import 'package:intl/intl.dart';

class Holding {
  final int id;
  final String symbol;
  final String? companyName;
  double quantity;
  double averageBuyPrice;
  double? currentPrice;
  double? previousClosePrice;
  double? todayChange;
  final bool isActive;

  // Additional calculated fields
  double get investmentValue => quantity * averageBuyPrice;
  double get currentValue => quantity * (currentPrice ?? averageBuyPrice);
  double get profit => currentValue - investmentValue;
  double get profitPercentage => investmentValue > 0 ? (profit / investmentValue * 100) : 0.0;
  double get todaysProfitLoss => quantity * (todayChange ?? 0);

  Holding({
    required this.id,
    required this.symbol,
    this.companyName,
    required this.quantity,
    required this.averageBuyPrice,
    this.currentPrice,
    this.previousClosePrice,
    this.todayChange,
    this.isActive = true,
  });

  factory Holding.fromJson(Map<String, dynamic> json) {
    return Holding(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      symbol: json['symbol'],
      companyName: json['companyName'],
      quantity: json['quantity']?.toDouble() ?? 0.0,
      averageBuyPrice: json['averageBuyPrice']?.toDouble() ?? 0.0,
      currentPrice: json['currentPrice']?.toDouble(),
      previousClosePrice: json['previousClosePrice']?.toDouble(),
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'symbol': symbol,
    'companyName': companyName,
    'quantity': quantity,
    'averageBuyPrice': averageBuyPrice,
    'currentPrice': currentPrice,
    'previousClosePrice': previousClosePrice,
    'todayChange': todayChange,
    'isActive': isActive,
  };
}