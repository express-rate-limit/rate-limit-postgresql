import { Pool } from 'pg'
import { Session } from '../models/session'

/**
 * Calculates the time when all hit counters will be reset.
 *
 * @param windowMs {number} - The duration of a window (in milliseconds).
 *
 * @returns {Date}
 *
 * @private
 */
export const calculateNextResetTime = (windowMs: number): Date => {
	const resetTime = new Date()
	resetTime.setMilliseconds(resetTime.getMilliseconds() + windowMs)
	return resetTime
}

/**
 * Method that retrieves the active session from the database.
 *
 * @private
 */
export async function getSession(
	name_: string,
	type_: string,
	windowMs: number,
	pool: Pool,
): Promise<Session> {
	let selectSessionQuery =
		'SELECT id, name_, type_, expires_at FROM rate_limit.sessions WHERE name_ = $1 and type_ = $2 LIMIT 1'
	try {
		let result = await pool.query(selectSessionQuery, [name_, type_])

		if (result.rows.length == 0) {
			return createNewSession(name_, type_, windowMs, pool)
		}

		let databaseSession: Session = {
			id: result.rows[0].id,
			name: result.rows[0].name_,
			type: result.rows[0].type_,
			expires_at: result.rows[0].expires_at,
		}

		if (isSessionValid(databaseSession)) {
			return databaseSession
		} else {
			return createNewSession(name_, type_, windowMs, pool)
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
export function isSessionValid(session: Session): boolean {
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
export async function createNewSession(
	name_: string,
	type_: string,
	windowMs: number,
	pool: Pool,
): Promise<Session> {
	let newSession = {
		id: 'provisional-id',
		name: name_,
		type: type_,
		expires_at: calculateNextResetTime(windowMs),
	}

	let deleteSessionQuery = `DELETE FROM rate_limit.sessions
        WHERE name_ = $1 and type_ = $2
        `
	let insertSessionQuery = `INSERT INTO rate_limit.sessions(name_, type_, expires_at) 
        SELECT $1, $2, $3 
        RETURNING id, name_, type_`

	let client = await pool.connect()
	try {
		await client.query(deleteSessionQuery, [name_, type_])
		let result = await client.query(insertSessionQuery, [
			name_,
			type_,
			newSession.expires_at,
		])
		newSession.id = result.rows[0].id
	} finally {
		client.release()
	}

	return newSession
}
