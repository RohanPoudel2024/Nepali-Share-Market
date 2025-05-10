module.exports = async ({ client }) => {
  console.log('Adding company_name column to paper_trades table...');
  
  try {
    // Check if table exists first
    const tableExists = await client.unsafe(`
      SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_name = 'paper_trades'
      );
    `);
    
    if (!tableExists.rows?.[0]?.exists) {
      console.log('paper_trades table does not exist yet, skipping migration');
      return true;
    }
    
    // Check if column already exists to avoid errors
    const columnExists = await client.unsafe(`
      SELECT EXISTS (
        SELECT FROM information_schema.columns 
        WHERE table_name = 'paper_trades' AND column_name = 'company_name'
      );
    `);
    
    if (columnExists.rows?.[0]?.exists) {
      console.log('company_name column already exists, skipping migration');
      return true;
    }
    
    // Add the missing column
    await client.unsafe(`
      ALTER TABLE paper_trades
      ADD COLUMN company_name TEXT;
    `);
    
    console.log('Successfully added company_name column to paper_trades table');
    return true;
  } catch (error) {
    console.error('Error adding company_name column:', error);
    return false;
  }
};