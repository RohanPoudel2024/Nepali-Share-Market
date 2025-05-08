const { sql } = require('drizzle-orm');

module.exports = async ({ client }) => {
  console.log('Ensuring paper_holdings has all required columns...');
  
  try {
    // First check if the tables exist
    const tableCheck = await client.unsafe(`
      SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_name = 'paper_portfolios'
      );
    `);
    
    // More robust check for the query result structure
    let tableExists = false;
    if (tableCheck && tableCheck.rows && tableCheck.rows.length > 0) {
      tableExists = tableCheck.rows[0].exists;
    } else if (tableCheck && Array.isArray(tableCheck) && tableCheck.length > 0) {
      tableExists = tableCheck[0].exists;
    }
    
    console.log('Paper trading tables exist:', tableExists);
    
    if (!tableExists) {
      console.log('Creating paper trading tables from scratch');
      
      // Create the tables
      await client.unsafe(`
        CREATE TABLE IF NOT EXISTS "paper_portfolios" (
          "id" serial PRIMARY KEY,
          "user_id" integer,
          "name" varchar(255) NOT NULL,
          "description" text,
          "initial_balance" numeric NOT NULL DEFAULT 150000,
          "current_balance" numeric NOT NULL DEFAULT 150000,
          "created_at" timestamp DEFAULT NOW(),
          "updated_at" timestamp DEFAULT NOW()
        );

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
          FOREIGN KEY ("portfolio_id") REFERENCES "paper_portfolios" ("id") ON DELETE CASCADE
        );

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
          FOREIGN KEY ("portfolio_id") REFERENCES "paper_portfolios" ("id") ON DELETE CASCADE
        );
      `);
    }
    
    // Add is_active column if it doesn't exist
    await client.unsafe(`
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT FROM information_schema.columns 
          WHERE table_name = 'paper_holdings' AND column_name = 'is_active'
        ) THEN
          ALTER TABLE "paper_holdings" ADD COLUMN "is_active" boolean DEFAULT true;
          RAISE NOTICE 'Added is_active column to paper_holdings table';
        END IF;
      END $$;
    `);
    
    return true;
  } catch (error) {
    console.error('Error in add_is_active_column migration:', error);
    // Continue despite errors to allow other migrations to run
    return true;
  }
};