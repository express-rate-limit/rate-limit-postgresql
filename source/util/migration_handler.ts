import { Pool } from 'pg'
import { migrate } from 'postgres-migrations'

export async function applyMigrations(config: any): Promise<void> {
	const pool = new Pool(config)
	await migrate({ client: pool }, __dirname + '/migrations')
}
