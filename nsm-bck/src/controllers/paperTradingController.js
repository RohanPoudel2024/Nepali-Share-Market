const paperTradingService = require('../services/paperTradingService');

const paperTradingController = {
  // Get all portfolios for current user
  getUserPortfolios: async (req, res) => {
    try {
      const userId = req.user?.id; // Handle potentially undefined user
      const portfolios = await paperTradingService.getUserPortfolios(userId);
      
      return res.status(200).json({
        success: true,
        data: portfolios
      });
    } catch (error) {
      console.error('Error in getUserPortfolios:', error);
      
      return res.status(500).json({
        success: false,
        message: 'Failed to retrieve portfolios',
        error: error.message
      });
    }
  },

  // Get details of a specific portfolio
  getPortfolioDetails: async (req, res) => {
    try {
      const { portfolioId } = req.params;
      const userId = req.user?.id;
      
      const portfolioDetails = await paperTradingService.getPortfolioDetails(portfolioId);
      
      // Skip user validation if user is undefined or user_id in portfolio is null
      if (userId && portfolioDetails.user_id && portfolioDetails.user_id !== userId) {
        return res.status(403).json({
          success: false,
          message: 'You do not have permission to access this portfolio'
        });
      }
      
      return res.status(200).json({
        success: true,
        data: portfolioDetails
      });
    } catch (error) {
      console.error('Error in getPortfolioDetails:', error);
      
      return res.status(404).json({
        success: false,
        message: 'Portfolio not found',
        error: error.message
      });
    }
  },

  // Create a new portfolio
  createPortfolio: async (req, res) => {
    try {
      const userId = req.user?.id;
      const { name, description, initialBalance } = req.body;
      
      if (!name) {
        return res.status(400).json({
          success: false,
          message: 'Portfolio name is required'
        });
      }
      
      const newPortfolio = await paperTradingService.createPortfolio(userId, {
        name,
        description,
        initialBalance
      });
      
      return res.status(201).json({
        success: true,
        message: 'Portfolio created successfully',
        data: newPortfolio
      });
    } catch (error) {
      console.error('Error in createPortfolio:', error);
      return res.status(500).json({
        success: false,
        message: 'Failed to create portfolio',
        error: error.message
      });
    }
  },

  // Execute a trade
  executeTrade: async (req, res) => {
    try {
      const { portfolioId } = req.params;
      const { symbol, type, quantity, price, companyName } = req.body;
      
      // Validate required fields
      if (!symbol || !type || !quantity || !price) {
        return res.status(400).json({
          success: false,
          message: 'Missing required fields: symbol, type, quantity, and price are required'
        });
      }
      
      // Execute the trade
      const trade = await paperTradingService.executeTrade(portfolioId, {
        symbol,
        type,
        quantity: parseFloat(quantity),
        price: parseFloat(price),
        companyName
      });
      
      return res.status(200).json({
        success: true,
        message: 'Trade executed successfully',
        data: trade
      });
    } catch (error) {
      console.error('Error in executeTrade:', error);
      return res.status(400).json({
        success: false,
        message: error.message || 'Failed to execute trade'
      });
    }
  },

  // Get trade history for a portfolio
  getTradeHistory: async (req, res) => {
    try {
      const { portfolioId } = req.params;
      
      const trades = await paperTradingService.getTradeHistory(portfolioId);

      return res.status(200).json({
        success: true,
        data: trades
      });
    } catch (error) {
      console.error('Error in getTradeHistory:', error);
      return res.status(500).json({
        success: false,
        message: 'Failed to retrieve trade history',
        error: error.message
      });
    }
  },

  // Fix portfolio balance
  fixPortfolioBalance: async (req, res) => {
    try {
      const { portfolioId } = req.params;
      
      const updatedPortfolio = await paperTradingService.fixPortfolioBalance(portfolioId);
      
      return res.status(200).json({
        success: true,
        message: 'Portfolio balance fixed successfully',
        data: updatedPortfolio
      });
    } catch (error) {
      console.error('Error fixing portfolio balance:', error);
      return res.status(500).json({
        success: false,
        message: 'Failed to fix portfolio balance',
        error: error.message
      });
    }
  }
};

module.exports = paperTradingController;