import { Store, Options, ClientRateLimitInfo } from 'express-rate-limit'

import Pool from 'pg-pool'
import { applyMigrations } from '../../util/migration_handler'

/**
 * A `Store` for the `express-rate-limit` package that stores hit counts in
 * PostgreSQL.
 *
 * @public
 */
class PostgresStoreAggregatedIP implements Store {
	/**
	 * The database configuration as specified in https://node-postgres.com/apis/client.
	 */
	config: any

	/**
	 * Optional value that the store prepends to keys
	 *
	 * Used by the double-count check to avoid false-positives when a key is counted twice, but with different prefixes
	 */
	prefix: string

	/**
	 * The database connection pool.
	 */
	pool: any

	/**
	 * The duration of time before which all hit counts are reset (in milliseconds).
	 */
	windowMs!: number

	/**
	 * @constructor for `PostgresStoreAggregatedIP`.
	 *
	 * @param config {any} - The database configuration as specified in https://node-postgres.com/apis/client.
	 * @param prefix {string} - The unique name of the session. This is useful when applying multiple rate limiters with multiple stores.
	 */
	constructor(config: any, prefix: string) {
		this.config = config
		this.prefix = prefix
		applyMigrations(config)
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
		let recordInsertGetRecordsQuery = `SELECT * FROM rate_limit.agg_increment($1, $2, $3) AS (count int, expires_at timestamptz);`

		try {
			let result = await this.pool.query(recordInsertGetRecordsQuery, [
				key,
				this.prefix,
				this.windowMs,
			])
			let totalHits: number = 0
			let resetTime: Date | undefined = undefined

			if (result.rows.length > 0) {
				totalHits = parseInt(result.rows[0].count)
				resetTime = result.rows[0].expires_at
			}
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
			SELECT * FROM rate_limit.agg_decrement($1, $2);
        `

		try {
			await this.pool.query(decrementQuery, [key, this.prefix])
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
			SELECT * FROM rate_limit.agg_reset_key($1, $2)
            `

		try {
			await this.pool.query(resetQuery, [key, this.prefix])
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
			SELECT * FROM rate_limit.agg_reset_session($1);
            `

		try {
			await this.pool.query(resetAllQuery, [this.prefix])
		} catch (err) {
			console.error(err)
			throw err
		}
	}
}

export default PostgresStoreAggregatedIP
