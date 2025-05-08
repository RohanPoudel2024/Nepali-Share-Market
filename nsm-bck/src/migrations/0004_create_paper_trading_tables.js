const { sql } = require('drizzle-orm');
const { paperPortfolios, paperHoldings, paperTrades } = require('../models/paperTrading');

module.exports = async ({ db, client }) => {
  console.log('Creating paper trading tables...');
  
  // Use direct SQL execution like your other successful migrations
  console.log('Creating paper_portfolios table...');
  await client.unsafe(`
    CREATE TABLE IF NOT EXISTS "paper_portfolios" (
      "id" serial PRIMARY KEY,
      "user_id" integer, /* Changed from NOT NULL to allow anonymous users */
      "name" varchar(255) NOT NULL,
      "description" text,
      "initial_balance" numeric NOT NULL DEFAULT 150000,
      "current_balance" numeric NOT NULL DEFAULT 150000,
      "created_at" timestamp DEFAULT NOW(),
      "updated_at" timestamp DEFAULT NOW()
    );
  `);
  
  console.log('Creating paper_holdings table...');
  await client.unsafe(`
    CREATE TABLE IF NOT EXISTS "paper_holdings" (
      "id" serial PRIMARY KEY,
      "portfolio_id" integer NOT NULL,
      "symbol" varchar(20) NOT NULL,
      "company_name" varchar(255),
      "quantity" numeric NOT NULL,
      "average_buy_price" numeric NOT NULL,
      "buy_price" numeric NOT NULL,
      "created_at" timestamp DEFAULT NOW(),
      "updated_at" timestamp DEFAULT NOW(),
      FOREIGN KEY ("portfolio_id") REFERENCES "paper_portfolios" ("id") ON DELETE CASCADE
    );
  `);
  
  console.log('Creating paper_trades table...');
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
      FOREIGN KEY ("portfolio_id") REFERENCES "paper_portfolios" ("id") ON DELETE CASCADE
    );
  `);
  
  console.log('Paper trading tables created successfully');
};