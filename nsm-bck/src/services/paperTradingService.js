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
        
        // Simple balance handling - no recovery logic
        let currentBalance = parseFloat(portfolio.current_balance);
        
        if (isNaN(currentBalance)) {
          throw new Error(`Invalid balance format in database. Please contact support.`);
        }
        
        console.log(`Current portfolio balance: ${currentBalance}`);
        
        let newBalance = currentBalance;
        
        // Handle buy/sell logic
        if (type.toUpperCase() === 'BUY') {
          // Check if user has enough balance for the purchase
          if (currentBalance < totalAmount) {
            throw new Error(`Insufficient balance. Need Rs. ${totalAmount.toFixed(2)} but you have Rs. ${currentBalance.toFixed(2)}`);
          }

          // Update cash balance
          newBalance = currentBalance - totalAmount;
          console.log(`BUYING: Updating portfolio balance from ${currentBalance} to ${newBalance}`);
          
          // Update portfolio balance in database
          await tx.update(paperPortfolios)
            .set({ 
              current_balance: newBalance,
              updated_at: new Date()
            })
            .where(eq(paperPortfolios.id, portfolioId));
            
          console.log(`Balance updated successfully for BUY: ${currentBalance} -> ${newBalance}`);
          
          // Check if holding exists
          const existingHolding = await tx.query.paperHoldings.findFirst({
            where: and(
              eq(paperHoldings.portfolio_id, portfolioId),
              eq(paperHoldings.symbol, symbol)
            )
          });

          if (existingHolding) {
            // Update existing holding - adjust average price using weighted average
            console.log('Updating existing holding:', existingHolding);
            
            // Ensure all values are proper numbers
            const existingQuantity = parseFloat(existingHolding.quantity) || 0;
            const existingAvgPrice = parseFloat(existingHolding.average_buy_price) || 0;
            const newQuantity = existingQuantity + tradeQuantity;
            
            // Protect against division by zero and NaN
            let newAvgPrice;
            if (newQuantity > 0) {
              const totalValue = (existingQuantity * existingAvgPrice) + (tradeQuantity * tradePrice);
              newAvgPrice = totalValue / newQuantity;
              
              // Final validation to guarantee we never store NaN
              if (isNaN(newAvgPrice)) {
                console.error('Got NaN for average price calculation!');
                console.log(`existingQuantity: ${existingQuantity}, existingAvgPrice: ${existingAvgPrice}`);
                console.log(`tradeQuantity: ${tradeQuantity}, tradePrice: ${tradePrice}`);
                console.log(`newQuantity: ${newQuantity}`);
                
                // Fallback to current trade price if calculation failed
                newAvgPrice = tradePrice; 
              }
            } else {
              newAvgPrice = existingAvgPrice; // Handle edge case
            }
            
            console.log(`Calculated new average price: ${newAvgPrice} from existing=${existingAvgPrice} and new=${tradePrice}`);
            
            await tx.update(paperHoldings)
              .set({ 
                quantity: newQuantity,
                average_buy_price: newAvgPrice,
                updated_at: new Date()
              })
              .where(eq(paperHoldings.id, existingHolding.id));
              
            console.log(`Updated holding: quantity ${existingQuantity} -> ${newQuantity}, avg price ${existingAvgPrice} -> ${newAvgPrice}`);
          } else {
            // Create new holding
            console.log('Creating new holding for', symbol);
            
            await tx.insert(paperHoldings).values({
              portfolio_id: portfolioId,
              symbol,
              company_name: companyName || symbol,
              quantity: tradeQuantity,
              average_buy_price: tradePrice,
              buy_price: tradePrice,
              is_active: true,
              created_at: new Date(),
              updated_at: new Date()
            });
          }
        } else if (type.toUpperCase() === 'SELL') {
          // Check if holding exists and has enough quantity
          const existingHolding = await tx.query.paperHoldings.findFirst({
            where: and(
              eq(paperHoldings.portfolio_id, portfolioId),
              eq(paperHoldings.symbol, symbol)
            )
          });

          if (!existingHolding) {
            throw new Error(`You don't own any shares of ${symbol}`);
          }

          const existingQuantity = parseFloat(existingHolding.quantity);
          if (existingQuantity < tradeQuantity) {
            throw new Error(`Insufficient shares. You only have ${existingQuantity} shares of ${symbol}`);
          }

          // Update cash balance for sell
          newBalance = currentBalance + totalAmount;
          console.log(`SELLING: Updating portfolio balance from ${currentBalance} to ${newBalance}`);
          
          await tx.update(paperPortfolios)
            .set({ 
              current_balance: newBalance,
              updated_at: new Date()
            })
            .where(eq(paperPortfolios.id, portfolioId));
            
          console.log(`Balance updated successfully for SELL: ${currentBalance} -> ${newBalance}`);
          
          // Update holding quantity
          const newQuantity = existingQuantity - tradeQuantity;
          
          if (newQuantity > 0) {
            // Update holding with reduced quantity (average price stays the same)
            await tx.update(paperHoldings)
              .set({ 
                quantity: newQuantity,
                updated_at: new Date()
              })
              .where(eq(paperHoldings.id, existingHolding.id));
              
            console.log(`Updated holding after sell: quantity ${existingQuantity} -> ${newQuantity}`);
          } else {
            // Remove holding if completely sold
            await tx.update(paperHoldings)
              .set({ 
                is_active: false,
                quantity: 0,
                updated_at: new Date()
              })
              .where(eq(paperHoldings.id, existingHolding.id));
              
            console.log(`Holding ${symbol} marked as inactive after complete sell`);
          }
        } else {
          throw new Error('Invalid trade type. Must be BUY or SELL');
        }

        // Record the trade
        const newTrade = await tx.insert(paperTrades).values({
          portfolio_id: portfolioId,
          symbol: symbol,
          type: type.toUpperCase(),
          quantity: tradeQuantity,
          price: tradePrice,
          total_amount: totalAmount,
          trade_date: new Date(),
          created_at: new Date()
        }).returning();

        // Verify the balance was correctly updated in database before returning
        const updatedPortfolio = await tx.query.paperPortfolios.findFirst({
          where: eq(paperPortfolios.id, portfolioId)
        });
        
        console.log(`Verification - Portfolio balance after trade: ${updatedPortfolio.current_balance}`);

        // Return the trade with verified updated portfolio balance
        return {
          ...newTrade[0],
          currentBalance: parseFloat(updatedPortfolio.current_balance)
        };
      } catch (error) {
        console.error('Transaction error:', error);
        throw error;
      }
    });
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