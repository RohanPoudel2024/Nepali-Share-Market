import 'package:flutter/foundation.dart';
import 'package:nepse_market_app/models/holding.dart';
import 'package:nepse_market_app/models/portfolio.dart';
import 'package:nepse_market_app/models/transaction.dart';
import 'package:nepse_market_app/providers/market_provider.dart';
import 'package:nepse_market_app/services/portfolio_service.dart';

class PortfolioProvider extends ChangeNotifier {
  final PortfolioService _portfolioService = PortfolioService();
  final MarketProvider _marketProvider;
  
  // Constructor
  PortfolioProvider(this._marketProvider);
  
  // State variables
  List<Portfolio> _portfolios = [];
  Portfolio? _selectedPortfolio;
  List<Transaction> _transactions = [];
  bool _isLoading = false;
  String? _errorMessage;
  
  // Getters
  List<Portfolio> get portfolios => _portfolios;
  Portfolio? get selectedPortfolio => _selectedPortfolio;
  List<Transaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  
  // Load all portfolios for the user
  Future<void> loadUserPortfolios() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      // Get basic portfolios list
      final basicPortfolios = await _portfolioService.getUserPortfolios();
      
      // Create a list to hold complete portfolios with all data
      List<Portfolio> completedPortfolios = [];
      
      // For each portfolio, fetch complete details
      for (var portfolio in basicPortfolios) {
        try {
          print('Fetching complete details for portfolio ${portfolio.id}');
          
          // Get full portfolio details including holdings
          final completePortfolio = await _portfolioService.getPortfolioDetails(portfolio.id);
          
          // Update market prices
          if (completePortfolio.holdings != null) {
            for (var holding in completePortfolio.holdings!) {
              try {
                holding.currentPrice = _marketProvider.getStockPrice(holding.symbol);
                _updateTodayChange(holding);
              } catch (e) {
                print('Error updating price for ${holding.symbol}: $e');
                holding.currentPrice = holding.averageBuyPrice;
              }
            }
          }
          
          completedPortfolios.add(completePortfolio);
        } catch (e) {
          // If we can't get details, use the basic portfolio
          print('Error fetching details for portfolio ${portfolio.id}: $e');
          completedPortfolios.add(portfolio);
        }
      }
      
