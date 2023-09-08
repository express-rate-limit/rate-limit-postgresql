import { Store, Options, ClientRateLimitInfo } from 'express-rate-limit'

import Pool from 'pg-pool'
import { migrate } from 'postgres-migrations'

type Session = {
	id: string
	expires_at: Date | undefined
}

/**
 * Calculates the time when all hit counters will be reset.
 *
 * @param windowMs {number} - The duration of a window (in milliseconds).
 *
 * @returns {Date}
 *
 * @private
 */
const calculateNextResetTime = (windowMs: number): Date => {
	const resetTime = new Date()
	resetTime.setMilliseconds(resetTime.getMilliseconds() + windowMs)
	return resetTime
}

/**
 * A `Store` for the `express-rate-limit` package that stores hit counts in
 * PostgreSQL.
 *
 * @public
 */
class PostgresStore implements Store {
	/**
	 * The database configuration as specified in https://node-postgres.com/apis/client.
	 */
	config: any

	/**
	 * The database connection pool.
	 */
	pool: any

	/**
	 * The session instance persisted on the client side.
	 */
	session: Session = {
		id: 'init',
		expires_at: undefined,
	}

	/**
	 * The duration of time before which all hit counts are reset (in milliseconds).
	 */
	windowMs!: number

	/**
	 * The time at which all hit counts will be reset.
	 */
	resetTime!: Date

	/**
	 * @constructor for `PostgresStore`.
	 *
	 * @param config {JSON} - The database configuration as specified in https://node-postgres.com/apis/client.
	 */
	constructor(config: any) {
		this.config = config
		this.applyMigrations()
	}

	async applyMigrations(): Promise<void> {
		const dbConfig = {
			database: this.config['database'] || 'postgres',
			user: this.config['user'] || 'postgres',
			password: this.config['password'] || 'postgres',
			host: this.config['host'] || 'localhost',
			port: this.config['port'] || 5432,
		}
		await migrate(dbConfig, __dirname + '/../migrations')
	}

	/**
	 * Method that actually initializes the store. Must be synchronous.
	 *
	 * This method is optional, it will be called only if it exists.
	 *
	 * @param options {Options} - The options used to setup express-rate-limit.
	 *
	 * @public
	 */
	init(options: Options): void {
		this.windowMs = options.windowMs
		this.pool = new Pool(this.config)
	}

	/**
	 * Method to increment a client's hit counter.
	 *
	 * @param key {string} - The identifier for a client.
	 *
	 * @returns {ClientRateLimitInfo} - The number of hits and reset time for that client.
	 *
	 * @public
	 */
	async increment(key: string): Promise<ClientRateLimitInfo> {
		let recordInsertQuery =
			'INSERT INTO rate_limit.records(key, session_id) VALUES ($1, $2)'
		let numberOfRecordsQuery =
			'SELECT count(id) AS count FROM rate_limit.records WHERE key = $1'
		if (!this.isSessionValid(this.session)) {
			this.session = await this.getSession()
		}

		try {
			await this.pool.query(recordInsertQuery, [key, this.session.id])
			let result = await this.pool.query(numberOfRecordsQuery, [key])
			let totalHits: number = 0
			if (result.rows.length > 0) totalHits = parseInt(result.rows[0].count)
			let resetTime: Date | undefined = this.session.expires_at
			return {
				totalHits,
				resetTime,
			}
		} catch (err) {
			console.error(err)
			throw err
		}
	}

	/**
	 * Method to decrement a client's hit counter.
	 *
	 * @param key {string} - The identifier for a client.
	 *
	 * @public
	 */
	async decrement(key: string): Promise<void> {
		let decrementQuery = `
            WITH 
            rows_to_delete AS (
                SELECT id FROM rate_limit.records
                WHERE key = $1 ORDER BY registered_at LIMIT 1
                )
            DELETE FROM rate_limit.records 
              USING rows_to_delete WHERE records.id = rows_to_delete.id            
        `

		try {
			await this.pool.query(decrementQuery, [key])
		} catch (err) {
			console.error(err)
			throw err
		}
	}

	/**
	 * Method to reset a client's hit counter.
	 *
	 * @param key {string} - The identifier for a client.
	 *
	 * @public
	 */
	async resetKey(key: string): Promise<void> {
		let resetQuery = `
            DELETE FROM rate_limit.records
            WHERE key = $1
            `

		try {
			await this.pool.query(resetQuery, [key])
		} catch (err) {
			console.error(err)
			throw err
		}
	}

	/**
	 * Method to reset everyone's hit counter.
	 *
	 * This method is optional, it is never called by express-rate-limit.
	 *
	 * @public
	 */
	async resetAll(): Promise<void> {
		let resetAllQuery = `
            DELETE FROM rate_limit.records
            `

		try {
			await this.pool.query(resetAllQuery)
		} catch (err) {
			console.error(err)
			throw err
		}
	}

	/**
	 * Method that retrieves the active session from the database.
	 *
	 * @private
	 */
	async getSession(): Promise<Session> {
		let selectSessionQuery =
			'SELECT id, expires_at FROM rate_limit.sessions LIMIT 1'
		try {
			let result = await this.pool.query(selectSessionQuery)

			if (result.rows.length == 0) {
				console.log('No database session, creating one')
				return this.createNewSession()
			}

			let databaseSession: Session = {
				id: result.rows[0].id,
				expires_at: result.rows[0].expires_at,
			}

			if (this.isSessionValid(databaseSession)) {
				console.log('Database session is valid', databaseSession)
				return databaseSession
			} else {
				console.log('Database session is not valid', databaseSession)
				return this.createNewSession()
			}
		} catch (err) {
			console.error(err)
			throw err
		}
	}

	/**
	 * Method that checks the validity of a session.
	 *
	 * @param session {Session} - The session that is evaluated.
	 *
	 * @private
	 */
	isSessionValid(session: Session): boolean {
		if (session.expires_at) {
			return session.expires_at > new Date()
		}
		return false
	}

	/**
	 * Method that clears the database of existing relevant sessions,
	 * generates a new valid session and persists it to the database.
	 *
	 * @private
	 */
	async createNewSession(): Promise<Session> {
		let newSession = {
			id: 'provisional-id',
			expires_at: calculateNextResetTime(this.windowMs),
		}

		let deleteSessionQuery = 'DELETE FROM rate_limit.sessions'
		let insertSessionQuery =
			'INSERT INTO rate_limit.sessions(expires_at) SELECT $1 RETURNING id'

		let client = await this.pool.connect()
		try {
			await client.query(deleteSessionQuery)
			let result = await client.query(insertSessionQuery, [
				newSession.expires_at,
			])
			newSession.id = result.rows[0].id
		} finally {
			client.release()
		}

		return newSession
	}
}

export default PostgresStore
