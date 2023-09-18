import 'mocha'
import { assert } from 'chai'

import { Pool } from 'pg'
import sinon, { SinonMock, SinonStub } from 'sinon'
import { PostgresStore } from '../../source'
import { Session } from '../../source/models/session'
const session_handler = require('../../source/util/session_handler')
const migration_handler = require('../../source/util/migration_handler')

class ClientMock {
	query() {}
	release() {}
}

describe('Postgres Store Aggregated IP', () => {
	let query: SinonStub
	let connect: SinonStub
	let client: SinonMock
	let getSessionStub: SinonStub
	let applyMigrationsStub: SinonStub
	let isSessionValidSpy: SinonStub
	let newCreatedSession: Session

	beforeEach(() => {
		query = sinon.stub(Pool.prototype, 'query')
		connect = sinon.stub(Pool.prototype, 'connect')
		client = sinon.mock(ClientMock.prototype)
		getSessionStub = sinon.stub(session_handler, 'getSession')
		isSessionValidSpy = sinon.stub(session_handler, 'isSessionValid')
		applyMigrationsStub = sinon.stub(migration_handler, 'applyMigrations')
		const futureTime = new Date()
		const timeOffset = 5000
		futureTime.setMilliseconds(futureTime.getMilliseconds() + timeOffset)

		newCreatedSession = {
			id: '1',
			name: 'test-name',
			type: 'test-type',
			expires_at: futureTime,
		}
	})

	afterEach(() => {
		query.restore() // reset stub/mock
		connect.restore()
		client.restore()
		getSessionStub.restore()
		applyMigrationsStub.restore()
		isSessionValidSpy.restore()
	})

	it('constructor should call correct functions and populate correct fields', async () => {
		let testStore = new PostgresStore({}, 'test')
		assert.equal(testStore.prefix, 'test')
		sinon.assert.callCount(applyMigrationsStub, 1)
	})

	it('increment function should follow expected business logic', async () => {
		let pool = new Pool()
		let dbCount = 1

		isSessionValidSpy.returns(true)
		query.onFirstCall().returns({
			rows: [
				{
					count: dbCount,
				},
			],
		})
		let testStore = new PostgresStore({}, 'test')
		testStore.pool = pool
		testStore.session = newCreatedSession

		let incrementCount = await testStore.increment('key')
		sinon.assert.callCount(isSessionValidSpy, 1)
		sinon.assert.calledWith(
			query,
			`
            INSERT INTO rate_limit.records_aggregated(key, session_id) VALUES ($1, $2)
            ON CONFLICT ON CONSTRAINT unique_session_key DO UPDATE
            SET count = records_aggregated.count + 1
            RETURNING count
            `,
			['key', newCreatedSession.id],
		)
		assert.equal(incrementCount.totalHits, dbCount)
		assert.isTrue(
			(incrementCount.resetTime?.getMilliseconds() ||
				new Date().getMilliseconds()) -
				(newCreatedSession.expires_at?.getMilliseconds() ||
					new Date().getMilliseconds()) <
				10,
		)
	})

	it('decrement function should follow expected business logic', async () => {
		let pool = new Pool()
		query.onFirstCall().returns({
			rows: [],
		})

		let testStore = new PostgresStore({}, 'test')
		testStore.pool = pool
		testStore.session = newCreatedSession

		await testStore.decrement('key')
		let decrementQuery = `
            UPDATE rate_limit.records_aggregated
            SET count = greatest(0, count-1)
            WHERE key = $1 and session_id = $2          
        `
		sinon.assert.calledWith(query, decrementQuery, [
			'key',
			newCreatedSession.id,
		])
	})

	it('resetKey function should follow expected business logic', async () => {
		let pool = new Pool()
		query.onFirstCall().returns({
			rows: [],
		})

		let testStore = new PostgresStore({}, 'test')
		testStore.pool = pool
		testStore.session = newCreatedSession

		await testStore.resetKey('key')
		let resetQuery = `
            DELETE FROM rate_limit.records_aggregated
            WHERE key = $1 and session_id = $2
            `
		sinon.assert.calledWith(query, resetQuery, ['key', newCreatedSession.id])
	})

	it('resetAll function should follow expected business logic', async () => {
		let pool = new Pool()
		query.onFirstCall().returns({
			rows: [],
		})

		let testStore = new PostgresStore({}, 'test')
		testStore.pool = pool
		testStore.session = newCreatedSession

		await testStore.resetAll()
		let resetAllQuery = `
            DELETE FROM rate_limit.records_aggregated WHERE session_id = $1
            `
		sinon.assert.calledWith(query, resetAllQuery, [newCreatedSession.id])
	})
})
