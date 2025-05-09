// This migration ensures all portfolios have valid balances based on trade history

module.exports = async ({ client }) => {
  console.log('Starting portfolio balance repair migration...');
  
  try {
    // First verify that paper_portfolios table exists
    const tableExistsResult = await client.unsafe(`
      SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_name = 'paper_portfolios'
      );
    `);
    
    let tableExists = false;
    
    if (tableExistsResult && tableExistsResult.rows && tableExistsResult.rows.length > 0) {
      tableExists = tableExistsResult.rows[0].exists;
    }
    
    if (!tableExists) {
      console.log('paper_portfolios table does not exist yet, skipping balance repair');
      return true;
    }
    
    // Get all portfolios
    const portfolios = await client.unsafe(`
      SELECT id, initial_balance, current_balance
      FROM paper_portfolios
    `);
    
    const portfoliosArray = portfolios.rows || [];
    
    for (const portfolio of portfoliosArray) {
      console.log(`Processing portfolio ${portfolio.id}`);
      
      try {
        // Get all trades for this portfolio
        const tradesResult = await client.unsafe(`
          SELECT type, total_amount 
          FROM paper_trades 
          WHERE portfolio_id = ${portfolio.id}
          ORDER BY created_at ASC;
        `);
        
        const trades = tradesResult.rows || [];
        
        // Start with initial balance
        let calculatedBalance = parseFloat(portfolio.initial_balance);
        
        // Apply all trades to recalculate the correct current balance
        for (const trade of trades) {
          if (trade.type === 'BUY') {
            calculatedBalance -= parseFloat(trade.total_amount);
          } else if (trade.type === 'SELL') {
            calculatedBalance += parseFloat(trade.total_amount);
          }
        }
        
        // Update the portfolio with the calculated balance
        await client.unsafe(`
          UPDATE paper_portfolios 
          SET current_balance = ${calculatedBalance},
              updated_at = NOW()
          WHERE id = ${portfolio.id};
        `);
        
        console.log(`Updated portfolio ${portfolio.id} balance from ${portfolio.current_balance} to ${calculatedBalance}`);
      } catch (e) {
        console.error(`Error processing portfolio ${portfolio.id}:`, e);
      }
    }
    
    console.log('Portfolio balance repair migration completed successfully');
    return true;
  } catch (error) {
    console.error('Error in portfolio balance repair migration:', error);
    return true; // Continue with other migrations
  }
};
