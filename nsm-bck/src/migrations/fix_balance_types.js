module.exports = async ({ client }) => {
  console.log('Starting comprehensive balance type fix...');
  try {
    // Check if table exists first
    const tableExists = await client.unsafe(`
      SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_name = 'paper_portfolios'
      );
    `);
    
    if (!tableExists.rows?.[0]?.exists) {
      console.log('paper_portfolios table does not exist yet, skipping');
      return true;
    }
    
    // Set default values for any NULL or invalid balances
    await client.unsafe(`
      -- First convert NaN, undefined, empty strings to NULL
      UPDATE paper_portfolios
      SET current_balance = NULL
      WHERE current_balance::text = 'NaN' 
         OR current_balance::text = 'undefined'
         OR current_balance::text = '';
         
      UPDATE paper_portfolios
      SET initial_balance = NULL
      WHERE initial_balance::text = 'NaN' 
         OR initial_balance::text = 'undefined'
         OR initial_balance::text = '';
      
      -- Then set NULL values to 150000
      UPDATE paper_portfolios
      SET current_balance = 150000
      WHERE current_balance IS NULL;
         
      UPDATE paper_portfolios
      SET initial_balance = 150000
      WHERE initial_balance IS NULL;
    `);
    
    console.log('Applied data fixes.');
    
    // Add proper constraints to prevent future issues
    await client.unsafe(`
      -- Set proper precision numeric type with NOT NULL constraint
      ALTER TABLE paper_portfolios 
      ALTER COLUMN current_balance TYPE NUMERIC(14,2) USING current_balance::NUMERIC(14,2),
      ALTER COLUMN current_balance SET NOT NULL,
      ALTER COLUMN current_balance SET DEFAULT 150000,
      
      ALTER COLUMN initial_balance TYPE NUMERIC(14,2) USING initial_balance::NUMERIC(14,2),
      ALTER COLUMN initial_balance SET NOT NULL,
      ALTER COLUMN initial_balance SET DEFAULT 150000;
    `);
    
    console.log('Added constraints to balance columns.');
    return true;
  } catch (error) {
    console.error('Error in balance_types migration:', error);
    return false; 
  }
};