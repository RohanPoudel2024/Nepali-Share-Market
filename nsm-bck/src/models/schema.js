const { pgTable, serial, text, integer, timestamp, boolean, real } = require('drizzle-orm/pg-core');

// Users table
const users = pgTable('users', {
  id: serial('id').primaryKey(),
  email: text('email').notNull().unique(),
  password: text('password').notNull(),
  name: text('name'),
  createdAt: timestamp('created_at').defaultNow()
});

// Portfolio table
const portfolios = pgTable('portfolios', {
  id: serial('id').primaryKey(),
  userId: integer('user_id').notNull().references(() => users.id),
  name: text('name').notNull(),
  description: text('description'),
  createdAt: timestamp('created_at').defaultNow()
});

// Stock holdings table
const holdings = pgTable('holdings', {
  id: serial('id').primaryKey(),
  portfolioId: integer('portfolio_id').notNull().references(() => portfolios.id),
  symbol: text('symbol').notNull(),
  quantity: real('quantity').notNull().default(0),
  averageBuyPrice: real('average_buy_price').notNull(),
  isActive: boolean('is_active').default(true),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow()
});

// Transactions table
const transactions = pgTable('transactions', {
  id: serial('id').primaryKey(),
  holdingId: integer('holding_id').notNull().references(() => holdings.id),
  type: text('type').notNull(),  // "BUY" or "SELL"
  quantity: real('quantity').notNull(),
  price: real('price').notNull(),
  date: timestamp('date').notNull(),
  createdAt: timestamp('created_at').defaultNow()
});

const paperPortfolios = pgTable('paper_portfolios', {
  id: serial('id').primaryKey(),
  userId: integer('user_id').notNull().references(() => users.id),
  name: text('name').notNull(),
  description: text('description'),
  initialBalance: real('initial_balance').notNull().default(0),
  currentBalance: real('current_balance').notNull().default(0),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow()
});

const paperHoldings = pgTable('paper_holdings', {
  id: serial('id').primaryKey(),
  portfolioId: integer('portfolio_id').notNull().references(() => paperPortfolios.id),
  symbol: text('symbol').notNull(),
  quantity: real('quantity').notNull().default(0),
  averageBuyPrice: real('average_buy_price').notNull(),
  isActive: boolean('is_active').default(true),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow()
});

const paperTrades = pgTable('paper_trades', {
  id: serial('id').primaryKey(),
  portfolioId: integer('portfolio_id').notNull().references(() => paperPortfolios.id),
  holdingId: integer('holding_id').references(() => paperHoldings.id),
  symbol: text('symbol').notNull(),
  type: text('type').notNull(),  // "BUY" or "SELL"
  quantity: real('quantity').notNull(),
  price: real('price').notNull(),
  totalAmount: real('total_amount').notNull(),
  tradeDate: timestamp('trade_date').notNull(),
  createdAt: timestamp('created_at').defaultNow()
});

module.exports = {
  users,
  portfolios,
  holdings,
  transactions,
  paperPortfolios,
  paperHoldings,
  paperTrades
};