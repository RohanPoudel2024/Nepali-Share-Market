const express = require('express');
const router = express.Router();
const portfolioController = require('../controllers/portfolioController');

// Get all portfolios for a user
router.get('/', portfolioController.getPortfolios);
router.post('/', portfolioController.createPortfolio);
router.get('/:id', portfolioController.getPortfolioDetails);
router.post('/:portfolioId/holdings', portfolioController.addHolding);
router.put('/holdings/:holdingId', portfolioController.updateHolding);

// Add these new routes for transactions
router.post('/:portfolioId/transactions', portfolioController.addTransaction);
router.get('/:portfolioId/transactions', portfolioController.getTransactions);

module.exports = router;