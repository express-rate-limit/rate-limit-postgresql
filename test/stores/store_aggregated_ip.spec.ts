import 'mocha'
import { assert } from 'chai'

import { Pool } from 'pg'
import sinon, { SinonMock, SinonStub } from 'sinon'
import { PostgresStore } from '../../source'
const migration_handler = require('../../source/util/migration_handler')

class ClientMock {
	query() {}
	release() {}
}

describe('Postgres Store Aggregated IP', () => {
	let query: SinonStub
	let connect: SinonStub
	let client: SinonMock
	let applyMigrationsStub: SinonStub
	let expirationDate = new Date()

	beforeEach(() => {
		query = sinon.stub(Pool.prototype, 'query')
		connect = sinon.stub(Pool.prototype, 'connect')
		client = sinon.mock(ClientMock.prototype)
		applyMigrationsStub = sinon.stub(migration_handler, 'applyMigrations')
	})

	afterEach(() => {
		query.restore() // reset stub/mock
		connect.restore()
		client.restore()
		applyMigrationsStub.restore()
	})

	it('constructor should call correct functions and populate correct fields', async () => {
		let testStore = new PostgresStore({}, 'test')
		assert.equal(testStore.prefix, 'test')
		sinon.assert.callCount(applyMigrationsStub, 1)
	})

	it('increment function should follow expected business logic', async () => {
		let pool = new Pool()
		let dbCount = 1

		query.onFirstCall().returns({
			rows: [
				{
					count: dbCount,
					expires_at: expirationDate,
				},
			],
		})
		let testStore = new PostgresStore({}, 'test')
		testStore.pool = pool
		let recordInsertGetRecordsQuery = `SELECT * FROM rate_limit.agg_increment($1, $2, $3) AS (count int, expires_at timestamptz);`
		let incrementCount = await testStore.increment('key')
		sinon.assert.calledWith(query, recordInsertGetRecordsQuery, [
			'key',
			testStore.prefix,
			undefined,
		])
		assert.equal(incrementCount.totalHits, dbCount)
		assert.equal(incrementCount.resetTime, expirationDate)
	})

	it('decrement function should follow expected business logic', async () => {
		let pool = new Pool()
		query.onFirstCall().returns({
			rows: [],
		})

		let testStore = new PostgresStore({}, 'test')
		testStore.pool = pool

		await testStore.decrement('key')
		let decrementQuery = `
			SELECT * FROM rate_limit.agg_decrement($1, $2);
        `
		sinon.assert.calledWith(query, decrementQuery, ['key', testStore.prefix])
	})

	it('resetKey function should follow expected business logic', async () => {
		let pool = new Pool()
		query.onFirstCall().returns({
			rows: [],
		})

		let testStore = new PostgresStore({}, 'test')
		testStore.pool = pool

		await testStore.resetKey('key')
		let resetQuery = `
			SELECT * FROM rate_limit.agg_reset_key($1, $2)
            `
		sinon.assert.calledWith(query, resetQuery, ['key', testStore.prefix])
	})

	it('resetAll function should follow expected business logic', async () => {
		let pool = new Pool()
		query.onFirstCall().returns({
			rows: [],
		})

		let testStore = new PostgresStore({}, 'test')
		testStore.pool = pool

		await testStore.resetAll()
		let resetAllQuery = `
			SELECT * FROM rate_limit.agg_reset_session($1);
            `
		sinon.assert.calledWith(query, resetAllQuery, [testStore.prefix])
	})
})
