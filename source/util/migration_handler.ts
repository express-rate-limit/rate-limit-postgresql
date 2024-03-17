import { Client } from 'pg'
import { migrate } from 'postgres-migrations'

export async function applyMigrations(config: any): Promise<void> {
	const client = new Client(config)
	await client.connect()
	try {
		await migrate({ client }, __dirname + '/migrations')
	} finally {
		await client.end()
	}
}
