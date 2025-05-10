import 'package:flutter/foundation.dart';
import 'package:nepse_market_app/models/stock.dart';
import 'package:nepse_market_app/services/market_service.dart';
import 'package:nepse_market_app/utils/map_utils.dart'; // Add this import
import 'dart:math';
import 'package:intl/intl.dart';

class MarketProvider extends ChangeNotifier {
  final MarketService _marketService = MarketService();
  
  // For Top Gainers
  List<Stock> _gainers = [];
  bool _isLoadingGainers = false;
  String? _gainerError;

  // For Top Losers  
  List<Stock> _losers = [];
  bool _isLoadingLosers = false;
  String? _loserError;
  
  // For Live Trading
  List<Stock> _liveTrading = [];
  bool _isLoadingLiveTrading = false;
  String? _liveTradingError;
  
  // For Indices
  List<Map<String, dynamic>> _indices = [];
  bool _isLoadingIndices = false;
  String? _indicesError;
  
  // For Company Details
  Map<String, dynamic>? _companyDetails;
  bool _isLoadingCompanyDetails = false;
  String? _companyDetailsError;

  // For Stock Historical Data
  Map<String, List<dynamic>> _stockHistoricalData = {};
  
  // Getters
  List<Stock> get gainers => _gainers;
  List<Stock> get losers => _losers;
  List<Stock> get liveTrading => _liveTrading;
  List<Map<String, dynamic>> get indices => _indices;
  Map<String, dynamic>? get companyDetails => _companyDetails;
  bool get isLoadingGainers => _isLoadingGainers;
  bool get isLoadingLosers => _isLoadingLosers;
  bool get isLoadingLiveTrading => _isLoadingLiveTrading;
  bool get isLoadingIndices => _isLoadingIndices;
  bool get isLoadingCompanyDetails => _isLoadingCompanyDetails;
  String? get gainerError => _gainerError;
  String? get loserError => _loserError;
  String? get liveTradingError => _liveTradingError;
  String? get indicesError => _indicesError;
  String? get companyDetailsError => _companyDetailsError;
  
  Future<void> loadAllMarketData() async {
    // Load live trading data first as gainers and losers depend on it
    await loadLiveTrading();
    
    // Then calculate gainers and losers from that data
    await Future.wait([
      loadTopGainers(), 
      loadTopLosers(),
      loadIndices()
    ]);
  }

  Future<void> loadTopGainers() async {
    _isLoadingGainers = true;
    _gainerError = null;
    notifyListeners();
    
    try {
      // Use existing live trading data if available, otherwise fetch new data
      if (_liveTrading.isNotEmpty) {
        _gainers = _marketService.calculateTopGainers(_liveTrading);
      } else {
        _gainers = await _marketService.getTopGainers();
      }
      _gainerError = null;
    } catch (e) {
      _gainerError = e.toString();
      _gainers = []; // Ensure this is empty on error
    } finally {
      _isLoadingGainers = false;
      notifyListeners();
    }
  }
  
  Future<void> loadTopLosers() async {
    _isLoadingLosers = true;
    _loserError = null;
    notifyListeners();
    
    try {
      // Use existing live trading data if available, otherwise fetch new data
      if (_liveTrading.isNotEmpty) {
        _losers = _marketService.calculateTopLosers(_liveTrading);
      } else {
        _losers = await _marketService.getTopLosers();
      }
      _loserError = null;
    } catch (e) {
      _loserError = e.toString();
      _losers = []; // Ensure this is empty on error
    } finally {
      _isLoadingLosers = false;
      notifyListeners();
    }
  }
  
  Future<void> loadLiveTrading() async {
    _isLoadingLiveTrading = true;
    _liveTradingError = null;
    notifyListeners();
    
    try {
      // Set a timeout for just this call
      final liveData = await _marketService.getLiveTrading()
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            // Return cached data or empty list on timeout
            print('Live trading request timed out, using cached data');
            return _liveTrading.isNotEmpty ? _liveTrading : [];
          }
        );
      
