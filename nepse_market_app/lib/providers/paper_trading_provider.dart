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
      
      // Validate balances for all portfolios (run in background)
      _validateAllPortfolioBalances();
      
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
      print('Loading paper portfolio details for ID: $portfolioId');
      
      // Get portfolio details
      final portfolio = await _paperTradingService.getPaperPortfolioDetails(portfolioId);
      
      print('Loaded portfolio: id=${portfolio.id}, balance=${portfolio.currentBalance}, initial=${portfolio.initialBalance}');
      
      // Update prices
      _updatePortfolioMarketPrices(portfolio);
      
      // Load trade history separately to ensure it's up to date
      try {
        _paperTrades = await _paperTradingService.getPaperTradeHistory(portfolioId);
      } catch (tradeError) {
        print('Error loading trades, continuing with empty list: $tradeError');
        _paperTrades = [];
      }
      
      // Set as selected portfolio - preserve the current balance that came from server
      _selectedPaperPortfolio = portfolio;
      
      // Store current balance for debugging
      print('Stored portfolio with balance: ${_selectedPaperPortfolio?.currentBalance}');
      
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
  
  // Improved trade execution with proper balance handling
  Future<bool> executePaperTrade(int portfolioId, String symbol, String type, double quantity, double? price) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      final actualPrice = price ?? _marketProvider.getStockPrice(symbol) ?? 0;
      
      if (actualPrice <= 0) {
        _errorMessage = "Cannot get valid market price. Please enter price manually.";
        _isLoading = false;
        notifyListeners();
        return false;
      }
      
      // Pre-validate the trade to avoid server-side balance issues
      final portfolio = getPortfolio(portfolioId);
      final tradeAmount = quantity * actualPrice;
      
      // For buy orders, ensure we have enough balance
      if (type.toLowerCase() == 'buy' && portfolio.currentBalance < tradeAmount) {
        _errorMessage = "Insufficient balance for this trade.";
        _isLoading = false;
        notifyListeners();
        return false;
      }
      
      final success = await _paperTradingService.executePaperTrade(
        portfolioId,
        symbol,
        type,
        quantity,
        actualPrice,
      );
      
      // Refresh portfolio data on success
      if (success) {
        await loadPaperPortfolioDetails(portfolioId);
        _errorMessage = null;
      }
      
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      final errorMsg = e.toString();
      
      // Handle specific error types with user-friendly messages
      if (errorMsg.contains('Insufficient balance')) {
        _errorMessage = "You don't have enough balance to complete this trade.";
      } else if (errorMsg.contains('Invalid balance format')) {
        _errorMessage = "Portfolio balance needs repair. Please use the 'Fix Balance' option.";
      } else if (errorMsg.contains('quantity')) {
        _errorMessage = "Please enter a valid quantity.";
      } else {
        _errorMessage = "Error: $errorMsg";
      }
      
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  // Add a method to fix balance issues
  Future<bool> fixBalanceIssue(int portfolioId) async {
    _isLoading = true;
    _errorMessage = "Attempting to fix portfolio balance...";
    notifyListeners();
    
    try {
      // Call the renamed method that doesn't require a balance parameter
      final success = await _paperTradingService.fixPortfolioBalanceAuto(portfolioId);
      
      if (success) {
        // Refresh portfolio details
        await loadPaperPortfolioDetails(portfolioId);
        _errorMessage = null;
      } else {
        _errorMessage = "Failed to fix portfolio balance";
      }
      
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = "Error fixing balance: ${e.toString()}";
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  // Add a method to fix portfolio balance
  Future<bool> fixPortfolioBalance(int portfolioId) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      // Calculate the proper balance based on initial balance and trades
      double estimatedBalance = 150000; // Default
      
      if (_selectedPaperPortfolio != null) {
        estimatedBalance = _selectedPaperPortfolio!.initialBalance;
        
        // Apply trades
        if (_paperTrades.isNotEmpty) {
          for (var trade in _paperTrades) {
            if (trade.type.toUpperCase() == 'BUY') {
              estimatedBalance -= trade.totalAmount;
            } else if (trade.type.toUpperCase() == 'SELL') {
              estimatedBalance += trade.totalAmount;
            }
          }
        }
      }
      
      // Fix the balance
      final success = await _paperTradingService.fixPortfolioBalance(portfolioId, estimatedBalance);
      
      // Reload portfolio details
      if (success) {
        await loadPaperPortfolioDetails(portfolioId);
        _errorMessage = null;
      } else {
        _errorMessage = 'Failed to repair portfolio balance';
      }
      
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = 'Error fixing portfolio balance: $e';
      print(_errorMessage);
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

  // Add this new method
  Future<void> _validateAllPortfolioBalances() async {
    // Don't set loading state as this runs in background
    try {
      for (var portfolio in _paperPortfolios) {
        await _paperTradingService.validatePortfolioBalance(portfolio.id);
      }
    } catch (e) {
      print('Error validating portfolio balances: $e');
      // Don't set error message as this is a background task
    }
  }

  // Improved method to get a specific portfolio by ID with balance validation
  PaperPortfolio getPortfolio(int portfolioId) {
    try {
      final portfolio = _paperPortfolios.firstWhere(
        (portfolio) => portfolio.id == portfolioId,
        orElse: () => _createLocalFallbackPortfolio(),
      );
      
      // Validate the portfolio has a valid balance
      if (portfolio.currentBalance.isNaN || 
          portfolio.currentBalance.isInfinite ||
          portfolio.currentBalance <= 0) {
        print('Warning: Portfolio ${portfolio.id} has invalid balance: ${portfolio.currentBalance}');
        
        // Automatically fix the balance if it's invalid
        // Use initialBalance if available, otherwise default
        double fixedBalance = 150000.0;
        if (portfolio.initialBalance > 0 && 
            !portfolio.initialBalance.isNaN &&
            !portfolio.initialBalance.isInfinite) {
          fixedBalance = portfolio.initialBalance;
        }
        
        // Create a copy with the fixed balance
        return PaperPortfolio(
          id: portfolio.id,
          name: portfolio.name,
          description: portfolio.description,
          initialBalance: portfolio.initialBalance.isFinite ? portfolio.initialBalance : 150000.0,
          currentBalance: fixedBalance,
          holdings: portfolio.holdings,
          paperTrades: portfolio.paperTrades,
        );
      }
      
      return portfolio;
    } catch (e) {
      print('Error getting portfolio with ID $portfolioId: $e');
      // Return fallback portfolio if something goes wrong
      return _selectedPaperPortfolio ?? 
             (_paperPortfolios.isNotEmpty ? _paperPortfolios.first : _createLocalFallbackPortfolio());
    }
  }

  // Add this method to validate portfolio balance before trade
  Future<bool> validatePortfolioBalance(int portfolioId) async {
    try {
      // Don't set loading state since this is a background check
      final portfolio = getPortfolio(portfolioId);
      
      if (portfolio.currentBalance.isNaN || 
          portfolio.currentBalance.isInfinite ||
          portfolio.currentBalance == null) {
        return false;
      }
      
      // For buy trades, we need a positive balance
      if (portfolio.currentBalance <= 0) {
        print('Portfolio $portfolioId has non-positive balance: ${portfolio.currentBalance}');
        return false;
      }
      
      // If we already have a portfolio with a valid balance locally, no need to call server
      return true;
    } catch (e) {
      print('Error validating portfolio balance locally: $e');
      
      // Try to validate on the server
      try {
        return await _paperTradingService.validatePortfolioBalance(portfolioId);
      } catch (serverError) {
        print('Server validation failed: $serverError');
        return false;
      }
    }
  }

  // Completely refresh portfolio data from server
  Future<void> forcePaperPortfolioRefresh(int portfolioId) async {
    try {
      print('Force refreshing portfolio $portfolioId');
      _isLoading = true;
      notifyListeners();
      
      // Get fresh data from server with cache bypass
      final portfolio = await _paperTradingService.refreshPaperPortfolioDetails(portfolioId);
      
      // Log the values we got
      print('Received fresh portfolio data: balance=${portfolio.currentBalance}');
      
      // Update prices and market data
      _updatePortfolioMarketPrices(portfolio);
      
      // Reload trade history to ensure everything is in sync
      _paperTrades = await _paperTradingService.getPaperTradeHistory(portfolioId);
      
      // Update selected portfolio with FRESH data
      _selectedPaperPortfolio = portfolio;
      
      // Update the cached portfolio in the list
      final index = _paperPortfolios.indexWhere((p) => p.id == portfolioId);
      if (index >= 0) {
        _paperPortfolios[index] = portfolio;
      }
      
      _errorMessage = null;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      print('Error during force refresh: $e');
      _errorMessage = 'Failed to refresh data: $e';
      _isLoading = false;
      notifyListeners();
    }
  }
}