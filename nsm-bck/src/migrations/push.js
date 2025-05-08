require('dotenv').config();
const { drizzle } = require('drizzle-orm/postgres-js');
const { sql } = require('drizzle-orm');
const postgres = require('postgres');
const schema = require('../models/schema');

const pushToDatabase = async () => {
  try {
    const connectionString = process.env.DATABASE_URL;
    console.log('Pushing schema to database...');
    console.log('Using connection:', connectionString.replace(/:[^:]*@/, ':****@'));
    
    // Connect with broader permissions for table creation
    const client = postgres(connectionString, { 
      max: 1,
      // Higher timeout for schema operations
      timeout: 30000
    });
    
    // Check database connection
    try {
      await client.unsafe("SELECT 1");
      console.log('Database connection successful');
    } catch (error) {
      console.error('Database connection error:', error.message);
      throw error;
    }
    
    // Use direct SQL for table creation since we're having issues with the ORM structure
    console.log('Creating tables...');
    
    // Create users table
    console.log('Creating users table...');
    await client.unsafe(`
      CREATE TABLE IF NOT EXISTS "users" (
        "id" serial PRIMARY KEY,
        "email" text NOT NULL UNIQUE,
        "password" text NOT NULL,
        "name" text,
        "created_at" timestamp DEFAULT NOW()
      );
    `);
    
    // Create portfolios table
    console.log('Creating portfolios table...');
    await client.unsafe(`
      CREATE TABLE IF NOT EXISTS "portfolios" (
        "id" serial PRIMARY KEY,
        "user_id" integer NOT NULL REFERENCES "users"("id"),
        "name" text NOT NULL,
        "description" text,
        "created_at" timestamp DEFAULT NOW()
      );
    `);
    
    // Create holdings table
    console.log('Creating holdings table...');
    await client.unsafe(`
      CREATE TABLE IF NOT EXISTS "holdings" (
        "id" serial PRIMARY KEY,
        "portfolio_id" integer NOT NULL REFERENCES "portfolios"("id"),
        "symbol" text NOT NULL,
        "quantity" real NOT NULL DEFAULT 0,
        "average_buy_price" real NOT NULL,
        "is_active" boolean DEFAULT true,
        "created_at" timestamp DEFAULT NOW(),
        "updated_at" timestamp DEFAULT NOW()
      );
    `);
    
    // Create transactions table
    console.log('Creating transactions table...');
    await client.unsafe(`
      CREATE TABLE IF NOT EXISTS "transactions" (
        "id" serial PRIMARY KEY,
        "holding_id" integer NOT NULL REFERENCES "holdings"("id"),
        "type" text NOT NULL,
        "quantity" real NOT NULL,
        "price" real NOT NULL,
        "date" timestamp NOT NULL,
        "created_at" timestamp DEFAULT NOW()
      );
    `);
    
    console.log('Schema pushed successfully');
    await client.end();
    process.exit(0);
  } catch (error) {
    console.error('Database push failed:', error);
    process.exit(1);
  }
};

pushToDatabase();