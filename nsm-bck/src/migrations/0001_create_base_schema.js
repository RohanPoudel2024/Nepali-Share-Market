// This migration creates the basic schema for the application

module.exports = async ({ client }) => {
  console.log('Creating base schema tables...');
  
  try {
    // Create users table first as it's referenced by other tables
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
        "user_id" integer NOT NULL,
        "name" text NOT NULL,
        "description" text,
        "created_at" timestamp DEFAULT NOW(),
        CONSTRAINT fk_user FOREIGN KEY (user_id) REFERENCES users(id)
      );
    `);
    
    // Create holdings table
    console.log('Creating holdings table...');
    await client.unsafe(`
      CREATE TABLE IF NOT EXISTS "holdings" (
        "id" serial PRIMARY KEY,
        "portfolio_id" integer NOT NULL,
        "symbol" text NOT NULL,
        "quantity" real NOT NULL DEFAULT 0,
        "average_buy_price" real NOT NULL,
        "is_active" boolean DEFAULT true,
        "created_at" timestamp DEFAULT NOW(),
        "updated_at" timestamp DEFAULT NOW(),
        CONSTRAINT fk_portfolio FOREIGN KEY (portfolio_id) REFERENCES portfolios(id)
      );
    `);
    
    // Create transactions table
    console.log('Creating transactions table...');
    await client.unsafe(`
      CREATE TABLE IF NOT EXISTS "transactions" (
        "id" serial PRIMARY KEY,
        "holding_id" integer NOT NULL,
        "type" text NOT NULL,
        "quantity" real NOT NULL,
        "price" real NOT NULL,
        "date" timestamp NOT NULL,
        "created_at" timestamp DEFAULT NOW(),
        CONSTRAINT fk_holding FOREIGN KEY (holding_id) REFERENCES holdings(id)
      );
    `);
    
    // Create paper trading tables
    console.log('Creating paper trading tables...');
    
    // Paper portfolios table
    await client.unsafe(`
      CREATE TABLE IF NOT EXISTS "paper_portfolios" (
        "id" serial PRIMARY KEY,
        "user_id" integer,
        "name" varchar(255) NOT NULL,
        "description" text,
        "initial_balance" numeric NOT NULL DEFAULT 150000,
        "current_balance" numeric NOT NULL DEFAULT 150000,
        "created_at" timestamp DEFAULT NOW(),
        "updated_at" timestamp DEFAULT NOW(),
        CONSTRAINT fk_paper_user FOREIGN KEY (user_id) REFERENCES users(id)
      );
    `);
    
    // Paper holdings table
    await client.unsafe(`
      CREATE TABLE IF NOT EXISTS "paper_holdings" (
        "id" serial PRIMARY KEY,
        "portfolio_id" integer NOT NULL,
        "symbol" varchar(20) NOT NULL,
        "company_name" varchar(255),
        "quantity" numeric NOT NULL,
        "average_buy_price" numeric NOT NULL,
        "buy_price" numeric NOT NULL,
        "is_active" boolean DEFAULT true,
        "created_at" timestamp DEFAULT NOW(),
        "updated_at" timestamp DEFAULT NOW(),
        CONSTRAINT fk_paper_portfolio FOREIGN KEY (portfolio_id) REFERENCES paper_portfolios(id) ON DELETE CASCADE
      );
    `);
    
    // Paper trades table
    await client.unsafe(`
      CREATE TABLE IF NOT EXISTS "paper_trades" (
        "id" serial PRIMARY KEY,
        "portfolio_id" integer NOT NULL,
        "symbol" varchar(20) NOT NULL,
        "type" varchar(10) NOT NULL,
        "quantity" numeric NOT NULL,
        "price" numeric NOT NULL,
        "total_amount" numeric NOT NULL,
        "trade_date" timestamp DEFAULT NOW(),
        "created_at" timestamp DEFAULT NOW(),
        CONSTRAINT fk_paper_trade_portfolio FOREIGN KEY (portfolio_id) REFERENCES paper_portfolios(id) ON DELETE CASCADE
      );
    `);
    
    console.log('Base schema created successfully');
    return true;
  } catch (error) {
    // If table already exists, that's fine, we'll just continue
    if (error.code === '42P07') { // duplicate_table error code
      console.log('Tables already exist, continuing...');
      return true;
    }
    
    console.error('Error creating base schema:', error);
    // Don't throw here, we want to continue with other migrations
    return true;
  }
};
