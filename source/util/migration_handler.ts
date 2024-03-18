import pg from 'pg'
import { migrate } from 'postgres-migrations'

export async function applyMigrations(config: any): Promise<void> {
	const client = new pg.Client(config)
	await client.connect()
	try {
		await migrate({ client }, __dirname + '/migrations')
	} finally {
		await client.end()
	}
}
