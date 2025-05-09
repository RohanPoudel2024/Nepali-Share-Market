module.exports = async ({ client }) => {
  try {
    console.log('Fixing balance column types in paper_portfolios table...');
    
    // First check if the table exists
    const tableExistsResult = await client.unsafe(`
      SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_name = 'paper_portfolios'
      );
    `);
    
    const tableExists = tableExistsResult.rows?.[0]?.exists === true;
    if (!tableExists) {
      console.log('paper_portfolios table does not exist yet, skipping fix');
      return true;
    }
    
    // Check the current column types
    const columnInfo = await client.unsafe(`
      SELECT column_name, data_type 
      FROM information_schema.columns
      WHERE table_name = 'paper_portfolios' AND 
        column_name IN ('initial_balance', 'current_balance');
    `);
    
    console.log('Current column types:');
    for (const col of columnInfo.rows) {
      console.log(`- ${col.column_name}: ${col.data_type}`);
    }
    
    // Apply fixes to ensure columns are NUMERIC and NOT NULL
    await client.unsafe(`
      ALTER TABLE paper_portfolios
      ALTER COLUMN current_balance TYPE NUMERIC USING (current_balance::numeric),
      ALTER COLUMN current_balance SET NOT NULL,
      ALTER COLUMN current_balance SET DEFAULT 150000;
    `);
    
    await client.unsafe(`
      ALTER TABLE paper_portfolios
      ALTER COLUMN initial_balance TYPE NUMERIC USING (initial_balance::numeric),
      ALTER COLUMN initial_balance SET NOT NULL,
      ALTER COLUMN initial_balance SET DEFAULT 150000;
    `);
    
    // Verify the fixes
    const updatedColumnInfo = await client.unsafe(`
      SELECT column_name, data_type, is_nullable, column_default
      FROM information_schema.columns
      WHERE table_name = 'paper_portfolios' AND 
        column_name IN ('initial_balance', 'current_balance');
    `);
    
    console.log('Updated column types:');
    for (const col of updatedColumnInfo.rows) {
      console.log(`- ${col.column_name}: ${col.data_type}, nullable: ${col.is_nullable}, default: ${col.column_default}`);
    }
    
    console.log('Balance column types fixed successfully');
    return true;
  } catch (error) {
    console.error('Error fixing balance column types:', error);
    // Continue with other migrations
    return true;
  }
};
