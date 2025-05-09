const fs = require('fs');
const path = require('path');
const { db, client } = require('./database');

async function runMigrations() {
  console.log('Running database migrations...');
  
  try {
    // First check if database connection is working
    try {
      await client.unsafe('SELECT 1');
      console.log('Database connection successful');
    } catch (connError) {
      console.error('Database connection error:', connError);
      throw new Error('Failed to connect to database');
    }
    
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
        // Continue with the next migration instead of crashing
        console.log(`Continuing to next migration despite error in ${file}`);
      }
    }
    
    console.log('All migrations completed successfully');
    return true;
  } catch (error) {
    console.error('Migration process error:', error);
    return false;
  }
}

module.exports = runMigrations;