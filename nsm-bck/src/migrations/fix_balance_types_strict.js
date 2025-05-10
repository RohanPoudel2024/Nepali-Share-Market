module.exports = async ({ client }) => {
  console.log('Applying strict balance type enforcement...');
  
  try {
    // Verify table exists
    const tableExists = await client.unsafe(`
      SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'paper_portfolios');
    `);
    
    if (!tableExists.rows?.[0]?.exists) {
      console.log('Table does not exist yet, skipping');
      return true;
    }
    
    // CRITICAL FIX: Convert ALL balance columns to NUMERIC type with NOT NULL constraint
    console.log('Converting balance columns to strict NUMERIC type...');
    await client.unsafe(`
      -- First convert any invalid values to NULL 
      UPDATE paper_portfolios 
      SET current_balance = NULL 
      WHERE current_balance::text = 'NaN' OR current_balance::text = 'undefined' OR current_balance::text = '';
      
      -- Make sure NULL values get valid defaults
      UPDATE paper_portfolios 
      SET current_balance = initial_balance 
      WHERE current_balance IS NULL AND initial_balance IS NOT NULL AND initial_balance::text != 'NaN';
      
      -- Any remaining NULL values get the default
      UPDATE paper_portfolios 
      SET current_balance = 150000 
      WHERE current_balance IS NULL;
      
      -- Fix initial_balance too
      UPDATE paper_portfolios 
      SET initial_balance = 150000 
      WHERE initial_balance IS NULL OR initial_balance::text = 'NaN' OR initial_balance::text = 'undefined';
      
      -- Now alter the columns with proper constraints
      ALTER TABLE paper_portfolios
      ALTER COLUMN current_balance TYPE NUMERIC(14,2) USING current_balance::NUMERIC(14,2),
      ALTER COLUMN current_balance SET NOT NULL,
      ALTER COLUMN initial_balance TYPE NUMERIC(14,2) USING initial_balance::NUMERIC(14,2),
      ALTER COLUMN initial_balance SET NOT NULL;
    `);
    
    console.log('Balance column types strictly enforced');
    return true;
  } catch (error) {
    console.error('Error enforcing balance types:', error);
    return false;
  }
};