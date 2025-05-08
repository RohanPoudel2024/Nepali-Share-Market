const portfolioService = require('../services/portfolioService');

const portfolioController = {
  // Get all portfolios for a user
  getPortfolios: async (req, res) => {
    try {
      // In a real app, you'd get userId from authenticated user
      const userId = req.user?.id || 1; // Fallback to 1 for testing
      const portfolios = await portfolioService.getUserPortfolios(userId);
      res.json(portfolios);
    } catch (error) {
      console.error('Error fetching portfolios:', error);
      res.status(500).json({ error: error.message });
    }
  },
  
  // Create a new portfolio
  createPortfolio: async (req, res) => {
    try {
      const { name, description } = req.body;
      // In a real app, you'd get userId from authenticated user
      const userId = req.user?.id || 1; // Fallback to 1 for testing
      
      if (!name) {
        return res.status(400).json({ error: 'Portfolio name is required' });
      }
      
      const portfolioData = {
        userId,
        name,
        description
      };
      
      const newPortfolio = await portfolioService.createPortfolio(portfolioData);
      
      // Return structured response format that matches frontend expectations
      res.status(201).json({
        success: true,
        data: newPortfolio[0] || newPortfolio // Handle both array and object response
      });
    } catch (error) {
      console.error('Error creating portfolio:', error);
      res.status(500).json({ success: false, error: error.message });
    }
  },
  
  // Get portfolio details including holdings
  getPortfolioDetails: async (req, res) => {
    try {
      const { id } = req.params;
      // In a real app, you'd get userId from authenticated user
      const userId = req.user?.id || 1; // Fallback to 1 for testing
      
      const portfolio = await portfolioService.getPortfolioWithHoldings(parseInt(id), userId);
      
      if (!portfolio) {
        return res.status(404).json({ 
          success: false, 
          error: 'Portfolio not found' 
        });
      }
      
      // Return with proper success wrapper structure
      res.json({
        success: true,
        data: portfolio
      });
    } catch (error) {
      console.error('Error fetching portfolio details:', error);
      res.status(500).json({ 
        success: false, 
        error: error.message 
      });
    }
  },
  
  // Add a new holding to a portfolio
  addHolding: async (req, res) => {
    try {
      const { portfolioId } = req.params;
      const { symbol, quantity, averageBuyPrice } = req.body;
      
      console.log('Adding holding request:', { portfolioId, symbol, quantity, averageBuyPrice });
      
      if (!symbol || !quantity || !averageBuyPrice) {
        return res.status(400).json({ 
          success: false,
          error: 'Symbol, quantity, and average buy price are required' 
        });
      }
      
      const holdingData = {
        portfolioId: parseInt(portfolioId),
        symbol,
        quantity: parseFloat(quantity),
        averageBuyPrice: parseFloat(averageBuyPrice)
      };
      
      const newHolding = await portfolioService.addHolding(holdingData);
      
      // Return consistent response structure
      res.status(201).json({
        success: true,
        data: newHolding
      });
    } catch (error) {
      console.error('Error adding holding:', error);
      res.status(500).json({ 
        success: false,
        error: error.message 
      });
    }
  },
  
  // Update an existing holding (buy more or sell)
  updateHolding: async (req, res) => {
    try {
      const { holdingId } = req.params;
      const { quantity, price, type } = req.body;
      
      if (!quantity || !price || !type) {
        return res.status(400).json({ 
          error: 'Quantity, price, and type (BUY or SELL) are required' 
        });
      }
      
      if (type !== 'BUY' && type !== 'SELL') {
        return res.status(400).json({ error: 'Type must be either BUY or SELL' });
      }
      
      const updatedHolding = await portfolioService.updateHolding(
        parseInt(holdingId),
        {
          quantity: parseFloat(quantity),
          price: parseFloat(price),
          type
        }
      );
      
      res.json(updatedHolding);
    } catch (error) {
      console.error('Error updating holding:', error);
      res.status(500).json({ error: error.message });
    }
  },

  // Add a transaction
  addTransaction: async (req, res) => {
    try {
      const { portfolioId } = req.params;
      const { symbol, type, quantity, price, date } = req.body;
      
      if (!symbol || !type || !quantity || !price) {
        return res.status(400).json({ 
          success: false,
          error: 'Symbol, type, quantity, and price are required' 
        });
      }
      
      // Find the holding for this symbol
      const holding = await portfolioService.findHoldingBySymbol(
        parseInt(portfolioId), 
        symbol
      );
      
      if (!holding) {
        return res.status(404).json({
          success: false,
          error: `No holding found for ${symbol} in this portfolio`
        });
      }
      
      const transaction = await portfolioService.addTransaction({
        holdingId: holding.id,
        type: type.toUpperCase(),
        quantity: parseFloat(quantity),
        price: parseFloat(price),
        date: date ? new Date(date) : new Date()
      });
      
      // Return a single transaction object, not an array
      res.status(201).json({
        success: true,
        data: transaction[0] || transaction // Handle both array and object
      });
    } catch (error) {
      console.error('Error adding transaction:', error);
      res.status(500).json({ 
        success: false,
        error: error.message 
      });
    }
  },

  // Get transactions for a portfolio
  getTransactions: async (req, res) => {
    try {
      const { portfolioId } = req.params;
      
      const transactions = await portfolioService.getTransactionsByPortfolioId(
        parseInt(portfolioId)
      );
      
      res.json({
        success: true,
        data: transactions
      });
    } catch (error) {
      console.error('Error getting transactions:', error);
      res.status(500).json({ 
        success: false,
        error: error.message 
      });
    }
  }
};

module.exports = portfolioController;