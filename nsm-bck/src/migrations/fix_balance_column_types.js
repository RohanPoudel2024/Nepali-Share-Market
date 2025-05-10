module.exports = async ({ client }) => {
  console.log('Fixing balance column types in paper_portfolios table...');
  
  try {
    // Check if table exists
    const tableExists = await client.unsafe(`
      SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_name = 'paper_portfolios'
      );
    `);
    
    if (!tableExists.rows?.[0]?.exists) {
      console.log('paper_portfolios table does not exist yet, skipping fix');
      return true;
    }
    
    // Fix column type and add constraints in one operation
    await client.unsafe(`
      ALTER TABLE paper_portfolios 
      ALTER COLUMN current_balance TYPE DECIMAL(14,2) USING COALESCE(current_balance::DECIMAL(14,2), initial_balance::DECIMAL(14,2), 150000),
      ALTER COLUMN current_balance SET NOT NULL,
      ALTER COLUMN initial_balance TYPE DECIMAL(14,2) USING COALESCE(initial_balance::DECIMAL(14,2), 150000),
      ALTER COLUMN initial_balance SET NOT NULL;
    `);
    
    console.log('Fixed balance column types and constraints');
    return true;
  } catch (error) {
    console.error('Error fixing balance column types:', error);
    return true; // Continue with other migrations
  }
};
