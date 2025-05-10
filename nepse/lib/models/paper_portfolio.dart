import 'package:nepse_market_app/models/paper_trade.dart';

class PaperPortfolio {
  final int id;
  final String name;
  final String? description;
  double initialBalance;
  double currentBalance;
  List<PaperHolding> holdings;
  double _totalMarketValue = 0.0;
  double _totalInvestment = 0.0;
  double _totalProfit = 0.0;
  double _cumulativePurchases = 0.0;
  List<PaperTrade> _paperTrades = [];

  PaperPortfolio({
    required this.id,
    required this.name,
    this.description,
    required this.initialBalance,
    required this.currentBalance,
    required this.holdings,
    List<PaperTrade>? paperTrades,
    double cumulativePurchases = 0.0,
  })  : _paperTrades = paperTrades ?? [],
        _cumulativePurchases = cumulativePurchases;

  double get totalMarketValue => _totalMarketValue;
  set totalMarketValue(double value) {
    _totalMarketValue = value;
  }

  double get totalInvestment => _totalInvestment;
  set totalInvestment(double value) {
    _totalInvestment = value;
  }
  
  double get totalProfit => _totalProfit;
  set totalProfit(double value) {
    _totalProfit = value;
  }

  double get cumulativePurchases => _cumulativePurchases;
  set cumulativePurchases(double value) {
    _cumulativePurchases = value;
  }

  double get totalSpent => _cumulativePurchases;

  double get portfolioValue {
    return currentBalance + totalMarketValue;
  }

  double get profitPercentage {
    if (totalInvestment <= 0) return 0.0;
    return (totalProfit / totalInvestment) * 100;
  }
  
  double get returnOnInvestment {
    // Calculate ROI based on the portfolio initial balance
    if (initialBalance <= 0) return 0.0;
    
    // Calculate the total value change compared to initial investment
    final totalValueChange = portfolioValue - initialBalance;
    return (totalValueChange / initialBalance) * 100;
  }

  List<PaperTrade> get paperTrades => _paperTrades;
  set paperTrades(List<PaperTrade> value) {
    _paperTrades = value;
  }

  factory PaperPortfolio.fromJson(Map<String, dynamic> json) {
    // Parse finance values with strict numeric validation
    double parseFinanceValue(dynamic value, double defaultValue) {
      if (value == null) return defaultValue;
      
      // Handle numeric values directly
      if (value is num) return value.toDouble();
      
      // Handle string values by parsing
      if (value is String) {
        if (value.isEmpty || value == 'null' || value == 'undefined' || value == 'NaN') {
          return defaultValue;
        }
        
        final parsed = double.tryParse(value);
        if (parsed != null) return parsed;
      }
      
      // Default case
      return defaultValue;
    }
    
    // Apply strict parsing for balance values
    final currentBalance = parseFinanceValue(json['current_balance'], 150000.0);
    final initialBalance = parseFinanceValue(json['initial_balance'], 150000.0);
    final cumulativePurchases = parseFinanceValue(json['cumulative_purchases'], 0.0);
    
    return PaperPortfolio(
      id: json['id'] is String ? int.parse(json['id']) : json['id'],
      name: json['name'] ?? 'Paper Portfolio',
      description: json['description'],
      initialBalance: initialBalance,
      currentBalance: currentBalance,
      cumulativePurchases: cumulativePurchases,
      holdings: json['holdings'] != null 
          ? (json['holdings'] as List).map((h) => PaperHolding.fromJson(h)).toList()
          : [],
      paperTrades: json['trades'] != null
          ? (json['trades'] as List).map((t) => PaperTrade.fromJson(t)).toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'initial_balance': initialBalance,
      'current_balance': currentBalance,
      'holdings': holdings.map((holding) => holding.toJson()).toList(),
      'total_market_value': _totalMarketValue,
      'total_investment': _totalInvestment,
      'total_profit': _totalProfit,
      'cumulative_purchases': _cumulativePurchases,
    };
  }
}

class PaperHolding {
  final int id;
  final String symbol;
  final String? companyName;
  double quantity;
  double averageBuyPrice;
  double? _currentPrice;
  double _marketValue = 0.0;
  double _currentValue = 0.0;
  final double buyPrice;

  PaperHolding({
    required this.id,
    required this.symbol,
    this.companyName,
    required this.quantity,
    required this.averageBuyPrice,
    double? currentPrice,
    double marketValue = 0.0,
    double currentValue = 0.0,
    required this.buyPrice,
  })  : _currentPrice = currentPrice,
        _marketValue = marketValue,
        _currentValue = currentValue;

  double? get currentPrice => _currentPrice;
  set currentPrice(double? value) {
    _currentPrice = value;
  }

  double get marketValue => _marketValue;
  set marketValue(double value) {
    _marketValue = value;
  }

  double get currentValue => _currentValue;
  set currentValue(double value) {
    _currentValue = value;
  }

  double get investmentValue => quantity * averageBuyPrice;
  double get calculatedCurrentValue => quantity * (currentPrice ?? averageBuyPrice);
  double get profit => currentValue - investmentValue;

  double get profitPercentage {
    if (investmentValue == 0) return 0;
    return (profit / investmentValue) * 100;
  }

  factory PaperHolding.fromJson(Map<String, dynamic> json) {
    // Helper function to safely parse doubles
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) {
        try {
          return double.parse(value);
        } catch (_) {
          return 0.0;
        }
      }
      return 0.0;
    }
    
    return PaperHolding(
      id: json['id'] is String ? int.parse(json['id']) : (json['id'] ?? 0),
      symbol: json['symbol'] ?? '',
      companyName: json['company_name'],
      quantity: parseDouble(json['quantity']),
      averageBuyPrice: parseDouble(json['average_buy_price']),
      currentPrice: parseDouble(json['current_price']),
      buyPrice: parseDouble(json['buy_price']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'symbol': symbol,
      'company_name': companyName,
      'quantity': quantity,
      'average_buy_price': averageBuyPrice,
      'current_price': currentPrice,
      'buy_price': buyPrice,
    };
  }
}