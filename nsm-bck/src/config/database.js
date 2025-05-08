require('dotenv').config();
const { drizzle } = require('drizzle-orm/postgres-js');
const postgres = require('postgres');
const schema = require('../models/schema');

// Use the Supabase connection string
const connectionString = process.env.DATABASE_URL;

// Create a PostgreSQL client
const client = postgres(connectionString, { max: 1 });

// Create a Drizzle instance with schema
const db = drizzle(client, { schema });

module.exports = { db, client };