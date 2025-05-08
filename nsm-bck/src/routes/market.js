const express = require('express');
const marketController = require('../controllers/marketController');

const router = express.Router();

router.get('/gainers', marketController.getTopGainers);
router.get('/live-trading', marketController.getLiveTrading);
router.get('/indices', marketController.getIndices);
router.get('/stock/:symbol', marketController.getStockBySymbol); // Add this route
// Add new route for company details
router.get('/company/:symbol', marketController.getCompanyDetails);

module.exports = router;