const { db } = require('../config/database');
const { portfolios, holdings, transactions } = require('../models/schema');
const { eq, and, inArray } = require('drizzle-orm');

const portfolioService = {
  // Get all portfolios for a user with summary data
  getUserPortfolios: async (userId) => {
    // Get basic portfolios
    const userPortfolios = await db.query.portfolios.findMany({
      where: eq(portfolios.userId, userId)
    });
    
    // For each portfolio, calculate summary data
    const portfoliosWithSummary = await Promise.all(userPortfolios.map(async (portfolio) => {
      // Get all holdings for this portfolio
      const portfolioHoldings = await db.query.holdings.findMany({
        where: and(
          eq(holdings.portfolioId, portfolio.id),
          eq(holdings.isActive, true)
        )
      });
      
      // Calculate summary values
      let totalInvestment = 0;
      
      if (portfolioHoldings.length > 0) {
        totalInvestment = portfolioHoldings.reduce(
          (sum, holding) => sum + (holding.quantity * holding.averageBuyPrice), 
          0
        );
      }
      
      return {
        ...portfolio,
        totalInvestment,
        holdingsCount: portfolioHoldings.length
      };
    }));
    
    return portfoliosWithSummary;
  },

  // Create a new portfolio
  createPortfolio: async (portfolioData) => {
    return await db.insert(portfolios)
      .values(portfolioData)
      .returning();
  },

  // Get a specific portfolio with holdings
  getPortfolioWithHoldings: async (portfolioId, userId) => {
    const portfolio = await db.query.portfolios.findFirst({
      where: and(
        eq(portfolios.id, portfolioId),
        eq(portfolios.userId, userId)
      )
    });

    if (!portfolio) {
      return null;
    }

    // Include only active holdings
    const stockHoldings = await db.query.holdings.findMany({
      where: and(
        eq(holdings.portfolioId, portfolioId),
        eq(holdings.isActive, true)
      )
    });

    // Calculate summary data
    let totalInvestment = 0;
    let holdingsCount = stockHoldings.length;
    
    if (stockHoldings.length > 0) {
      totalInvestment = stockHoldings.reduce(
        (sum, holding) => sum + (holding.quantity * holding.averageBuyPrice), 
        0
      );
    }

    return {
      ...portfolio,
      holdings: stockHoldings,
      totalInvestment,
      holdingsCount
    };
  },

  // Add a new stock holding to a portfolio
  addHolding: async (holdingData) => {
    const [newHolding] = await db.insert(holdings)
      .values(holdingData)
      .returning();
    
    await db.insert(transactions).values({
      holdingId: newHolding.id,
      type: 'BUY',
      quantity: holdingData.quantity,
      price: holdingData.averageBuyPrice,
      date: new Date()
    });

    return newHolding;
  },

  // Update an existing holding (buy more or sell)
  updateHolding: async (holdingId, { quantity, price, type }) => {
    const holding = await db.query.holdings.findFirst({
      where: eq(holdings.id, holdingId)
    });

    if (!holding) {
      throw new Error('Holding not found');
    }

    // Record the transaction
    await db.insert(transactions).values({
      holdingId,
      type,
      quantity,
      price,
      date: new Date()
    });

    if (type === 'BUY') {
      // Calculate new average price
      const totalCost = (holding.averageBuyPrice * holding.quantity) + (price * quantity);
      const totalQuantity = holding.quantity + quantity;
      const newAveragePrice = totalCost / totalQuantity;

      // Update the holding
      return await db.update(holdings)
        .set({
          quantity: totalQuantity,
          averageBuyPrice: newAveragePrice,
          updatedAt: new Date()
        })
        .where(eq(holdings.id, holdingId))
        .returning();
    } else if (type === 'SELL') {
      const remainingQuantity = holding.quantity - quantity;
      
      // If all shares sold, mark as inactive
      if (remainingQuantity <= 0) {
        return await db.update(holdings)
          .set({
            quantity: 0,
            isActive: false,
            updatedAt: new Date()
          })
          .where(eq(holdings.id, holdingId))
          .returning();
      } else {
        // Update with remaining quantity
        return await db.update(holdings)
          .set({
            quantity: remainingQuantity,
            updatedAt: new Date()
          })
          .where(eq(holdings.id, holdingId))
          .returning();
      }
    }
  },

  // Find a holding by symbol in a portfolio
  findHoldingBySymbol: async (portfolioId, symbol) => {
    return await db.query.holdings.findFirst({
      where: and(
        eq(holdings.portfolioId, portfolioId),
        eq(holdings.symbol, symbol),
        eq(holdings.isActive, true)
      )
    });
  },

  // Add a transaction
  addTransaction: async (transactionData) => {
    return await db.insert(transactions)
      .values(transactionData)
      .returning();
  },

  // Get transactions by portfolio ID
  getTransactionsByPortfolioId: async (portfolioId) => {
    // Get all holdings for this portfolio
    const portfolioHoldings = await db.query.holdings.findMany({
      where: eq(holdings.portfolioId, portfolioId)
    });
    
    const holdingIds = portfolioHoldings.map(h => h.id);
    
    // Get transactions for these holdings
    if (holdingIds.length === 0) return [];
    
    const txns = await db.query.transactions.findMany({
      where: inArray(transactions.holdingId, holdingIds)
    });
    
    // Add symbol to each transaction from its parent holding
    return txns.map(txn => {
      const holding = portfolioHoldings.find(h => h.id === txn.holdingId);
      return {
        ...txn,
        symbol: holding ? holding.symbol : 'Unknown'
      };
    });
  }
};

module.exports = portfolioService;