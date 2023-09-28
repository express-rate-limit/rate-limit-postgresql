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
		'SELECT id, name_, type_, expires_at FROM rate_limit.session_select($1, $2);'
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

	let resetSessionQuery = `
		SELECT id, name_, type_ from rate_limit.session_reset($1, $2, $3)
	`

	try {
		let result = await pool.query(resetSessionQuery, [
			name_,
			type_,
			newSession.expires_at,
		])
		newSession.id = result.rows[0].id
	} catch (err) {
		console.error(err)
		throw err
	}

	return newSession
}
