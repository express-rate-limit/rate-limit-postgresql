import 'mocha'
import { assert, expect } from 'chai'

import { Pool } from 'pg'
import sinon, { SinonMock, SinonStub } from 'sinon'
import { PostgresStoreIndividualIP } from '../../source'
import { Session } from '../../source/models/session'
const session_handler = require('../../source/util/session_handler')
const migration_handler = require('../../source/util/migration_handler')

class ClientMock {
	query() {}
	release() {}
}

describe('Postgres Store Individual IP', () => {
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

	it('constructor should call correct functions', async () => {
		new PostgresStoreIndividualIP({}, 'test')
		sinon.assert.callCount(applyMigrationsStub, 1)
	})

	it('increment function should follow expected business logic', async () => {
		let pool = new Pool()

		isSessionValidSpy.returns(true)
		query.onFirstCall().returns({
			rows: [],
		})

		query.onSecondCall().returns({
			rows: [
				{
					count: 1,
				},
			],
		})
		let testStore = new PostgresStoreIndividualIP({}, 'test')
		testStore.pool = pool
		testStore.session = newCreatedSession

		await testStore.increment('key')
		sinon.assert.callCount(isSessionValidSpy, 1)
		sinon.assert.calledWith(
			query,
			'INSERT INTO rate_limit.individual_records(key, session_id) VALUES ($1, $2)',
			['key', newCreatedSession.id],
		)
		sinon.assert.calledWith(
			query,
			'SELECT count(id) AS count FROM rate_limit.individual_records WHERE key = $1 AND session_id = $2',
			['key', newCreatedSession.id],
		)
	})

	it('decrement function should follow expected business logic', async () => {
		let pool = new Pool()
		query.onFirstCall().returns({
			rows: [],
		})

		query.onSecondCall().returns({
			rows: [
				{
					count: 1,
				},
			],
		})
		let testStore = new PostgresStoreIndividualIP({}, 'test')
		testStore.pool = pool
		testStore.session = newCreatedSession

		await testStore.decrement('key')
		let decrementQuery = `
            WITH 
            rows_to_delete AS (
                SELECT id FROM rate_limit.individual_records
                WHERE key = $1 and session_id = $2 ORDER BY registered_at LIMIT 1
                )
            DELETE FROM rate_limit.individual_records 
              USING rows_to_delete WHERE individual_records.id = rows_to_delete.id            
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

		query.onSecondCall().returns({
			rows: [
				{
					count: 1,
				},
			],
		})
		let testStore = new PostgresStoreIndividualIP({}, 'test')
		testStore.pool = pool
		testStore.session = newCreatedSession

		await testStore.resetKey('key')
		let resetQuery = `
            DELETE FROM rate_limit.individual_records
            WHERE key = $1 AND session_id = $2
            `
		sinon.assert.calledWith(query, resetQuery, ['key', newCreatedSession.id])
	})

	it('resetAll function should follow expected business logic', async () => {
		let pool = new Pool()
		query.onFirstCall().returns({
			rows: [],
		})

		query.onSecondCall().returns({
			rows: [
				{
					count: 1,
				},
			],
		})
		let testStore = new PostgresStoreIndividualIP({}, 'test')
		testStore.pool = pool
		testStore.session = newCreatedSession

		await testStore.resetAll()
		let resetAllQuery = `
            DELETE FROM rate_limit.individual_records WHERE session_id = $1
            `
		sinon.assert.calledWith(query, resetAllQuery, [newCreatedSession.id])
	})
})
