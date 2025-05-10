const { eq, and, desc, asc } = require('drizzle-orm');
const { db } = require('../config/database');
const { paperPortfolios, paperHoldings, paperTrades } = require('../models/paperTrading');

// Ensure numeric validation before any DB operations
const ensureNumeric = (value, defaultValue = 150000) => {
  // If the value is already a number, just ensure it's valid
  if (typeof value === 'number') {
    return isNaN(value) ? defaultValue : value;
  }
  
  // If it's a string, try to parse it
  if (typeof value === 'string' && value.trim() !== '') {
    const parsed = parseFloat(value);
    return !isNaN(parsed) ? parsed : defaultValue;
  }
  
  // For null/undefined or other types, return default
  return defaultValue;
};

// Add a special function for portfolio balance that's more careful
const getPortfolioBalance = async (tx, portfolioId) => {
  try {
    // Use proper field selection with select() instead of query builder
    const result = await tx
      .select({
        current_balance: paperPortfolios.current_balance,
        initial_balance: paperPortfolios.initial_balance,
      })
      .from(paperPortfolios)
      .where(eq(paperPortfolios.id, portfolioId))
      .limit(1);
    
    if (!result || result.length === 0) return 150000;
    
    // Check if we can directly parse the balance
    const balance = parseFloat(result[0].current_balance);
    if (!isNaN(balance)) return balance;
    
    // If not, try to calculate it from trade history
    console.log(`Invalid balance detected for portfolio ${portfolioId}, recalculating...`);
    return await paperTradingService.recalculateBalanceFromTrades(portfolioId);
  } catch (error) {
    console.error('Error retrieving portfolio balance:', error);
    return 150000;
  }
};

