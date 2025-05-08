const express = require('express');
const paperTradingController = require('../controllers/paperTradingController');
const authMiddleware = require('../middleware/auth');

const router = express.Router();

// Apply authentication middleware to all routes
router.use(authMiddleware);

// Portfolio routes
router.get('/portfolios', paperTradingController.getUserPortfolios);
router.post('/portfolios', paperTradingController.createPortfolio);
router.get('/portfolios/:portfolioId', paperTradingController.getPortfolioDetails);

// Trade routes
router.post('/portfolios/:portfolioId/trades', paperTradingController.executeTrade);
router.get('/portfolios/:portfolioId/trades', paperTradingController.getTradeHistory);

module.exports = router;