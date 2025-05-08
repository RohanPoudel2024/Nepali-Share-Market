require('dotenv').config();

/** @type {import('drizzle-kit').Config} */
module.exports = {
  schema: './src/models/schema.js',
  out: './drizzle',
  dialect: 'postgresql',  // This was missing
  driver: 'postgres',     // Changed from 'pg' to 'postgres'
  dbCredentials: {
    connectionString: process.env.DATABASE_URL,
  }
};