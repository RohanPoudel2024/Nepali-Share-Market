import 'package:flutter/foundation.dart';
import 'package:nepse_market_app/models/paper_portfolio.dart';
import 'package:nepse_market_app/models/paper_trade.dart';
import 'package:nepse_market_app/providers/market_provider.dart';
import 'package:nepse_market_app/services/paper_trading_service.dart';

class PaperTradingProvider extends ChangeNotifier {
  final PaperTradingService _paperTradingService = PaperTradingService();
  final MarketProvider _marketProvider;
  
  PaperTradingProvider(this._marketProvider);
  
  // State variables
  List<PaperPortfolio> _paperPortfolios = [];
  PaperPortfolio? _selectedPaperPortfolio;
  List<PaperTrade> _paperTrades = [];
  bool _isLoading = false;
  String? _errorMessage;
  
  // Getters
  List<PaperPortfolio> get paperPortfolios => _paperPortfolios;
  PaperPortfolio? get selectedPaperPortfolio => _selectedPaperPortfolio;
  List<PaperTrade> get paperTrades => _paperTrades;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  
  // Update the loadPaperPortfolios method to be more resilient
  Future<void> loadPaperPortfolios() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      // Get portfolios from service
      print('Fetching paper portfolios from service...');
      _paperPortfolios = await _paperTradingService.getPaperPortfolios();
      print('Fetched ${_paperPortfolios.length} paper portfolios');
      
      // Ensure at least one portfolio exists
      if (_paperPortfolios.isEmpty) {
        print('No portfolios found, creating default portfolio');
        try {
          final defaultPortfolio = await _paperTradingService.createPaperPortfolio(
            "Paper Trading Portfolio",
            "Trade with NPR 150,000 virtual money without risk!",
            150000.0
          );
          _paperPortfolios = [defaultPortfolio];
        } catch (e) {
          print('Failed to create portfolio on server: $e');
          // Create a local fallback portfolio
          _paperPortfolios = [_createLocalFallbackPortfolio()];
        }
      }
      
      // Update market prices for all portfolios
      for (var portfolio in _paperPortfolios) {
        try {
          _updatePortfolioMarketPrices(portfolio);
        } catch (e) {
          print('Error updating market prices for portfolio ${portfolio.id}: $e');
        }
      }
      
      // Set the first portfolio as selected
      if (_paperPortfolios.isNotEmpty) {
        try {
          final portfolioId = _paperPortfolios.first.id;
          print('Loading details for portfolio ID: $portfolioId');
          // First set a basic version so we have something if the detailed load fails
          _selectedPaperPortfolio = _paperPortfolios.first;
          await _loadPaperPortfolioDetailsInternal(portfolioId);
        } catch (e) {
          print('Error loading first portfolio details: $e');
          // Already set _selectedPaperPortfolio above, so we have a fallback
        }
      }
      
