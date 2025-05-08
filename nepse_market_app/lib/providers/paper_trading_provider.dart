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
  
  // Execute a paper trade
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
      
      if (actualPrice <= 0) {
        throw Exception('Invalid stock price');
      }
      
      // Cache the portfolio before trade to compare balances after
      final oldBalance = _selectedPaperPortfolio?.currentBalance ?? 0;
      
      // Execute the trade
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
      
      // Important - reload complete portfolio data to refresh holdings and balance
      await loadPaperPortfolioDetails(portfolioId);
      
      // Also reload the trade history separately to ensure it's updated
      try {
        _paperTrades = await _paperTradingService.getPaperTradeHistory(portfolioId);
        notifyListeners(); // Make sure UI updates with new trades
      } catch (tradeHistoryError) {
        print('Warning: Trade executed but could not refresh trade history: $tradeHistoryError');
        // Create a simple temporary trade record to show in UI while history loads
        final tempTrade = PaperTrade(
          id: DateTime.now().millisecondsSinceEpoch,
          portfolioId: portfolioId,
          symbol: symbol,
          type: type.toUpperCase(),
          quantity: quantity,
          price: actualPrice,
          totalAmount: quantity * actualPrice,
          tradeDate: DateTime.now(),
          createdAt: DateTime.now(),
          timestamp: DateTime.now(),
        );
        
        // Add temporary trade to list
        if (_paperTrades == null) {
          _paperTrades = [tempTrade];
        } else {
          _paperTrades = [tempTrade, ..._paperTrades];
        }
      }
      
      // Log the balance changes for debugging
      final newBalance = _selectedPaperPortfolio?.currentBalance ?? 0;
      print('Portfolio balance change: $oldBalance -> $newBalance (${newBalance - oldBalance})');
      
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
    if (portfolio.holdings.isEmpty) {
      portfolio.totalMarketValue = 0.0;
      portfolio.totalInvestment = 0.0;
      portfolio.totalProfit = 0.0;
      return;
    }

    double totalMarketValue = 0.0;
    double totalInvestment = 0.0;

    for (var holding in portfolio.holdings) {
      // Calculate total investment
      totalInvestment += holding.quantity * holding.buyPrice;
      
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
          holding.currentPrice = holding.buyPrice;
          holding.marketValue = holding.quantity * holding.buyPrice;
          holding.currentValue = holding.marketValue;
          totalMarketValue += holding.marketValue;
        }
      } catch (e) {
        print('Error updating price for ${holding.symbol}: $e');
        holding.currentPrice = holding.buyPrice;
        holding.marketValue = holding.quantity * holding.buyPrice;
        holding.currentValue = holding.marketValue;
        totalMarketValue += holding.marketValue;
      }
    }

    // Update portfolio total values
    portfolio.totalMarketValue = totalMarketValue;
    portfolio.totalInvestment = totalInvestment;
    portfolio.totalProfit = totalMarketValue - totalInvestment;
  }
}