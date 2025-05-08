const fs = require('fs');
const path = require('path');
const { db, client } = require('./database');

async function runMigrations() {
  console.log('Running database migrations...');
  
  // Get all migration files
  const migrationsDir = path.join(__dirname, '..', 'migrations');
  const migrationFiles = fs.readdirSync(migrationsDir)
    .filter(file => file.endsWith('.js') && !file.includes('push.js') && !file.includes('run.js'))
    .sort(); // Make sure migrations run in order
  
  console.log(`Found ${migrationFiles.length} migrations to run`);
  
  // Execute each migration
  for (const file of migrationFiles) {
    try {
      console.log(`Executing migration: ${file}`);
      const migration = require(path.join(migrationsDir, file));
      await migration({ db, client });
      console.log(`Migration ${file} completed successfully`);
    } catch (error) {
      console.error(`Error executing migration ${file}:`, error);
      throw error;
    }
  }
  
  console.log('All migrations completed successfully');
}

module.exports = runMigrations;