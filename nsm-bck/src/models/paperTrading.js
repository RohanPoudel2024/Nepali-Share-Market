const { pgTable, serial, varchar, text, numeric, timestamp, integer, boolean } = require('drizzle-orm/pg-core');
const { users } = require('./schema');

// Paper Portfolio Schema
const paperPortfolios = pgTable('paper_portfolios', {
  id: serial('id').primaryKey(),
  user_id: integer('user_id'), // Made nullable
  name: varchar('name', { length: 255 }).notNull(),
  description: text('description'),
  initial_balance: numeric('initial_balance').notNull().default(150000),
  current_balance: numeric('current_balance').notNull().default(150000),
  created_at: timestamp('created_at').defaultNow(),
  updated_at: timestamp('updated_at').defaultNow()
});

// Paper Holdings Schema - added is_active
const paperHoldings = pgTable('paper_holdings', {
  id: serial('id').primaryKey(),
  portfolio_id: integer('portfolio_id').notNull().references(() => paperPortfolios.id, { onDelete: 'cascade' }),
  symbol: varchar('symbol', { length: 20 }).notNull(),
  company_name: varchar('company_name', { length: 255 }),
  quantity: numeric('quantity').notNull(),
  average_buy_price: numeric('average_buy_price').notNull(),
  buy_price: numeric('buy_price').notNull(),
  is_active: boolean('is_active').default(true),
  created_at: timestamp('created_at').defaultNow(),
  updated_at: timestamp('updated_at').defaultNow()
});

// Paper Trades Schema
const paperTrades = pgTable('paper_trades', {
  id: serial('id').primaryKey(),
  portfolio_id: integer('portfolio_id').notNull().references(() => paperPortfolios.id, { onDelete: 'cascade' }),
  symbol: varchar('symbol', { length: 20 }).notNull(),
  type: varchar('type', { length: 10 }).notNull(), // BUY or SELL
  quantity: numeric('quantity').notNull(),
  price: numeric('price').notNull(),
  total_amount: numeric('total_amount').notNull(),
  trade_date: timestamp('trade_date').defaultNow(),
  created_at: timestamp('created_at').defaultNow()
});

module.exports = {
  paperPortfolios,
  paperHoldings,
  paperTrades
};