const express = require('express');
const paperTradingController = require('../controllers/paperTradingController');
const authMiddleware = require('../middleware/auth');

const router = express.Router();

// Apply optional authentication middleware
router.use((req, res, next) => {
  // Try to authenticate, but don't require it
  authMiddleware(req, res, (err) => {
    // Continue regardless of authentication result
    next();
  });
});

// Portfolio routes
router.get('/portfolios', paperTradingController.getUserPortfolios);
router.post('/portfolios', paperTradingController.createPortfolio);
router.get('/portfolios/:portfolioId', paperTradingController.getPortfolioDetails);
router.get('/portfolios/:portfolioId/details', paperTradingController.getPortfolioDetails);

// Trade routes
router.post('/portfolios/:portfolioId/trades', paperTradingController.executeTrade);
router.get('/portfolios/:portfolioId/trades', paperTradingController.getTradeHistory);

// Balance fix route
router.post('/portfolios/:portfolioId/fix-balance', paperTradingController.fixPortfolioBalance);

module.exports = router;