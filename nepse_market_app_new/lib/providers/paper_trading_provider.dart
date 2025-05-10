import 'package:flutter/foundation.dart';
import 'package:nepse_market_app/models/paper_trade.dart';
import 'package:nepse_market_app/providers/market_provider.dart';

class PaperTradingProvider extends ChangeNotifier {
  final MarketProvider _marketProvider;
  
  List<PaperTrade> _trades = [];
  bool _isLoading = false;
  String? _errorMessage;
  double _balance = 1000000.0; // Starting with 1 million NPR for paper trading
  
  // Constructor that accepts a market provider
  PaperTradingProvider(this._marketProvider);
  
  // Getters
  List<PaperTrade> get trades => _trades;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  double get balance => _balance;
  
  // Add a paper trade
  Future<bool> addTrade(String symbol, double quantity, double price, String type) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      // Check if user has enough balance for buying
      if (type.toLowerCase() == 'buy') {
        final cost = quantity * price;
        if (cost > _balance) {
          _errorMessage = 'Insufficient balance for this trade';
          _isLoading = false;
          notifyListeners();
          return false;
        }
        
        // Deduct from balance
        _balance -= cost;
      }
      
      // Get current market price for the symbol
      double? currentPrice;
      try {
        currentPrice = _marketProvider.getStockPrice(symbol);
      } catch (e) {
        // If price can't be retrieved, use the provided price
        currentPrice = price;
      }
      
      // Create a new paper trade
      final newTrade = PaperTrade(
        id: DateTime.now().millisecondsSinceEpoch, // Simple ID generation
        symbol: symbol,
        quantity: quantity,
        buyPrice: price,
        currentPrice: currentPrice ?? price,
        type: type,
        timestamp: DateTime.now(),
      );
      
      // Add to trades list
      _trades.add(newTrade);
      
      // Calculate profit/loss for sell trades
      if (type.toLowerCase() == 'sell') {
        // Find matching buy trades
        final buyTrades = _trades.where((t) => 
            t.symbol == symbol && 
            t.type.toLowerCase() == 'buy' && 
            t.quantity >= quantity).toList();
        
        if (buyTrades.isNotEmpty) {
          final avgBuyPrice = buyTrades[0].buyPrice;
          final sellValue = quantity * price;
          
          // Add sell value to balance
          _balance += sellValue;
        }
      }
      
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
  
  // Method to update current prices of all trades
  void updatePrices() {
    for (var trade in _trades) {
      try {
        final currentPrice = _marketProvider.getStockPrice(trade.symbol);
        if (currentPrice != null) {
          trade.currentPrice = currentPrice;
        }
      } catch (e) {
        // Ignore errors, keep existing price
        print('Error updating price for ${trade.symbol}: $e');
      }
    }
    notifyListeners();
  }
  
  // Calculate total portfolio value
  double get totalValue {
    double total = _balance;
    
    // Group trades by symbol
    final Map<String, double> holdings = {};
    
    for (var trade in _trades) {
      if (trade.type.toLowerCase() == 'buy') {
        holdings[trade.symbol] = (holdings[trade.symbol] ?? 0) + trade.quantity;
      } else if (trade.type.toLowerCase() == 'sell') {
        holdings[trade.symbol] = (holdings[trade.symbol] ?? 0) - trade.quantity;
      }
    }
    
    // Calculate value of each holding
    holdings.forEach((symbol, quantity) {
      if (quantity > 0) {
        try {
          final price = _marketProvider.getStockPrice(symbol) ?? 0;
          total += price * quantity;
        } catch (e) {
          // Use last known price if current price is not available
          final lastTrade = _trades.lastWhere(
            (t) => t.symbol == symbol,
            orElse: () => _trades[0],
          );
          total += lastTrade.currentPrice * quantity;
        }
      }
    });
    
    return total;
  }
}