      if (liveData.isNotEmpty) {
        _liveTrading = liveData;
      }
      _liveTradingError = null;
    } catch (e) {
      _liveTradingError = e.toString();
      print('Error loading live trading: $_liveTradingError');
    } finally {
      _isLoadingLiveTrading = false;
      notifyListeners();
    }
  }
  
  Future<void> loadIndices() async {
    _isLoadingIndices = true;
    _indicesError = null;
    notifyListeners();
    
    try {
      var rawIndices = await _marketService.getIndices();
      
      // Sanitize the indices data before using it
      _indices = rawIndices.map((index) {
        // Ensure all indices have valid values
        return {
          'name': index['name'] ?? 'Unknown',
          'value': _parseNumeric(index['value'], 0.0),
          'change': _parseNumeric(index['change'], 0.0),
          'percentChange': _parseNumeric(index['percentChange'], 0.0),
        };
      }).toList();
      
      _indicesError = null;
    } catch (e) {
      _indicesError = e.toString();
    } finally {
      _isLoadingIndices = false;
      notifyListeners();
    }
  }
  
  Future<void> loadCompanyDetails(String symbol) async {
    _isLoadingCompanyDetails = true;
    _companyDetailsError = null;
    notifyListeners();
    
    try {
      print('Fetching company details for $symbol');
      final data = await _marketService.getCompanyDetails(symbol);
      
      // Debug the data structure 
      print('Received company data keys: ${data.keys.toList()}');
      print('Data type: ${data.runtimeType}');
      
      _companyDetails = data;
      _companyDetailsError = null;
    } catch (e) {
      print('Error loading company details: $e');
      _companyDetailsError = e.toString();
    } finally {
      _isLoadingCompanyDetails = false;
      notifyListeners();
    }
  }
  
  // Helper method to safely parse numeric values
  double _parseNumeric(dynamic value, double defaultValue) {
    if (value == null) return defaultValue;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) {
      try {
        return double.parse(value);
      } catch (_) {
        return defaultValue;
      }
    }
    return defaultValue;
  }
  
  // Find stock price by symbol from live trading list
  double getStockPriceFromLiveTrading(String symbol) {
    final stock = _liveTrading.firstWhere(
      (stock) => stock.symbol == symbol,
      orElse: () => Stock(
        symbol: symbol,
        name: '',
        ltp: 0,
        changePercent: 0,
        high: 0,
        low: 0,
        open: 0,
        quantity: 0,
        previousClose: 0, // Added the required parameter
      ),
    );
    return stock.ltp;
  }

  double? getStockPrice(String symbol) {
    try {
      // Make sure liveTrading data is loaded
      if (_liveTrading.isEmpty) {
        print('Live trading data not loaded yet');
        return null;
      }
      
      // Find the stock in the list
      final stock = _liveTrading.firstWhere(
        (stock) => stock.symbol.toUpperCase() == symbol.toUpperCase(),
        orElse: () => Stock(
          symbol: symbol,
          name: 'Unknown',
          ltp: 0,
          changePercent: 0,
          high: 0,
          low: 0,
          open: 0,
          quantity: 0,
          previousClose: 0,
        ),
      );
      
      if (stock == null) {
        print('Stock not found: $symbol');
        // Return a random price for demo purposes only (around 100-500 range)
        return 100 + (DateTime.now().millisecondsSinceEpoch % 400).toDouble();
      }
      
      return stock.ltp;
    } catch (e) {
      print('Error getting stock price for $symbol: $e');
      // Return a fallback price (only for paper trading)
      return 100 + (symbol.length * 10).toDouble();
    }
  }

  double? getPreviousClosePrice(String symbol) {
    // Find stock in liveTrading list and return its previous close price
    try {
      final stock = liveTrading.firstWhere((stock) => stock.symbol == symbol);
      return stock.previousClose;
    } catch (e) {
      return null;
    }
  }

  // Define the getStockData method with actual implementation
  StockData? getStockData(String symbol) {
    try {
      // Find the stock in the live trading list
      final stock = liveTrading.firstWhere((stock) => stock.symbol == symbol);
      
      // Return actual stock data from your live trading list
      return StockData(
        symbol: stock.symbol,
        previousClose: stock.previousClose,
      );
    } catch (e) {
      print('Stock not found in live trading: $symbol');
      return null;
    }
  }

  // Load historical data for a stock
  Future<void> loadStockHistoricalData(String symbol) async {
    try {
      // If we already have the data, don't reload
      if (_stockHistoricalData.containsKey(symbol)) {
        return;
      }
      
      final response = await _marketService.getStockHistoricalData(symbol);
      
      if (response.statusCode == 200 && response.data is Map && response.data['success'] == true) {
        final List<dynamic> data = response.data['data'];
        _stockHistoricalData[symbol] = data;
      } else {
        // Create some mock historical data for demo
        _stockHistoricalData[symbol] = _createMockHistoricalData(symbol);
      }
    } catch (e) {
      print('Error loading historical data for $symbol: $e');
      // Create some mock historical data as fallback
      _stockHistoricalData[symbol] = _createMockHistoricalData(symbol);
    }
  }
  
  // Get historical data for a stock
  List<dynamic>? getStockHistoricalData(String symbol) {
    return _stockHistoricalData[symbol];
  }
  
  // Create mock historical data for demo purposes
  List<dynamic> _createMockHistoricalData(String symbol) {
    final basePrice = getStockPrice(symbol) ?? 1000.0;
    final random = Random();
    final now = DateTime.now();
    
    return List.generate(30, (index) {
      final date = now.subtract(Duration(days: index));
      final close = basePrice * (1 + (random.nextDouble() - 0.5) * 0.05);
      final open = close * (1 + (random.nextDouble() - 0.5) * 0.03);
      final high = max(open, close) * (1 + random.nextDouble() * 0.02);
      final low = min(open, close) * (1 - random.nextDouble() * 0.02);
      final volume = random.nextInt(10000) + 1000;
      
      return {
        'date': DateFormat('yyyy-MM-dd').format(date),
        'open': open,
        'close': close,
        'high': high,
        'low': low,
        'volume': volume
      };
    });
  }
}

// Example StockData class
class StockData {
  final String symbol;
  final double? previousClose;

  StockData({required this.symbol, this.previousClose});
}