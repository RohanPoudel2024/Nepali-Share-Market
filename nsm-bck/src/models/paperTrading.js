const { pgTable, serial, varchar, text, numeric, timestamp, integer, boolean } = require('drizzle-orm/pg-core');
const { users } = require('./schema');

// Paper Portfolio Schema
const paperPortfolios = pgTable('paper_portfolios', {
  id: serial('id').primaryKey(),
  user_id: integer('user_id'), // Made nullable to support anonymous users
  name: text('name').notNull(),
  description: text('description'),
  // Explicitly define numeric types with proper precision
  initial_balance: numeric('initial_balance', { precision: 14, scale: 2 }).notNull().default('150000'),
  current_balance: numeric('current_balance', { precision: 14, scale: 2 }).notNull().default('150000'),
  created_at: timestamp('created_at').notNull().defaultNow(),
  updated_at: timestamp('updated_at').notNull().defaultNow()
});

// Paper Holdings Schema
const paperHoldings = pgTable('paper_holdings', {
  id: serial('id').primaryKey(),
  portfolio_id: integer('portfolio_id').notNull().references(() => paperPortfolios.id, { onDelete: 'cascade' }),
  symbol: varchar('symbol', { length: 20 }).notNull(),
  company_name: varchar('company_name', { length: 255 }),
  quantity: numeric('quantity', { precision: 14, scale: 6 }).notNull(),
  average_buy_price: numeric('average_buy_price', { precision: 14, scale: 2 }).notNull(),
  buy_price: numeric('buy_price', { precision: 14, scale: 2 }).notNull(),
  is_active: boolean('is_active').default(true),
  created_at: timestamp('created_at').defaultNow(),
  updated_at: timestamp('updated_at').defaultNow()
});

// Paper Trades Schema
const paperTrades = pgTable('paper_trades', {
  id: serial('id').primaryKey(),
  portfolio_id: integer('portfolio_id').notNull().references(() => paperPortfolios.id, { onDelete: 'cascade' }),
  symbol: varchar('symbol', { length: 20 }).notNull(),
  company_name: varchar('company_name', { length: 255 }),
  type: varchar('type', { length: 10 }).notNull(), // BUY or SELL
  quantity: numeric('quantity', { precision: 14, scale: 6 }).notNull(),
  price: numeric('price', { precision: 14, scale: 2 }).notNull(),
  total_amount: numeric('total_amount', { precision: 14, scale: 2 }).notNull(), 
  trade_date: timestamp('trade_date').defaultNow(),
  created_at: timestamp('created_at').notNull().defaultNow()
});

module.exports = {
  paperPortfolios,
  paperHoldings,
  paperTrades
};