import { migrate } from 'postgres-migrations'

export async function applyMigrations(config: any): Promise<void> {
	const dbConfig = {
		database: config['database'] || 'postgres',
		user: config['user'] || 'postgres',
		password: config['password'] || 'postgres',
		host: config['host'] || 'localhost',
		port: config['port'] || 5432,
	}
	await migrate(dbConfig, __dirname + '/migrations')
}