      _errorMessage = null;
    } catch (e) {
      print('Error in loadPaperPortfolios: $e');
      _paperPortfolios = [_createLocalFallbackPortfolio()];
      _selectedPaperPortfolio = _paperPortfolios.first;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // New helper method to create a local fallback portfolio
  PaperPortfolio _createLocalFallbackPortfolio() {
    return PaperPortfolio(
      id: 1, // Use a simple ID that will be consistent
      name: "Paper Trading Portfolio",
      description: "Trade with NPR 150,000 virtual money without risk!",
      initialBalance: 150000.0,
      currentBalance: 150000.0,
      holdings: [],
      paperTrades: [],
    );
  }
  
  // Add a new internal loading method that doesn't change isLoading state
  Future<void> _loadPaperPortfolioDetailsInternal(int portfolioId) async {
    try {
      // Get portfolio details
      final portfolio = await _paperTradingService.getPaperPortfolioDetails(portfolioId);
      
      // Update prices
      _updatePortfolioMarketPrices(portfolio);
      
      // Load trade history separately to ensure it's up to date
      _paperTrades = await _paperTradingService.getPaperTradeHistory(portfolioId);
      
      // Set as selected portfolio
      _selectedPaperPortfolio = portfolio;
      
      print('Loaded portfolio: id=${portfolio.id}, balance=${portfolio.currentBalance}, holdings=${portfolio.holdings.length}, trades=${_paperTrades.length}');
    } catch (e) {
      print('Error in _loadPaperPortfolioDetailsInternal: $e');
      // Don't change _selectedPaperPortfolio - keep whatever was set before
      throw e;
    }
  }
  
  // Load details for the portfolio
  Future<void> loadPaperPortfolioDetails(int portfolioId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      // Get portfolio details
      final portfolio = await _paperTradingService.getPaperPortfolioDetails(portfolioId);
      
      // Update prices
      _updatePortfolioMarketPrices(portfolio);
      
      // Load trade history separately to ensure it's up to date
      // If this fails, we'll still have the portfolio data
      try {
        _paperTrades = await _paperTradingService.getPaperTradeHistory(portfolioId);
      } catch (tradeError) {
        print('Error loading trades, continuing with empty list: $tradeError');
        _paperTrades = [];
      }
      
      // Set as selected portfolio
      _selectedPaperPortfolio = portfolio;
      
      print('Loaded portfolio: id=${portfolio.id}, balance=${portfolio.currentBalance}, holdings=${portfolio.holdings.length}, trades=${_paperTrades.length}');
      
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to load portfolio: ${e.toString()}';
      print('Error loading paper portfolio details: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Create portfolio is disabled - we always use the default
  Future<bool> createPaperPortfolio(String name, String? description, double initialBalance) async {
    return false; // Disabled function - we only use the default portfolio
  }
  
  // Execute a paper trade with improved balance handling
  Future<bool> executePaperTrade(
    int portfolioId,
    String symbol,
    String type,
    double quantity,
    double? price,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      // Validate the trade locally first for quick feedback
      if (_selectedPaperPortfolio != null && 
          type.toUpperCase() == 'BUY' && 
          _selectedPaperPortfolio!.id == portfolioId) {
        
        final actualPrice = price ?? _marketProvider.getStockPrice(symbol) ?? 0;
        if (actualPrice <= 0) {
          throw Exception('Invalid stock price');
        }
        
        // Calculate trade amount
        final tradeAmount = quantity * actualPrice;
        
        // Check if there's enough cash balance
        if (_selectedPaperPortfolio!.currentBalance < tradeAmount) {
          throw Exception('Insufficient balance. You need Rs. ${tradeAmount.toStringAsFixed(2)} but have Rs. ${_selectedPaperPortfolio!.currentBalance.toStringAsFixed(2)}');
        }
      }
      
      double actualPrice;
      
      if (price != null) {
        actualPrice = price;
      } else {
        final marketPrice = _marketProvider.getStockPrice(symbol);
        if (marketPrice == null || marketPrice <= 0) {
          throw Exception('Could not determine current market price for $symbol');
        }
        actualPrice = marketPrice;
      }
      
      // Execute the trade on the server
      final success = await _paperTradingService.executePaperTrade(
        portfolioId,
        symbol,
        type,
        quantity,
        actualPrice,
      );
      
      if (!success) {
        throw Exception('Failed to execute paper trade');
      }
      
      // Optional: Simulate trade locally for immediate UI feedback
      if (_selectedPaperPortfolio != null && _selectedPaperPortfolio!.id == portfolioId) {
        _selectedPaperPortfolio!.simulateTrade(type, symbol, quantity, actualPrice);
      }
      
      // Reload complete portfolio data to get accurate state
      await _loadPaperPortfolioDetailsInternal(portfolioId);
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      print('Error executing paper trade: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  // Update portfolio with current market prices
  void _updatePortfolioMarketPrices(PaperPortfolio portfolio) {
    double totalMarketValue = 0.0;
    double totalInvestment = 0.0;

    // Calculate current investment value from holdings
    for (var holding in portfolio.holdings) {
      // Calculate investment value (quantity × average buy price)
      final investmentValue = holding.quantity * holding.averageBuyPrice;
      totalInvestment += investmentValue;
      
      try {
        // Try to get current market price
        final currentPrice = _marketProvider.getStockPrice(holding.symbol);
        if (currentPrice != null && currentPrice > 0) {
          holding.currentPrice = currentPrice;
          holding.marketValue = holding.quantity * currentPrice;
          holding.currentValue = holding.marketValue;
          
          // Add to total market value
          totalMarketValue += holding.marketValue;
        } else {
          holding.currentPrice = holding.averageBuyPrice;
          holding.marketValue = holding.quantity * holding.averageBuyPrice;
          holding.currentValue = holding.marketValue;
          totalMarketValue += holding.marketValue;
        }
      } catch (e) {
        print('Error updating price for ${holding.symbol}: $e');
        holding.currentPrice = holding.averageBuyPrice;
        holding.marketValue = holding.quantity * holding.averageBuyPrice;
        holding.currentValue = holding.marketValue;
        totalMarketValue += holding.marketValue;
      }
    }

    // Update portfolio total values
    portfolio.totalMarketValue = totalMarketValue;
    portfolio.totalInvestment = totalInvestment;
    portfolio.totalProfit = totalMarketValue - totalInvestment;

    // If cumulativePurchases was not set from server data, calculate from trades
    if (portfolio.cumulativePurchases <= 0 && portfolio.paperTrades.isNotEmpty) {
      double totalPurchases = 0.0;
      for (var trade in portfolio.paperTrades) {
        if (trade.type.toUpperCase() == 'BUY') {
          totalPurchases += trade.totalAmount;
        }
      }
      portfolio.cumulativePurchases = totalPurchases;
    }
    
    // Important: Portfolio value is Cash Balance + Market Value of Holdings
    // No need to modify the calculation as portfolio.portfolioValue already 
    // returns currentBalance + totalMarketValue
    print('Portfolio updated: Cash Balance=${portfolio.currentBalance}, Market Value=${totalMarketValue}, Total Value=${portfolio.portfolioValue}');
  }
}