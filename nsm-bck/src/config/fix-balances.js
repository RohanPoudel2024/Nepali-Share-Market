const { db } = require('./database');
const { paperPortfolios, paperTrades } = require('../models/paperTrading');
const { eq, asc } = require('drizzle-orm');

async function fixAllPortfolioBalances() {
  try {
    console.log('Running portfolio balance verification and repair...');
    
    // Get all portfolios
    const portfolios = await db.select().from(paperPortfolios);
    console.log(`Found ${portfolios.length} portfolios to check`);
    
    for (const portfolio of portfolios) {
      try {
        console.log(`Checking portfolio ${portfolio.id} (${portfolio.name})...`);
        
        // Check if initial balance is valid
        let initialBalance = parseFloat(portfolio.initial_balance);
        if (isNaN(initialBalance) || initialBalance <= 0) {
          initialBalance = 150000;
          console.log(`Fixing invalid initial_balance to ${initialBalance}`);
          
          await db.update(paperPortfolios)
            .set({ initial_balance: initialBalance })
            .where(eq(paperPortfolios.id, portfolio.id));
        }
        
        // Check if current balance is valid
        let currentBalance = parseFloat(portfolio.current_balance);
        const isCurrentBalanceValid = !isNaN(currentBalance) && 
                                    currentBalance !== null && 
                                    currentBalance !== undefined;
                                    
        if (!isCurrentBalanceValid) {
          console.log(`Invalid current_balance: ${portfolio.current_balance} - recalculating`);
          
          // Get trades and recalculate balance
          const trades = await db.select()
            .from(paperTrades)
            .where(eq(paperTrades.portfolio_id, portfolio.id))
            .orderBy(asc(paperTrades.created_at));
            
          let calculatedBalance = initialBalance;
          
          for (const trade of trades) {
            const tradeAmount = parseFloat(trade.total_amount);
            if (!isNaN(tradeAmount)) {
              if (trade.type.toUpperCase() === 'BUY') {
                calculatedBalance -= tradeAmount;
              } else if (trade.type.toUpperCase() === 'SELL') {
                calculatedBalance += tradeAmount;
              }
            }
          }
          
          // Apply fix with proper rounding
          calculatedBalance = Math.round(calculatedBalance * 100) / 100;
          console.log(`Setting current_balance to ${calculatedBalance}`);
          
          await db.update(paperPortfolios)
            .set({ 
              current_balance: calculatedBalance,
              updated_at: new Date()
            })
            .where(eq(paperPortfolios.id, portfolio.id));
            
          console.log(`Fixed balance for portfolio ${portfolio.id}`);
        } else {
          console.log(`Balance for portfolio ${portfolio.id} is valid (${currentBalance})`);
        }
      } catch (e) {
        console.error(`Error processing portfolio ${portfolio.id}:`, e);
      }
    }
    
    console.log('Portfolio balance verification completed');
    return true;
  } catch (e) {
    console.error('Error in balance verification:', e);
    return false;
  }
}

module.exports = { fixAllPortfolioBalances };