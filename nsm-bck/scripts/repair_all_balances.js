const { db } = require('../src/config/database');
const { paperPortfolios, paperTrades } = require('../src/models/paperTrading');
const { eq, asc } = require('drizzle-orm');

async function repairAllBalances() {
  try {
    console.log('Starting comprehensive balance repair for all portfolios...');
    
    // Get all portfolios
    const portfolios = await db.select().from(paperPortfolios);
    console.log(`Found ${portfolios.length} portfolios to repair`);
    
    for (const portfolio of portfolios) {
      try {
        console.log(`\nRepairing Portfolio #${portfolio.id}:`);
        
        // Get all trades for this portfolio
        const trades = await db.select()
          .from(paperTrades)
          .where(eq(paperTrades.portfolio_id, portfolio.id))
          .orderBy(asc(paperTrades.created_at));
        
        console.log(`- Found ${trades.length} trades`);
        
        // Get a consistent initial_balance to start with
        let initialBalance = parseFloat(portfolio.initial_balance);
        if (isNaN(initialBalance) || initialBalance === undefined || initialBalance === null) {
          initialBalance = 150000;
          console.log(`- Fixed invalid initial_balance from ${portfolio.initial_balance} to ${initialBalance}`);
          
          // Fix the initial balance
          await db.update(paperPortfolios)
            .set({ initial_balance: initialBalance })
            .where(eq(paperPortfolios.id, portfolio.id));
        }
        
        // Calculate expected balance
        let calculatedBalance = initialBalance;
        
        for (const trade of trades) {
          try {
            const tradeAmount = parseFloat(trade.total_amount);
            if (!isNaN(tradeAmount)) {
              if (trade.type === 'BUY') {
                calculatedBalance -= tradeAmount;
              } else if (trade.type === 'SELL') {
                calculatedBalance += tradeAmount;
              }
            }
          } catch (tradeError) {
            console.error(`Error processing trade ID ${trade.id}:`, tradeError);
          }
        }
        
        // Round to 2 decimal places
        calculatedBalance = Math.round(calculatedBalance * 100) / 100;
        
        console.log(`- Initial balance: ${initialBalance}`);
        console.log(`- Current stored balance: ${portfolio.current_balance}`);
        console.log(`- Calculated balance: ${calculatedBalance}`);
        
        // Fix the balance if needed
        const currentStored = parseFloat(portfolio.current_balance);
        if (isNaN(currentStored) || Math.abs(currentStored - calculatedBalance) > 0.01) {
          console.log(`⚠️ Fixing balance from ${portfolio.current_balance} to ${calculatedBalance}`);
          
          await db.update(paperPortfolios)
            .set({
              current_balance: calculatedBalance,
              updated_at: new Date()
            })
            .where(eq(paperPortfolios.id, portfolio.id));
            
          console.log(`✅ Balance fixed!`);
        } else {
          console.log(`✅ Balance is already correct!`);
        }
      } catch (portfolioError) {
        console.error(`❌ Error repairing portfolio ${portfolio.id}:`, portfolioError);
      }
    }
    
    console.log('\nBalance repair completed');
  } catch (error) {
    console.error('Error repairing balances:', error);
  } finally {
    process.exit();
  }
}

// Run the repair
repairAllBalances();