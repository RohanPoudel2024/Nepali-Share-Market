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
  List<PaperTrade> _paperTrades = [];

  PaperPortfolio({
    required this.id,
    required this.name,
    this.description,
    required this.initialBalance,
    required this.currentBalance,
    required this.holdings,
    List<PaperTrade>? paperTrades,
  }) : _paperTrades = paperTrades ?? [];

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

  double get portfolioValue => currentBalance + totalMarketValue;

  double get totalInvested => totalInvestment;

  double get profitPercentage {
    if (totalInvestment <= 0) return 0.0;
    return (totalProfit / totalInvestment) * 100;
  }

  List<PaperTrade> get paperTrades => _paperTrades;
  set paperTrades(List<PaperTrade> value) {
    _paperTrades = value;
  }

  factory PaperPortfolio.fromJson(Map<String, dynamic> json) {
    try {
      // Extract ID safely - handle both numeric and string values
      int id;
      if (json['id'] is int) {
        id = json['id'];
      } else if (json['id'] is String) {
        id = int.tryParse(json['id']) ?? 0;
      } else {
        id = 0;
      }

      // Extract other fields safely
      final name = json['name'] as String? ?? "Unnamed Portfolio";
      final description = json['description'] as String?;
      
      // Parse numeric fields safely - handle both camelCase and snake_case keys
      final initialBalance = _parseDouble(json['initial_balance'] ?? json['initialBalance'] ?? 150000.0);
      final currentBalance = _parseDouble(json['current_balance'] ?? json['currentBalance'] ?? initialBalance);
      
      // Parse holdings safely
      List<PaperHolding> holdingsList = [];
      if (json['holdings'] != null) {
        try {
          holdingsList = (json['holdings'] as List)
              .map((holding) => holding is Map ? PaperHolding.fromJson(holding.cast<String, dynamic>()) : PaperHolding(
                id: 0,
                symbol: "Unknown", 
                quantity: 0,
                averageBuyPrice: 0,
                buyPrice: 0
              ))
              .toList();
        } catch (e) {
          print('Error parsing holdings: $e');
        }
      }
      
      // Parse trades safely
      List<PaperTrade> tradesList = [];
      if (json['trades'] != null) {
        try {
          tradesList = (json['trades'] as List)
              .map((trade) => trade is Map ? PaperTrade.fromJson(trade.cast<String, dynamic>()) : PaperTrade(
                id: 0,
                portfolioId: id,
                symbol: "Unknown",
                type: "BUY",
                quantity: 0,
                price: 0,
                tradeDate: DateTime.now(),
                totalAmount: 0,
                createdAt: DateTime.now(),
                timestamp: DateTime.now(),
              ))
              .toList();
        } catch (e) {
          print('Error parsing trades: $e');
        }
      }
      
      return PaperPortfolio(
        id: id,
        name: name,
        description: description,
        initialBalance: initialBalance,
        currentBalance: currentBalance,
        holdings: holdingsList,
        paperTrades: tradesList,
      );
    } catch (e) {
      print('Error in PaperPortfolio.fromJson: $e');
      // Return a default portfolio instead of throwing
      return PaperPortfolio(
        id: 1,
        name: "Error Portfolio",
        description: "Failed to parse portfolio data",
        initialBalance: 150000.0,
        currentBalance: 150000.0,
        holdings: [],
      );
    }
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) {
      try {
        return double.parse(value);
      } catch (_) {
        return 0.0;
      }
    }
    return 0.0;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'initial_balance': initialBalance,
      'current_balance': currentBalance,
      'holdings': holdings.map((holding) => holding.toJson()).toList(),
      'trades': paperTrades.map((trade) => trade is Map ? trade : trade.toJson()).toList(),
      'total_market_value': _totalMarketValue,
      'total_investment': _totalInvestment,
      'total_profit': _totalProfit,
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
    return PaperHolding(
      id: json['id'],
      symbol: json['symbol'],
      companyName: json['company_name'],
      quantity: _parseDouble(json['quantity']),
      averageBuyPrice: _parseDouble(json['average_buy_price']),
      currentPrice: _parseDouble(json['current_price']),
      buyPrice: _parseDouble(json['buy_price']),
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
    };
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) {
      try {
        return double.parse(value);
      } catch (_) {
        return 0.0;
      }
    }
    return 0.0;
  }
}