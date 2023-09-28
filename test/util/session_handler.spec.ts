import 'mocha'
import { assert } from 'chai'
import {
	calculateNextResetTime,
	getSession,
	isSessionValid,
} from '../../source/util/session_handler'
import { Pool } from 'pg'
import sinon, { SinonMock, SinonStub } from 'sinon'

class ClientMock {
	query() {}
	release() {}
}

describe('Session Handling - Calculate reset time', () => {
	it('Return correct value when resetting time', async () => {
		const assertionTime = new Date()
		const timeOffset = 5000
		assertionTime.setMilliseconds(assertionTime.getMilliseconds() + timeOffset)
		const calculatedTime = calculateNextResetTime(timeOffset)

		assert.isTrue(
			assertionTime.getMilliseconds() - calculatedTime.getMilliseconds() < 10,
		)
	})
})

describe('Session Handling - Expiration assertion', () => {
	it('Return invalid session if expired', async () => {
		const pastTime = new Date()
		const timeOffset = 5000
		pastTime.setMilliseconds(pastTime.getMilliseconds() - timeOffset)

		let expiredSession = {
			id: '1',
			name: 'test-name-old',
			type: 'test-type-old',
			expires_at: pastTime,
		}
		assert.isFalse(isSessionValid(expiredSession))
	})

	it('Return invalid session if expires_at is missing', async () => {
		const pastTime = new Date()
		const timeOffset = 5000
		pastTime.setMilliseconds(pastTime.getMilliseconds() - timeOffset)

		let expiredSession = {
			id: '1',
			name: 'test-name-old',
			type: 'test-type-old',
			expires_at: undefined,
		}
		assert.isFalse(isSessionValid(expiredSession))
	})

	it('Return valid session if not expired', async () => {
		const futureTime = new Date()
		const timeOffset = 5000
		futureTime.setMilliseconds(futureTime.getMilliseconds() + timeOffset)

		let validSession = {
			id: '1',
			name: 'test-name',
			type: 'test-type',
			expires_at: futureTime,
		}
		assert.isTrue(isSessionValid(validSession))
	})
})

describe('Session Handling - Database Interaction', () => {
	let query: SinonStub
	let connect: SinonStub
	let client: SinonMock

	beforeEach(() => {
		query = sinon.stub(Pool.prototype, 'query')
		connect = sinon.stub(Pool.prototype, 'connect')
		client = sinon.mock(ClientMock.prototype)
	})

	afterEach(() => {
		query.restore() // reset stub/mock
		connect.restore()
		client.restore()
	})

	it('should return existing database session if it has not expired', async () => {
		const futureTime = new Date()
		const timeOffset = 5000
		futureTime.setMilliseconds(futureTime.getMilliseconds() + timeOffset)

		let notExpiredSession = {
			id: '1',
			name: 'test-name',
			type: 'test-type',
			expires_at: futureTime,
		}

		query.resolves({
			rows: [
				{
					id: notExpiredSession.id,
					name_: notExpiredSession.name,
					type_: notExpiredSession.type,
					expires_at: notExpiredSession.expires_at,
				},
			],
		})

		let pool = new Pool()

		let databaseSession = await getSession(
			notExpiredSession.name,
			notExpiredSession.type,
			timeOffset,
			pool,
		)

		assert.equal(databaseSession.id, notExpiredSession.id)
		assert.equal(databaseSession.type, notExpiredSession.type)
		assert.equal(databaseSession.name, notExpiredSession.name)
		assert.isTrue(
			(databaseSession.expires_at?.getMilliseconds() ||
				new Date().getMilliseconds()) -
				notExpiredSession.expires_at?.getMilliseconds() <
				10,
		)
		sinon.assert.callCount(query, 1)
	})

	it('should generate a new session and insert it in the database if the session does not exist in the database', async () => {
		const futureTime = new Date()
		const timeOffset = 5000
		futureTime.setMilliseconds(futureTime.getMilliseconds() + timeOffset)

		let newCreatedSession = {
			id: '1',
			name: 'test-name',
			type: 'test-type',
			expires_at: futureTime,
		}

		query.onFirstCall().returns({
			rows: [],
		})

		query.onSecondCall().returns({
			rows: [
				{
					id: newCreatedSession.id,
					name_: newCreatedSession.name,
					type_: newCreatedSession.type,
					expires_at: newCreatedSession.expires_at,
				},
			],
		})

		connect.resolves({
			query,
			release() {},
		})

		let pool = new Pool()

		let databaseSession = await getSession(
			newCreatedSession.name,
			newCreatedSession.type,
			timeOffset,
			pool,
		)

		assert.equal(databaseSession.id, newCreatedSession.id)
		assert.equal(databaseSession.type, newCreatedSession.type)
		assert.equal(databaseSession.name, newCreatedSession.name)
		assert.isTrue(
			(databaseSession.expires_at?.getMilliseconds() ||
				new Date().getMilliseconds()) -
				newCreatedSession.expires_at?.getMilliseconds() <
				10,
		)
		sinon.assert.callCount(query, 2)
	})

	it('should generate a new session and insert it in the database if the database session is expired', async () => {
		const futureTime = new Date()
		const pastTime = new Date()
		const timeOffset = 5000
		futureTime.setMilliseconds(futureTime.getMilliseconds() + timeOffset)
		pastTime.setMilliseconds(pastTime.getMilliseconds() - timeOffset)

		let expiredSession = {
			id: '1',
			name: 'test-name-old',
			type: 'test-type-old',
			expires_at: pastTime,
		}

		let newCreatedSession = {
			id: '2',
			name: 'test-name-new',
			type: 'test-type-new',
			expires_at: futureTime,
		}

		query.onFirstCall().returns({
			rows: [
				{
					id: expiredSession.id,
					name_: expiredSession.name,
					type_: expiredSession.type,
					expires_at: expiredSession.expires_at,
				},
			],
		})

		query.onSecondCall().returns({
			rows: [
				{
					id: newCreatedSession.id,
					name_: newCreatedSession.name,
					type_: newCreatedSession.type,
					expires_at: newCreatedSession.expires_at,
				},
			],
		})

		connect.resolves({
			query,
			release() {},
		})

		let pool = new Pool()

		let databaseSession = await getSession(
			newCreatedSession.name,
			newCreatedSession.type,
			timeOffset,
			pool,
		)

		assert.equal(databaseSession.id, newCreatedSession.id)
		assert.equal(databaseSession.type, newCreatedSession.type)
		assert.equal(databaseSession.name, newCreatedSession.name)
		assert.isTrue(
			(databaseSession.expires_at?.getMilliseconds() ||
				new Date().getMilliseconds()) -
				newCreatedSession.expires_at?.getMilliseconds() <
				10,
		)
		sinon.assert.callCount(query, 2)
	})
})
