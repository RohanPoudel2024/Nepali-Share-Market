module.exports = async ({ client }) => {
  console.log('Fixing balance column in paper_portfolios table...');
  
  try {
    // Check if table exists with robust error handling
    const tableExistsResult = await client.unsafe(`
      SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_name = 'paper_portfolios'
      );
    `);
    
    // Robust check for different client result formats
    let tableExists = false;
    if (tableExistsResult) {
      if (tableExistsResult.rows && tableExistsResult.rows.length > 0) {
        // Standard node-postgres format
        tableExists = tableExistsResult.rows[0].exists;
      } else if (Array.isArray(tableExistsResult) && tableExistsResult.length > 0) {
        // Some clients return array directly
        tableExists = tableExistsResult[0].exists;
      } else if (typeof tableExistsResult === 'object') {
        // Check for exists as direct property
        tableExists = tableExistsResult.exists === true;
      }
    }
    
    console.log(`Table paper_portfolios exists: ${tableExists}`);
    
    if (!tableExists) {
      console.log('paper_portfolios table does not exist yet, skipping');
      return true;
    }
    
    // Add column type validation and NOT NULL constraint
    console.log('Ensuring current_balance is numeric type with NOT NULL constraint');
    
    // First fix any invalid values
    await client.unsafe(`
      UPDATE paper_portfolios
      SET current_balance = initial_balance
      WHERE current_balance IS NULL 
         OR current_balance::text = 'undefined'
         OR current_balance::text = 'NaN';
    `);
    
    // Then add constraints
    await client.unsafe(`
      ALTER TABLE paper_portfolios 
      ALTER COLUMN current_balance TYPE NUMERIC(15,2) USING (current_balance::NUMERIC(15,2)),
      ALTER COLUMN current_balance SET NOT NULL;
      
      ALTER TABLE paper_portfolios
      ALTER COLUMN initial_balance TYPE NUMERIC(15,2) USING (initial_balance::NUMERIC(15,2)),
      ALTER COLUMN initial_balance SET NOT NULL;
    `);
    
    // Check if company_name column exists in paper_trades table
    console.log('Checking if company_name column exists in paper_trades table...');
    const columnExistsResult = await client.unsafe(`
      SELECT EXISTS (
        SELECT FROM information_schema.columns 
        WHERE table_name = 'paper_trades' AND column_name = 'company_name'
      );
    `);
    
    let columnExists = false;
    if (columnExistsResult) {
      if (columnExistsResult.rows && columnExistsResult.rows.length > 0) {
        columnExists = columnExistsResult.rows[0].exists;
      } else if (Array.isArray(columnExistsResult) && columnExistsResult.length > 0) {
        columnExists = columnExistsResult[0].exists;
      } else if (typeof columnExistsResult === 'object') {
        columnExists = columnExistsResult.exists === true;
      }
    }
    
    console.log(`Column company_name exists: ${columnExists}`);
    
    if (!columnExists) {
      console.log('Adding company_name column to paper_trades table...');
      await client.unsafe(`
        ALTER TABLE paper_trades
        ADD COLUMN company_name TEXT;
      `);
      console.log('Added company_name column');
    } else {
      console.log('company_name column already exists, skipping');
    }
    
    console.log('Balance column fixes completed');
    return true;
  } catch (error) {
    console.error('Error fixing balance columns:', error);
    // Continue with other migrations, don't fail server startup
    return true;
  }
};