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
    try {
      // First verify the portfolio exists to avoid processing invalid portfolio IDs
      const portfolio = await db.query.portfolios.findFirst({
        where: eq(portfolios.id, portfolioId)
      });
      
      if (!portfolio) {
        console.warn(`Portfolio with ID ${portfolioId} not found`);
        return [];
      }

      // Get all holdings for this portfolio without filtering so we get all IDs
      const portfolioHoldings = await db.query.holdings.findMany({
        where: eq(holdings.portfolioId, portfolioId)
      });
      
      // Early return if no holdings exist
      if (!portfolioHoldings || portfolioHoldings.length === 0) {
        console.log(`No holdings found for portfolio ${portfolioId}`);
        return [];
      }
      
      const holdingIds = portfolioHoldings.map(h => h.id);
      console.log(`Found ${holdingIds.length} holdings for portfolio ${portfolioId}`);
      
      // Use a safer approach - direct SQL query to avoid ORM mapping issues
      try {
        // Use raw SQL instead of ORM methods
        const result = await db.execute(
          `SELECT t.*, h.symbol FROM transactions t
           JOIN holdings h ON t.holding_id = h.id
           WHERE h.portfolio_id = $1
           ORDER BY t.date DESC`,
          [portfolioId]
        );
        
        return result.rows || [];
      } catch (sqlError) {
        console.error(`SQL error getting transactions for portfolio ${portfolioId}:`, sqlError);
        
        // Fallback to the safer per-holding approach
        let allTransactions = [];
        
        // Process each holding ID individually
        for (const holdingId of holdingIds) {
          try {
            const holdingTransactions = await db.execute(
              `SELECT * FROM transactions WHERE holding_id = $1`,
              [holdingId]
            );
            
            // Get the symbol for this holding
            const holding = portfolioHoldings.find(h => h.id === holdingId);
            const symbol = holding ? holding.symbol : 'Unknown';
            
            // Add symbol to each transaction
            const txnsWithSymbol = (holdingTransactions.rows || []).map(txn => ({
              ...txn,
              symbol
            }));
            
            allTransactions = [...allTransactions, ...txnsWithSymbol];
          } catch (holdingError) {
            console.error(`Error fetching transactions for holding ${holdingId}:`, holdingError);
          }
        }
        
        // Sort transactions by date
        allTransactions.sort((a, b) => new Date(b.date) - new Date(a.date));
        
        return allTransactions;
      }
    } catch (error) {
      console.error(`Error fetching transactions for portfolio ${portfolioId}:`, error);
      return []; // Return empty array on error
    }
  }
};

module.exports = portfolioService;