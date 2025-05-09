module.exports = async ({ client }) => {
  console.log('Starting balance repair migration...');
  
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
    } else if (Array.isArray(tableExistsResult) && tableExistsResult.length > 0) {
      tableExists = tableExistsResult[0].exists;
    }
    
    if (!tableExists) {
      console.log('paper_portfolios table does not exist yet, skipping balance repair');
      return true;
    }
    
    // Find portfolios with NULL or invalid balances
    console.log('Querying for portfolios with invalid balances...');
    const portfoliosWithNullBalances = await client.unsafe(`
      SELECT id, initial_balance 
      FROM paper_portfolios 
      WHERE current_balance IS NULL 
         OR current_balance::text = 'NaN'
         OR current_balance::text = 'undefined';
    `);
    
    // Safely extract rows from the query result
    let portfoliosToFix = [];
    
    // Handle different result formats based on DB client used
    if (portfoliosWithNullBalances) {
      if (Array.isArray(portfoliosWithNullBalances)) {
        // Client returns array directly
        portfoliosToFix = portfoliosWithNullBalances;
        console.log(`Found ${portfoliosToFix.length} portfolios with invalid balances (array format)`);
      } 
      else if (portfoliosWithNullBalances.rows && Array.isArray(portfoliosWithNullBalances.rows)) {
        // Standard node-postgres format
        portfoliosToFix = portfoliosWithNullBalances.rows;
        console.log(`Found ${portfoliosToFix.length} portfolios with invalid balances (rows format)`);
      }
      else if (typeof portfoliosWithNullBalances === 'object') {
        // Some clients return object with items under a different property
        const possibleArrayProps = ['rows', 'data', 'results', 'items'];
        
        for (const prop of possibleArrayProps) {
          if (portfoliosWithNullBalances[prop] && Array.isArray(portfoliosWithNullBalances[prop])) {
            portfoliosToFix = portfoliosWithNullBalances[prop];
            console.log(`Found ${portfoliosToFix.length} portfolios with invalid balances (using ${prop} property)`);
            break;
          }
        }
      }
    }
    
    // If we couldn't determine the structure, log it for debugging
    if (portfoliosToFix.length === 0) {
      console.log('No portfolios with invalid balances found');
      return true; // Exit successfully
    }
    
    // For each problematic portfolio, fix the balance
    for (const row of portfoliosToFix) {
      try {
        const portfolioId = row.id;
        // Safely get initial balance with fallback
        const initialBalance = row.initial_balance || 150000;
        
        console.log(`Repairing portfolio ${portfolioId} balance using initial_balance: ${initialBalance}`);
        
        // Get all trades for this portfolio to reconstruct the balance
        const tradesResult = await client.unsafe(`
          SELECT type, total_amount 
          FROM paper_trades 
          WHERE portfolio_id = ${portfolioId}
          ORDER BY created_at ASC;
        `);
        
        // Safely get trades array
        let trades = [];
        if (tradesResult && tradesResult.rows) {
          trades = tradesResult.rows;
        } else if (Array.isArray(tradesResult)) {
          trades = tradesResult;
        }
        
        // Start with initial balance
        let calculatedBalance = parseFloat(initialBalance);
        
        // Apply all trades to calculate current balance
        for (const trade of trades) {
          try {
            const tradeAmount = parseFloat(trade.total_amount);
            if (!isNaN(tradeAmount)) {
              if (trade.type && trade.type.toUpperCase() === 'BUY') {
                calculatedBalance -= tradeAmount;
              } else if (trade.type && trade.type.toUpperCase() === 'SELL') {
                calculatedBalance += tradeAmount;
              }
            }
          } catch (tradeError) {
            console.error(`Error processing trade for portfolio ${portfolioId}:`, tradeError);
          }
        }
        
        console.log(`Calculated balance for portfolio ${portfolioId}: ${calculatedBalance}`);
        
        // Update the portfolio with the reconstructed balance
        await client.unsafe(`
          UPDATE paper_portfolios 
          SET current_balance = ${calculatedBalance}, 
              updated_at = NOW() 
          WHERE id = ${portfolioId};
        `);
        
        console.log(`Fixed balance for portfolio ${portfolioId}`);
      } catch (rowError) {
        console.error(`Error processing portfolio row:`, rowError);
        // Continue to next portfolio rather than failing entire migration
      }
    }
    
    try {
      // Add NOT NULL constraints to prevent future issues if they don't exist
      console.log('Ensuring current_balance column has proper constraints');
      
      // Check if column has NOT NULL constraint
      const columnCheck = await client.unsafe(`
        SELECT is_nullable 
        FROM information_schema.columns 
        WHERE table_name = 'paper_portfolios' 
        AND column_name = 'current_balance';
      `);
      
      let isNullable = true;
      if (columnCheck && columnCheck.rows && columnCheck.rows.length > 0) {
        isNullable = columnCheck.rows[0].is_nullable === 'YES';
      } else if (Array.isArray(columnCheck) && columnCheck.length > 0) {
        isNullable = columnCheck[0].is_nullable === 'YES';
      }
      
      if (isNullable) {
        console.log('Adding NOT NULL constraint and default value to current_balance');
        await client.unsafe(`
          ALTER TABLE paper_portfolios 
          ALTER COLUMN current_balance SET NOT NULL,
          ALTER COLUMN current_balance SET DEFAULT 150000;
        `);
      } else {
        console.log('current_balance already has NOT NULL constraint');
      }
    } catch (constraintError) {
      console.error('Error setting constraints:', constraintError);
      // Don't fail the migration if just the constraint setting fails
    }
    
    console.log('Balance repair migration completed successfully');
    return true;
  } catch (error) {
    console.error('Error in balance repair migration:', error);
    // Don't fail server startup if this migration fails
    return true;
  }
};
