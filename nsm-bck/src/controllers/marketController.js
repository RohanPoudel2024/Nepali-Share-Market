const nepseService = require('../services/nepseService');

const marketController = {
  getTopGainers: async (req, res) => {
    try {
      const gainers = await nepseService.getTopGainers();
      res.json(gainers);
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  },

  getLiveTrading: async (req, res) => {
    try {
      const liveTrading = await nepseService.getLiveTrading();
      res.json(liveTrading);
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  },

  getIndices: async (req, res) => {
    try {
      const indices = await nepseService.getIndices();
      res.json(indices);
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  },
  
  getStockBySymbol: async (req, res) => {
    try {
      const { symbol } = req.params;
      const liveTrading = await nepseService.getLiveTrading();
      
      const stock = liveTrading.find(item => 
        item.symbol.toLowerCase() === symbol.toLowerCase()
      );
      
      if (!stock) {
        return res.status(404).json({ error: 'Stock not found' });
      }
      
      res.json(stock);
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  },  // Added comma here - this was likely missing

  getCompanyDetails: async (req, res) => {
    try {
      const { symbol } = req.params;
      
      if (!symbol) {
        return res.status(400).json({ error: 'Symbol is required' });
      }
      
      const companyDetails = await nepseService.getCompanyDetails(symbol);
      res.json({
        success: true,
        data: companyDetails
      });
    } catch (error) {
      res.status(500).json({ 
        success: false,
        error: error.message 
      });
    }
  }
};

module.exports = marketController;