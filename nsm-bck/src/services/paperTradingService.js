const { eq, and } = require('drizzle-orm');
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
      let totalInvestment = 0;
      let totalMarketValue = 0;
      
      if (holdings && holdings.length > 0) {
        holdings.forEach(holding => {
          // Calculate investment value
          const investmentValue = parseFloat(holding.quantity) * parseFloat(holding.average_buy_price);
          totalInvestment += investmentValue;
          
          // For market value, we'd need current prices, but for now use the same
          totalMarketValue += investmentValue;
        });
      }
      
      // Return combined data with calculated fields
      return {
        ...portfolio,
        holdings,
        totalInvestment,
        totalMarketValue,
        totalProfit: totalMarketValue - totalInvestment,
        profitPercentage: totalInvestment > 0 ? ((totalMarketValue - totalInvestment) / totalInvestment) * 100 : 0
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

  // Execute a trade
  executeTrade: async (portfolioId, tradeData) => {
    // Start a transaction
    return await db.transaction(async (tx) => {
      try {
        console.log('Executing trade with data:', { portfolioId, ...tradeData });
        
        // Get portfolio
        const portfolio = await tx.query.paperPortfolios.findFirst({
          where: eq(paperPortfolios.id, portfolioId)
        });
        
        if (!portfolio) {
          throw new Error('Portfolio not found');
        }
        
        const { symbol, type, quantity, price } = tradeData;
        
        // Make sure quantity and price are valid numbers
        const safeQuantity = parseFloat(quantity);
        const safePrice = parseFloat(price);
        
        if (isNaN(safeQuantity) || safeQuantity <= 0) {
          throw new Error('Invalid quantity value');
        }
        
        if (isNaN(safePrice) || safePrice <= 0) {
          throw new Error('Invalid price value');
        }
        
        const totalAmount = safeQuantity * safePrice;
        
        // Continue with the rest of the trade execution logic
        if (type.toUpperCase() === 'BUY') {
          // Check if user has enough balance
          if (parseFloat(portfolio.current_balance) < totalAmount) {
            throw new Error(`Insufficient balance. Need Rs. ${totalAmount.toFixed(2)} but you have Rs. ${parseFloat(portfolio.current_balance).toFixed(2)}`);
          }

          // Update balance - CRITICAL PART
          console.log('Updating portfolio balance from', portfolio.current_balance, 'to', parseFloat(portfolio.current_balance) - totalAmount);
          
          await tx.update(paperPortfolios)
            .set({ 
              current_balance: parseFloat(portfolio.current_balance) - totalAmount,
              updated_at: new Date()
            })
            .where(eq(paperPortfolios.id, portfolioId));
          
          // Check if holding exists
          const existingHolding = await tx.query.paperHoldings.findFirst({
            where: and(
              eq(paperHoldings.portfolio_id, portfolioId),
              eq(paperHoldings.symbol, symbol)
            )
          });

          if (existingHolding) {
            // Update existing holding
            console.log('Updating existing holding:', existingHolding);
            
            const newQuantity = parseFloat(existingHolding.quantity) + safeQuantity;
            const newAvgPrice = ((parseFloat(existingHolding.quantity) * parseFloat(existingHolding.average_buy_price)) + totalAmount) / newQuantity;
            
            await tx.update(paperHoldings)
              .set({ 
                quantity: newQuantity,
                average_buy_price: newAvgPrice,
                updated_at: new Date()
              })
              .where(eq(paperHoldings.id, existingHolding.id));
          } else {
            // Create new holding
            console.log('Creating new holding for', symbol);
            
            await tx.insert(paperHoldings).values({
              portfolio_id: portfolioId,
              symbol,
              company_name: tradeData.companyName || symbol,
              quantity: safeQuantity,
              average_buy_price: safePrice,
              buy_price: safePrice,
              is_active: true,
              created_at: new Date(),
              updated_at: new Date()
            });
          }
        } 
        else if (type.toUpperCase() === 'SELL') {
          // Rest of the sell logic...
        } 
        else {
          throw new Error('Invalid trade type. Must be BUY or SELL');
        }

        // Record the trade
        const tradeResult = await tx.insert(paperTrades).values({
          portfolio_id: portfolioId,
          symbol,
          type: type.toUpperCase(),
          quantity: safeQuantity,
          price: safePrice,
          total_amount: totalAmount,
          trade_date: new Date()
        }).returning();

        return tradeResult[0];
      } catch (error) {
        console.error('Error executing trade transaction:', error);
        throw error;
      }
    });
  },

  // Get trade history for a portfolio
  getTradeHistory: async (portfolioId) => {
    try {
      return await db.query.paperTrades.findMany({
        where: eq(paperTrades.portfolio_id, portfolioId),
        orderBy: (paperTrades, { asc }) => [asc(paperTrades.trade_date)]
      });
    } catch (error) {
      console.error('Error fetching trade history:', error);
      throw error;
    }
  }
};

module.exports = paperTradingService;