require('dotenv').config();
const { migrate } = require('drizzle-orm/postgres-js/migrator');
const postgres = require('postgres');
const { drizzle } = require('drizzle-orm/postgres-js');

const migrationRunner = async () => {
  try {
    const connectionString = process.env.DATABASE_URL;
    const migrationClient = postgres(connectionString, { max: 1 });
    const db = drizzle(migrationClient);

    console.log('Running migrations...');
    
    await migrate(db, { migrationsFolder: 'drizzle' });
    
    console.log('Migrations completed successfully');
    
    await migrationClient.end();
    process.exit(0);
  } catch (error) {
    console.error('Migration failed:', error);
    process.exit(1);
  }
};

migrationRunner();