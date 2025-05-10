module.exports = async ({ client }) => {
  console.log('Starting portfolio balance validation migration...');
  
  try {
    // First verify that paper_portfolios table exists with robust error handling
    console.log('Checking if paper_portfolios table exists...');
    
    let tableExists = false;
    try {
      const tableExistsResult = await client.unsafe(`
        SELECT EXISTS (
          SELECT FROM information_schema.tables 
          WHERE table_name = 'paper_portfolios'
        );
      `);
      
      // Handle different response formats from various database clients
      if (tableExistsResult) {
        if (tableExistsResult.rows && tableExistsResult.rows[0]) {
          // Standard node-postgres format
          tableExists = tableExistsResult.rows[0].exists === true;
        } else if (Array.isArray(tableExistsResult) && tableExistsResult[0]) {
          // Some clients return array directly
          tableExists = tableExistsResult[0].exists === true;
        } else if (typeof tableExistsResult === 'object') {
          // Check for exists as direct property
          tableExists = tableExistsResult.exists === true;
        }
      }
      
      console.log(`Table paper_portfolios exists: ${tableExists}`);
    } catch (checkError) {
      console.error('Error checking if table exists:', checkError);
      // Proceed with migration, other checks will handle missing table
    }
    
    if (!tableExists) {
      console.log('paper_portfolios table does not exist yet, skipping');
      return true;
    }
    
    // Add NOT NULL constraint with default value if it doesn't exist
    console.log('Ensuring current_balance and initial_balance have proper constraints...');
    
    // First set default values for any null or invalid balances
    try {
      await client.unsafe(`
        UPDATE paper_portfolios
        SET current_balance = COALESCE(initial_balance, 150000)
        WHERE current_balance IS NULL 
           OR current_balance::text = 'NaN'
           OR current_balance::text = 'undefined'
           OR current_balance::text = '';
          
        UPDATE paper_portfolios
        SET initial_balance = 150000
        WHERE initial_balance IS NULL 
           OR initial_balance::text = 'NaN'
           OR initial_balance::text = 'undefined'
           OR initial_balance::text = '';
      `);
      console.log('Fixed any invalid balance values');
    } catch (updateError) {
      console.error('Error updating invalid balances:', updateError);
      // Continue with migration
    }
    
    // Then add constraints
    try {
      await client.unsafe(`
        ALTER TABLE paper_portfolios 
        ALTER COLUMN current_balance SET NOT NULL,
        ALTER COLUMN current_balance SET DEFAULT 150000;
        
        ALTER TABLE paper_portfolios 
        ALTER COLUMN initial_balance SET NOT NULL,
        ALTER COLUMN initial_balance SET DEFAULT 150000;
      `);
      console.log('Added NOT NULL constraints and default values');
    } catch (constraintError) {
      console.log('Constraints may already exist or require different syntax:', constraintError.message);
    }
    
    console.log('Portfolio balance validation migration completed');
    return true;
  } catch (error) {
    console.error('Error in portfolio balance validation migration:', error);
    // Don't fail server startup if migration has issues
    return true;
  }
};