const paperTradingService = {
  // Ensure user has at least one portfolio - automatically create if not
  ensureUserHasPortfolio: async (userId) => {
    try {
      // Get user's portfolios
      const portfolios = await db.query.paperPortfolios.findMany({
        where: userId ? eq(paperPortfolios.user_id, userId) : undefined
      });
      
      // If no portfolios exist, create a default one
      if (!portfolios || portfolios.length === 0) {
        console.log('No portfolios found for user, creating default portfolio');
        return await paperTradingService.createPortfolio(userId, {
          name: "Paper Trading Portfolio",
          description: "Trade with NPR 150,000 virtual money without risk!",
          initialBalance: 150000
        });
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
      // First ensure user has at least one portfolio
      await paperTradingService.ensureUserHasPortfolio(userId);
      
      // Now get all portfolios (should have at least one)
      const portfolios = await db.query.paperPortfolios.findMany({
        where: userId ? eq(paperPortfolios.user_id, userId) : undefined
      });
      
      return portfolios || [];
    } catch (error) {
      console.error('Error fetching user portfolios:', error);
      throw error;
    }
  },

  // Get a specific portfolio with holdings and calculated metrics
  getPortfolioDetails: async (portfolioId) => {
    try {
      // Get portfolio with consistent query approach
      const portfolio = await db.query.paperPortfolios.findFirst({
        where: eq(paperPortfolios.id, portfolioId)
      });
      
      if (!portfolio) {
        throw new Error('Portfolio not found');
      }
      
      // Always convert balance to number to ensure consistent type
      let currentBalance = parseFloat(portfolio.current_balance);
      if (isNaN(currentBalance)) {
        console.warn(`Warning: Invalid balance detected for portfolio ${portfolioId}`);
        // Calculate balance now to avoid returning invalid value
        currentBalance = await paperTradingService.recalculateBalanceFromTrades(portfolioId);
        
        // Update in database to fix for future requests
        await db.update(paperPortfolios)
          .set({ current_balance: currentBalance })
          .where(eq(paperPortfolios.id, portfolioId));
          
        // Update the portfolio object
        portfolio.current_balance = currentBalance;
      }
      
      // Get holdings
      const holdings = await db.query.paperHoldings.findMany({
        where: and(
          eq(paperHoldings.portfolio_id, portfolioId),
          eq(paperHoldings.is_active, true)
        )
      });

      // Calculate portfolio metrics
      let totalInvestment = 0;      // Current value of investments at purchase price
      let totalMarketValue = 0;     // Current market value of holdings (using latest prices)
      
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
      
      // Return complete portfolio with calculated metrics
      return {
        ...portfolio,
        holdings,
        totalInvestment: Number(totalInvestment),
        totalMarketValue: Number(totalMarketValue),
        totalPortfolioValue: Number(currentBalance) + Number(totalMarketValue),
        totalProfit: Number(totalMarketValue) - Number(totalInvestment),
        profitPercentage: Number(totalInvestment) > 0 
          ? ((Number(totalMarketValue) - Number(totalInvestment)) / Number(totalInvestment)) * 100 
          : 0,
        cashBalance: Number(currentBalance)
      };
    } catch (error) {
      console.error('Error fetching portfolio details:', error);
      throw error;
    }
  },

  // Create new portfolio with safeguards
  createPortfolio: async (userId, portfolioData) => {
    try {
      // Ensure initial_balance is a valid number
      let initialBalance = 150000; // Default
      
      if (portfolioData.initialBalance !== undefined) {
        const parsedInitial = parseFloat(portfolioData.initialBalance);
        if (!isNaN(parsedInitial) && parsedInitial > 0) {
          initialBalance = parsedInitial;
        }
      }
      
      // Create new portfolio with validated balance
      const result = await db.insert(paperPortfolios).values({
        user_id: userId || null,
        name: portfolioData.name || "Paper Portfolio",
        description: portfolioData.description || "Trade with NPR 150,000 virtual money without risk!",
        initial_balance: initialBalance,
        current_balance: initialBalance, // Always matches initial at creation
        created_at: new Date(),
        updated_at: new Date()
      }).returning();

      return result[0];
    } catch (error) {
      console.error('Error creating portfolio:', error);
      throw error;
    }
  },

  // Improved execute trade function with transaction
  executeTrade: async (portfolioId, tradeData) => {
    const { symbol, type, quantity, price, companyName } = tradeData;
    
    // Validate numeric values BEFORE starting transaction
    const parsedQuantity = ensureNumeric(quantity, 0);
    const parsedPrice = ensureNumeric(price, 0);
    
    if (parsedQuantity <= 0) {
      throw new Error(`Invalid quantity: ${quantity}`);
    }
    
    if (parsedPrice <= 0) {
      throw new Error(`Invalid price: ${price}`);
    }
    
    // Calculate total with proper rounding
    const tradeAmount = Math.round(parsedQuantity * parsedPrice * 100) / 100;
    
    return await db.transaction(async (tx) => {
      try {
        // Lock portfolio row for update to prevent race conditions
        const portfolio = await tx.query.paperPortfolios.findFirst({
          where: eq(paperPortfolios.id, portfolioId),
          forUpdate: true
        });
        
        if (!portfolio) {
          throw new Error(`Portfolio ${portfolioId} not found`);
        }
        
        // Get current balance - USE NEW FUNCTION INSTEAD OF ensureNumeric
        let currentBalance = await getPortfolioBalance(tx, portfolioId);
        
        if (type.toUpperCase() === 'BUY') {
          // Check sufficient funds
          if (tradeAmount > currentBalance) {
            throw new Error(`Insufficient balance (${currentBalance.toFixed(2)}) for trade (${tradeAmount})`);
          }
          
          // Calculate new balance
          const newBalance = Math.round((currentBalance - tradeAmount) * 100) / 100;
          
          // Update values in database BEFORE adding the trade to ensure consistency
          await tx.update(paperPortfolios)
            .set({ 
              current_balance: newBalance,
              updated_at: new Date()
            })
            .where(eq(paperPortfolios.id, portfolioId));
          
          // Insert the trade record
          const tradeResult = await tx.insert(paperTrades).values({
            portfolio_id: portfolioId,
            symbol,
            company_name: companyName,
            type: 'BUY',
            quantity: parsedQuantity,
            price: parsedPrice,
            total_amount: tradeAmount,
            trade_date: new Date(),
            created_at: new Date()
          }).returning();
          
          // Update or create holding
          const existingHolding = await tx.query.paperHoldings.findFirst({
            where: and(
              eq(paperHoldings.portfolio_id, portfolioId),
              eq(paperHoldings.symbol, symbol),
              eq(paperHoldings.is_active, true)
            )
          });
          
          if (existingHolding) {
            // Update existing holding
            const newQuantity = parseFloat(existingHolding.quantity) + parsedQuantity;
            const newAvgPrice = (
              (parseFloat(existingHolding.quantity) * parseFloat(existingHolding.average_buy_price)) +
              (parsedQuantity * parsedPrice)
            ) / newQuantity;
            
            await tx.update(paperHoldings)
              .set({
                quantity: newQuantity,
                average_buy_price: newAvgPrice,
                updated_at: new Date()
              })
              .where(eq(paperHoldings.id, existingHolding.id));
          } else {
            // Create new holding
            await tx.insert(paperHoldings).values({
              portfolio_id: portfolioId,
              symbol,
              company_name: companyName,
              quantity: parsedQuantity,
              average_buy_price: parsedPrice,
              buy_price: parsedPrice,
              is_active: true,
              created_at: new Date(),
              updated_at: new Date()
            });
          }
          
          return tradeResult[0];
        }
        else if (type.toUpperCase() === 'SELL') {
          // Check holdings
          const holding = await tx.query.paperHoldings.findFirst({
            where: and(
              eq(paperHoldings.portfolio_id, portfolioId),
              eq(paperHoldings.symbol, symbol),
              eq(paperHoldings.is_active, true)
            )
          });
          
          if (!holding || parseFloat(holding.quantity) < parsedQuantity) {
            throw new Error(`Insufficient ${symbol} holdings to sell`);
          }
          
          // Calculate new balance
          const newBalance = Math.round((currentBalance + tradeAmount) * 100) / 100;
          
          // Insert the trade record
          const tradeResult = await tx.insert(paperTrades).values({
            portfolio_id: portfolioId,
            symbol,
            company_name: companyName,
            type: 'SELL',
            quantity: parsedQuantity,
            price: parsedPrice,
            total_amount: tradeAmount,
            trade_date: new Date(),
            created_at: new Date()
          }).returning();
          
          // Update portfolio balance
          await tx.update(paperPortfolios)
            .set({ 
              current_balance: newBalance,
              updated_at: new Date()
            })
            .where(eq(paperPortfolios.id, portfolioId));
          
          // Update holding quantity
          const remainingQuantity = parseFloat(holding.quantity) - parsedQuantity;
          
          if (remainingQuantity <= 0) {
            // Mark as inactive instead of deleting
            await tx.update(paperHoldings)
              .set({
                quantity: 0,
                is_active: false,
                updated_at: new Date()
              })
              .where(eq(paperHoldings.id, holding.id));
          } else {
            // Update quantity
            await tx.update(paperHoldings)
              .set({
                quantity: remainingQuantity,
                updated_at: new Date()
              })
              .where(eq(paperHoldings.id, holding.id));
          }
          
          return tradeResult[0];
        }
        else {
          throw new Error(`Invalid trade type: ${type}`);
        }
      } catch (error) {
        console.error('Transaction error:', error);
        throw error;
      }
    });
  },

  // Calculate correct balance from initial balance and trade history
  async recalculateBalanceFromTrades(portfolioId) {
    try {
      // Get portfolio to find initial balance
      const portfolio = await db.query.paperPortfolios.findFirst({
        where: eq(paperPortfolios.id, portfolioId)
      });
      
      if (!portfolio) {
        throw new Error(`Portfolio ${portfolioId} not found`);
      }
      
      // Start with initial balance or default to 150000
      let initialBalance = parseFloat(portfolio.initial_balance);
      if (isNaN(initialBalance)) {
        initialBalance = 150000;
        
        // Fix the initial balance in the database too
        await db.update(paperPortfolios)
          .set({ initial_balance: initialBalance })
          .where(eq(paperPortfolios.id, portfolioId));
      }
      
      // Get all trades for this portfolio in chronological order
      const trades = await db.select()
        .from(paperTrades)
        .where(eq(paperTrades.portfolio_id, portfolioId))
        .orderBy(asc(paperTrades.created_at));
      
      // Calculate balance based on trades
      let calculatedBalance = initialBalance;
      
      for (const trade of trades) {
        const tradeAmount = parseFloat(trade.total_amount);
        if (!isNaN(tradeAmount)) {
          if (trade.type === 'BUY') {
            calculatedBalance -= tradeAmount;
          } else if (trade.type === 'SELL') {
            calculatedBalance += tradeAmount;
          }
        }
      }
      
      // Round to avoid floating point issues
      return Math.round(calculatedBalance * 100) / 100;
    } catch (error) {
      console.error('Error recalculating balance:', error);
      throw error;
    }
  },

  // Fix portfolio balance issues
  fixPortfolioBalance: async (portfolioId) => {
    try {
      console.log(`Fixing balance for portfolio ${portfolioId}`);
      
      // Recalculate the correct balance
      const calculatedBalance = await paperTradingService.recalculateBalanceFromTrades(portfolioId);
      
      // Update the balance in the database
      const result = await db.update(paperPortfolios)
        .set({
          current_balance: calculatedBalance,
          updated_at: new Date()
        })
        .where(eq(paperPortfolios.id, portfolioId))
        .returning();
      
      return result[0];
    } catch (error) {
      console.error('Error fixing portfolio balance:', error);
      throw error;
    }
  },

  // Get trade history for a portfolio
  getTradeHistory: async (portfolioId) => {
    try {
      // Query trades directly with more error handling
      const trades = await db.select()
        .from(paperTrades)
        .where(eq(paperTrades.portfolio_id, portfolioId))
        .orderBy(desc(paperTrades.created_at));
      
      // Ensure we always return an array
      return Array.isArray(trades) ? trades : [];
    } catch (error) {
      console.error('Error fetching trade history:', error);
      return []; // Return empty array on error
    }
  },
  
  // Update stock prices in holdings
  updateHoldingsPrices: async (portfolioId, priceMap) => {
    try {
      // Get all active holdings
      const holdings = await db.query.paperHoldings.findMany({
        where: and(
          eq(paperHoldings.portfolio_id, portfolioId),
          eq(paperHoldings.is_active, true)
        )
      });
      
      // Update each holding with the latest price
      for (const holding of holdings) {
        const latestPrice = priceMap[holding.symbol];
        if (latestPrice && latestPrice > 0) {
          await db.update(paperHoldings)
            .set({
              current_price: latestPrice,
              updated_at: new Date()
            })
            .where(eq(paperHoldings.id, holding.id));
        }
      }
      
      return true;
    } catch (error) {
      console.error('Error updating holdings prices:', error);
      return false;
    }
  }
};

module.exports = paperTradingService;