      _portfolios = completedPortfolios;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Load details for a specific portfolio
  Future<void> loadPortfolioDetails(int portfolioId) async {
    if (_isLoading) return; // Prevent multiple simultaneous loads
    
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      if (portfolioId <= 0) {
        throw Exception('Invalid portfolio ID');
      }
      
      print('Fetching portfolio details for ID: $portfolioId');
      final portfolio = await _portfolioService.getPortfolioDetails(portfolioId);
      print('Portfolio fetched, has holdings: ${portfolio.holdings != null}, count: ${portfolio.holdings?.length ?? 0}');

      // Add these logs to portfolio_provider.dart in the loadPortfolioDetails method
      print('Fetched portfolio details: ${portfolio.name}');
      print('Holdings count: ${portfolio.holdings?.length ?? 0}');
      print('Investment value: ${portfolio.totalInvestment}');
      print('Current value: ${portfolio.totalCurrentValue}');

      // And check the holdings data
      if (portfolio.holdings != null) {
        for (var holding in portfolio.holdings!) {
          print('Holding: ${holding.symbol}, Qty: ${holding.quantity}, Investment: ${holding.investmentValue}, Current: ${holding.currentValue}');
        }
      }

      // First assignment
      _selectedPortfolio = portfolio; 

      // Then update the holdings prices...
      if (portfolio.holdings != null) {
        for (var holding in portfolio.holdings!) {
          try {
            holding.currentPrice = _marketProvider.getStockPrice(holding.symbol);
            final marketData = _marketProvider.getStockData(holding.symbol);
            if (marketData != null) {
              holding.previousClosePrice = marketData.previousClose;
              holding.todayChange = (holding.currentPrice ?? 0) - (marketData.previousClose ?? 0);
            }
          } catch (e) {
            // If stock price can't be retrieved, use average buy price
            holding.currentPrice = holding.averageBuyPrice;
          }
        }
      }
      
      // Second assignment (overwrites the first one)
      _selectedPortfolio = portfolio;
      
      // Load transactions separately
      try {
        _transactions = await _portfolioService.getTransactions(portfolioId);
      } catch (e) {
        print('Error loading transactions: $e');
        _transactions = [];
      }
      
      _errorMessage = null;
    } catch (e) {
      print('Portfolio details error: $e');
      _errorMessage = e.toString();
      
      // Only create an empty portfolio if it wasn't loaded at all
      if (_selectedPortfolio == null) {
        _selectedPortfolio = Portfolio(
          id: portfolioId,
          name: 'Portfolio',
          holdings: [],
        );
      }
    } finally {
      _isLoading = false;
      // Make sure this is the ONLY notifyListeners call at the end
      notifyListeners();
    }
  }

  // Load transactions for a portfolio
  Future<void> loadTransactions(int portfolioId) async {
    try {
      _transactions = await _portfolioService.getTransactions(portfolioId);
    } catch (e) {
      print('Error loading transactions: $e');
      _transactions = [];
    }
  }
  
  // Create a new portfolio
  Future<bool> createPortfolio(String name, String description) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      // Create the portfolio
      final newPortfolio = await _portfolioService.createPortfolio(name, description);
      
      // Add the new portfolio to the list
      _portfolios.add(newPortfolio);
      
      _errorMessage = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  // Add a new holding to a portfolio
  Future<bool> addHolding(
    int portfolioId,
    String symbol,
    double quantity,
    double averageBuyPrice,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      final newHolding = await _portfolioService.addHolding(
        portfolioId,
        symbol,
        quantity,
        averageBuyPrice,
      );
      
      try {
        // Update current price
        newHolding.currentPrice = _marketProvider.getStockPrice(symbol);
        _updateTodayChange(newHolding);
      } catch (e) {
        // If price can't be retrieved, use average buy price
        newHolding.currentPrice = averageBuyPrice;
      }
      
      // Add transaction record now that the API endpoint is implemented
      await _portfolioService.addTransaction(
        portfolioId,
        symbol,
        'Buy',
        quantity,
        averageBuyPrice,
        DateTime.now(),
      );
      
      // Reload the entire portfolio details
      await loadPortfolioDetails(portfolioId);
      
      _errorMessage = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  // Update an existing holding
  Future<bool> updateHolding(
    int holdingId,
    double quantity,
    double price,
    String type,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      final updatedHolding = await _portfolioService.updateHolding(
        holdingId,
        quantity,
        price,
        type,
      );
      
      // Update in selected portfolio if it's loaded
      if (_selectedPortfolio != null && _selectedPortfolio!.holdings != null) {
        final index = _selectedPortfolio!.holdings!.indexWhere((h) => h.id == holdingId);
        
        if (index != -1) {
          final updatedHoldings = List<Holding>.from(_selectedPortfolio!.holdings!);
          
          // If holding is inactive (fully sold), remove it or update it
          if (!updatedHolding.isActive) {
            updatedHoldings.removeAt(index);
          } else {
            try {
              updatedHolding.currentPrice = _marketProvider.getStockPrice(updatedHolding.symbol);
              _updateTodayChange(updatedHolding);
            } catch (e) {
              // If price can't be retrieved, keep existing price
              updatedHolding.currentPrice = price;
            }
            
            updatedHoldings[index] = updatedHolding;
          }
          
          _selectedPortfolio = Portfolio(
            id: _selectedPortfolio!.id,
            name: _selectedPortfolio!.name,
            description: _selectedPortfolio!.description,
            holdings: updatedHoldings,
            totalValue: calculateTotalValue(updatedHoldings),
            createdAt: _selectedPortfolio!.createdAt,
            updatedAt: DateTime.now(),
          );
        }
      }
      
      _errorMessage = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  // Add a transaction to a portfolio
  Future<bool> addTransaction(
    int portfolioId,
    String symbol,
    String type,
    double quantity,
    double price,
    DateTime date,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      // First add the transaction record
      final transaction = await _portfolioService.addTransaction(
        portfolioId,
        symbol,
        type,
        quantity,
        price,
        date,
      );
      
      // Cache the new transaction locally
      _transactions.add(transaction);
      
      // Then update the holding accordingly
      if (type.toLowerCase() == 'buy') {
        // Rest of your code stays the same
      } else if (type.toLowerCase() == 'sell') {
        // Rest of your code stays the same
      }
      
      // Reload portfolio details to get latest data
      await loadPortfolioDetails(portfolioId);
      
      _errorMessage = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Internal method to add holding without transaction side effects
  Future<void> _addHoldingInternal(
    int portfolioId,
    String symbol,
    double quantity,
    double price,
  ) async {
    final newHolding = await _portfolioService.addHolding(
      portfolioId,
      symbol,
      quantity,
      price,
    );
    
    try {
      newHolding.currentPrice = _marketProvider.getStockPrice(symbol);
      _updateTodayChange(newHolding);
    } catch (e) {
      newHolding.currentPrice = price;
    }
    
    // Update selected portfolio if needed
    if (_selectedPortfolio != null && _selectedPortfolio!.id == portfolioId) {
      final updatedHoldings = List<Holding>.from(_selectedPortfolio!.holdings ?? []);
      updatedHoldings.add(newHolding);
      
      _selectedPortfolio = Portfolio(
        id: _selectedPortfolio!.id,
        name: _selectedPortfolio!.name,
        description: _selectedPortfolio!.description,
        holdings: updatedHoldings,
        totalValue: calculateTotalValue(updatedHoldings),
        createdAt: _selectedPortfolio!.createdAt,
        updatedAt: DateTime.now(),
      );
    }
  }
  
  // Helper method to calculate total portfolio value from holdings
  double calculateTotalValue(List<Holding>? holdings) {
    if (holdings == null || holdings.isEmpty) {
      return 0.0;
    }
    
    double total = 0.0;
    for (final holding in holdings) {
      final price = holding.currentPrice ?? holding.averageBuyPrice;
      total += holding.quantity * price;
    }
    return total;
  }
  
  // Helper method to update today's price change for a holding
  void _updateTodayChange(Holding holding) {
    try {
      final marketData = _marketProvider.getStockData(holding.symbol);
      if (marketData != null) {
        holding.previousClosePrice = marketData.previousClose;
        holding.todayChange = (holding.currentPrice ?? 0) - (marketData.previousClose ?? 0);
      }
    } catch (e) {
      print('Error updating today change for ${holding.symbol}: $e');
    }
  }
}