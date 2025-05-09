const { db } = require('../src/config/database');
const { paperPortfolios, paperTrades } = require('../src/models/paperTrading');
const { eq } = require('drizzle-orm');

async function validatePortfolioBalances() {
  try {
    console.log('Validating all portfolio balances...');
    
    // Get all portfolios
    const portfolios = await db.select().from(paperPortfolios);
    console.log(`Found ${portfolios.length} portfolios to validate`);
    
    for (const portfolio of portfolios) {
      try {
        console.log(`\nValidating Portfolio #${portfolio.id}:`);
        console.log(`- Current balance: ${portfolio.current_balance} (${typeof portfolio.current_balance})`);
        console.log(`- Initial balance: ${portfolio.initial_balance} (${typeof portfolio.initial_balance})`);
        
        // Validate current_balance is a valid number
        const currentBalance = parseFloat(portfolio.current_balance);
        if (isNaN(currentBalance)) {
          console.error(`❌ Invalid current_balance: "${portfolio.current_balance}"`);
        } else {
          console.log(`✓ Valid current_balance: ${currentBalance}`);
        }
        
        // Get all trades for this portfolio
        const trades = await db.select()
          .from(paperTrades)
          .where(eq(paperTrades.portfolio_id, portfolio.id));
        
        console.log(`- Found ${trades.length} trades`);
        
        // Calculate expected balance
        let calculatedBalance = parseFloat(portfolio.initial_balance) || 150000;
        let validTrades = true;
        
        for (const trade of trades) {
          try {
            const tradeAmount = parseFloat(trade.total_amount);
            if (isNaN(tradeAmount)) {
              console.error(`❌ Invalid trade amount: "${trade.total_amount}" for trade ID ${trade.id}`);
              validTrades = false;
            } else {
              if (trade.type === 'BUY') {
                calculatedBalance -= tradeAmount;
              } else if (trade.type === 'SELL') {
                calculatedBalance += tradeAmount;
              } else {
                console.warn(`⚠️ Unknown trade type: "${trade.type}" for trade ID ${trade.id}`);
              }
            }
          } catch (tradeError) {
            console.error(`❌ Error processing trade ID ${trade.id}:`, tradeError);
            validTrades = false;
          }
        }
        
        console.log(`- Calculated balance: ${calculatedBalance}`);
        
        // Compare calculated balance with stored balance
        if (!isNaN(currentBalance)) {
          const difference = currentBalance - calculatedBalance;
          if (Math.abs(difference) > 0.01) {
            console.error(`❌ Balance mismatch: stored=${currentBalance}, calculated=${calculatedBalance}, difference=${difference}`);
          } else {
            console.log(`✓ Balance matches calculated value (within rounding error)`);
          }
        }
        
        // Fix the balance if needed
        if (isNaN(currentBalance) || (validTrades && Math.abs(currentBalance - calculatedBalance) > 0.01)) {
          console.log(`Fixing balance for portfolio ${portfolio.id}...`);
          
          await db.update(paperPortfolios)
            .set({
              current_balance: calculatedBalance,
              updated_at: new Date()
            })
            .where(eq(paperPortfolios.id, portfolio.id));
            
          console.log(`✓ Fixed balance from ${portfolio.current_balance} to ${calculatedBalance}`);
        }
      } catch (portfolioError) {
        console.error(`❌ Error validating portfolio ${portfolio.id}:`, portfolioError);
      }
    }
    
    console.log('\nPortfolio balance validation completed');
  } catch (error) {
    console.error('Error validating portfolio balances:', error);
  } finally {
    process.exit();
  }
}

validatePortfolioBalances();
