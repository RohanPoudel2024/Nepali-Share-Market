const { eq, and, desc, asc } = require('drizzle-orm');
const { db } = require('../config/database');
const { paperPortfolios, paperHoldings, paperTrades } = require('../models/paperTrading');

const paperTradingService = {
  // Ensure user has at least one portfolio
  ensureUserHasPortfolio: async (userId) => {
    try {
      // Get user's portfolios
      const portfolios = await db.query.paperPortfolios.findMany({
        where: userId ? eq(paperPortfolios.user_id, userId) : undefined
      });
      
      // If no portfolios exist, create a default one
      if (!portfolios || portfolios.length === 0) {
        console.log('No portfolios found for user, creating default portfolio');
        const defaultPortfolio = await paperTradingService.createPortfolio(userId, {
          name: "Default Paper Portfolio",
          description: "Trade with NPR 150,000 virtual money without risk!",
          initialBalance: 150000
        });
        
        return defaultPortfolio;
      }
      
      return portfolios[0]; // Return the first portfolio
    } catch (error) {
      console.error('Error ensuring user has portfolio:', error);
      throw error;
    }
  },

  // Get all portfolios for a user
  getUserPortfolios: async (userId) => {
    try {
      const portfolios = await db.query.paperPortfolios.findMany({
        where: userId ? eq(paperPortfolios.user_id, userId) : undefined
      });
      
      if (!portfolios || portfolios.length === 0) {
        const defaultPortfolio = await paperTradingService.ensureUserHasPortfolio(userId);
        return [defaultPortfolio];
      }
      
      return portfolios;
    } catch (error) {
      console.error('Error fetching user portfolios:', error);
      throw error;
    }
  },

  // Get a specific portfolio with holdings
  getPortfolioDetails: async (portfolioId) => {
    try {
      // Get portfolio
      const portfolio = await db.query.paperPortfolios.findFirst({
        where: eq(paperPortfolios.id, portfolioId)
      });
      
      if (!portfolio) {
        throw new Error('Portfolio not found');
      }
      
      // Get holdings - don't filter by is_active since the column might not exist yet
      const holdings = await db.query.paperHoldings.findMany({
        where: eq(paperHoldings.portfolio_id, portfolioId)
      });

      // Calculate portfolio metrics
      let totalInvestment = 0;      // Current value of investments
      let totalMarketValue = 0;     // Current market value of holdings
      let cumulativePurchases = 0;  // Track total money spent on purchases
      
      if (holdings && holdings.length > 0) {
        holdings.forEach(holding => {
          // Calculate investment value using average buy price
          const investmentValue = parseFloat(holding.quantity) * parseFloat(holding.average_buy_price);
          totalInvestment += investmentValue;
          
          // For market value, use current price if available, otherwise use average buy price
          const currentPrice = holding.current_price || holding.average_buy_price;
          const marketValue = parseFloat(holding.quantity) * parseFloat(currentPrice);
          totalMarketValue += marketValue;
          
          // Add these values to the holding object for convenience
          holding.investmentValue = investmentValue;
          holding.marketValue = marketValue;
          holding.profit = marketValue - investmentValue;
          holding.profitPercentage = investmentValue > 0 ? (holding.profit / investmentValue) * 100 : 0;
        });
      }
      
      // Calculate cumulative purchases from trade history
      const trades = await db.select()
        .from(paperTrades)
        .where(eq(paperTrades.portfolio_id, portfolioId));
      
      if (trades && trades.length > 0) {
        trades.forEach(trade => {
          if (trade.type === 'BUY') {
            cumulativePurchases += parseFloat(trade.total_amount);
          }
        });
      }
      
      // Calculate total portfolio value (cash + holdings market value)
      const totalPortfolioValue = parseFloat(portfolio.current_balance) + totalMarketValue;
      
      // Return combined data with calculated fields
      return {
        ...portfolio,
        holdings,
        totalInvestment,             // Current value of investments (qty × avg price)
        cumulativePurchases,         // Total money spent on purchases historically
        totalMarketValue,            // Current market value of holdings only
        totalPortfolioValue,         // Cash + market value of holdings
        totalProfit: totalMarketValue - totalInvestment,
        profitPercentage: totalInvestment > 0 ? ((totalMarketValue - totalInvestment) / totalInvestment) * 100 : 0,
        cashBalance: parseFloat(portfolio.current_balance)
      };
    } catch (error) {
      console.error('Error fetching portfolio details:', error);
      throw error;
    }
  },

  // Create new portfolio
  createPortfolio: async (userId, portfolioData) => {
    try {
      // Insert portfolio with safeguards for missing user
      const result = await db.insert(paperPortfolios).values({
        user_id: userId || null, // Handle null/undefined userId gracefully
        name: portfolioData.name,
        description: portfolioData.description,
        initial_balance: portfolioData.initialBalance || 150000,
        current_balance: portfolioData.initialBalance || 150000
      }).returning();

      return result[0];
    } catch (error) {
      console.error('Error creating portfolio:', error);
      throw error;
    }
  },

  // Fix portfolio balance if it's zero or invalid
  resetPortfolioBalance: async (portfolioId, newBalance = 150000) => {
    try {
      console.log(`Resetting portfolio ${portfolioId} balance to ${newBalance}`);
      
      const result = await db.update(paperPortfolios)
        .set({
          current_balance: newBalance,
          updated_at: new Date()
        })
        .where(eq(paperPortfolios.id, portfolioId))
        .returning();
      
      return result[0];
    } catch (error) {
      console.error('Error resetting portfolio balance:', error);
      throw error;
    }
  },

  // Add this new function to directly update portfolio balance
  updatePortfolioBalance: async (portfolioId, newBalance) => {
    try {
      console.log(`Updating portfolio ${portfolioId} balance to ${newBalance}`);
      
      const result = await db.update(paperPortfolios)
        .set({
          current_balance: newBalance,
          updated_at: new Date()
        })
        .where(eq(paperPortfolios.id, portfolioId))
        .returning();
      
      return result[0];
    } catch (error) {
      console.error('Error updating portfolio balance:', error);
      throw error;
    }
  },

  // Execute a trade
  executeTrade: async (portfolioId, tradeData) => {
    const { symbol, type, quantity, price, companyName } = tradeData;
    
    return await db.transaction(async (tx) => {
      try {
        // Get portfolio
        const portfolio = await tx.query.paperPortfolios.findFirst({
          where: eq(paperPortfolios.id, portfolioId)
        });
        
        if (!portfolio) {
          throw new Error('Portfolio not found');
        }
        
        // Calculate amount for this trade
        const tradeQuantity = parseFloat(quantity);
        const tradePrice = parseFloat(price);
        const totalAmount = tradeQuantity * tradePrice;
        
        console.log(`Calculating trade: ${type} ${tradeQuantity} ${symbol} at ${tradePrice} = ${totalAmount}`);
        
        // IMPROVED BALANCE HANDLING: More permissive validation with built-in recovery
        let currentBalance;
        
        // Try to directly parse the current balance
        try {
          currentBalance = parseFloat(portfolio.current_balance);
          
          // If we get NaN, try more aggressive parsing approaches
          if (isNaN(currentBalance)) {
            console.warn(`Portfolio ${portfolioId} has invalid balance format: "${portfolio.current_balance}"`);
            
            // Try to extract a number from the string if it's a string
            if (typeof portfolio.current_balance === 'string') {
              // Try to extract numeric part with regex
              const match = portfolio.current_balance.match(/\d+(\.\d+)?/);
              if (match) {
                currentBalance = parseFloat(match[0]);
                console.log(`Extracted numeric value ${currentBalance} from "${portfolio.current_balance}"`);
              }
            }
            
            // If still NaN, recover from initial balance
            if (isNaN(currentBalance) && portfolio.initial_balance) {
              currentBalance = parseFloat(portfolio.initial_balance);
              console.log(`Using initial_balance as fallback: ${currentBalance}`);
            }
            
            // If still NaN, use transaction history to calculate balance
            if (isNaN(currentBalance)) {
              // Get all trades for this portfolio
              const trades = await tx.select()
                .from(paperTrades)
                .where(eq(paperTrades.portfolio_id, portfolioId));
              
              // Use a safe default
              currentBalance = 150000;
              
              // Apply all trades
              for (const trade of trades) {
                if (trade.type === 'BUY') {
                  currentBalance -= parseFloat(trade.total_amount);
                } else if (trade.type === 'SELL') {
                  currentBalance += parseFloat(trade.total_amount);
                }
              }
              
              console.log(`Calculated balance from trade history: ${currentBalance}`);
            }
            
            // If STILL NaN, use default value as last resort
            if (isNaN(currentBalance)) {
              currentBalance = 150000;
              console.log(`Using default balance as last resort: ${currentBalance}`);
            }
            
            // UPDATE the portfolio with the fixed balance immediately
            await tx.update(paperPortfolios)
              .set({ 
                current_balance: currentBalance,
                updated_at: new Date()
              })
              .where(eq(paperPortfolios.id, portfolioId));
              
            console.log(`Fixed portfolio ${portfolioId} balance to ${currentBalance}`);
          } else {
            console.log(`Valid balance found: ${currentBalance}`);
          }
        } catch (e) {
          console.error('Error processing balance:', e);
          throw new Error(`Failed to process portfolio balance: ${e.message}`);
        }
        
        // Add additional validation to ensure we have a valid balance at this point
        if (isNaN(currentBalance)) {
          throw new Error(`Cannot determine valid balance for portfolio ${portfolioId} after multiple recovery attempts`);
        }
        
        let newBalance = currentBalance;
        
        // Remaining trade logic
        // ...existing code...
      } catch (error) {
        console.error('Transaction error:', error);
        throw error;
      }
    });
  },

  // New method to diagnose and fix balance issues
  diagnoseAndFixBalance: async (portfolioId) => {
    try {
      console.log(`Diagnosing balance issues for portfolio ${portfolioId}`);
      
      // Get the portfolio
      const portfolio = await db.query.paperPortfolios.findFirst({
        where: eq(paperPortfolios.id, portfolioId)
      });
      
      if (!portfolio) {
        throw new Error(`Portfolio ${portfolioId} not found`);
      }
      
      console.log(`Current balance value: "${portfolio.current_balance}" (${typeof portfolio.current_balance})`);
      console.log(`Initial balance value: "${portfolio.initial_balance}" (${typeof portfolio.initial_balance})`);
      
      // Get all trades for this portfolio
      const trades = await db.select()
        .from(paperTrades)
        .where(eq(paperTrades.portfolio_id, portfolioId));
      
      console.log(`Found ${trades.length} trades for portfolio ${portfolioId}`);
      
      // Calculate balance based on initial and trades
      let calculatedBalance = parseFloat(portfolio.initial_balance) || 150000;
      
      // Apply all trades
      for (const trade of trades) {
        if (trade.type === 'BUY') {
          calculatedBalance -= parseFloat(trade.total_amount);
        } else if (trade.type === 'SELL') {
          calculatedBalance += parseFloat(trade.total_amount);
        }
      }
      
      console.log(`Calculated correct balance: ${calculatedBalance}`);
      
      // Fix the balance in the database
      const result = await db.update(paperPortfolios)
        .set({
          current_balance: calculatedBalance,
          updated_at: new Date()
        })
        .where(eq(paperPortfolios.id, portfolioId))
        .returning();
      
      console.log(`Updated portfolio balance from ${portfolio.current_balance} to ${calculatedBalance}`);
      
      return {
        original: portfolio.current_balance,
        fixed: calculatedBalance,
        portfolio: result[0]
      };
    } catch (error) {
      console.error('Error diagnosing/fixing balance:', error);
      throw error;
    }
  },

  // Get trade history for a portfolio
  getTradeHistory: async (portfolioId) => {
    try {
      console.log(`Fetching trade history for portfolio ${portfolioId}`);
      
      // First verify the portfolio exists
      const portfolio = await db.query.paperPortfolios.findFirst({
        where: eq(paperPortfolios.portfolio_id || paperPortfolios.id, portfolioId)
      });
      
      if (!portfolio) {
        console.warn(`Portfolio ${portfolioId} not found`);
        return [];
      }
      
      // Query trades directly with more error handling
      const trades = await db.select()
        .from(paperTrades)
        .where(eq(paperTrades.portfolio_id, portfolioId))
        .orderBy(desc(paperTrades.created_at));
      
      console.log(`Found ${trades?.length || 0} trades for portfolio ${portfolioId}`);
      
      // Ensure we always return an array
      return Array.isArray(trades) ? trades : [];
    } catch (error) {
      console.error('Error fetching trade history:', error);
      return []; // Return empty array on error
    }
  }
};

module.exports = paperTradingService;