class PaperTrade {
  final int id;
  final int portfolioId;
  final String symbol;
  final String? companyName;
  final String type; // 'BUY' or 'SELL'
  final double quantity;
  final double price;
  final DateTime tradeDate;
  final double totalAmount;
  final DateTime createdAt;
  final DateTime timestamp; // Added timestamp field

  
  PaperTrade({
    required this.id,
    required this.portfolioId,
    required this.symbol,
    this.companyName,
    required this.type,
    required this.quantity,
    required this.price,
    required this.tradeDate,
    required this.totalAmount,
    required this.createdAt,
    required this.timestamp,
  });
  
  factory PaperTrade.fromJson(Map<String, dynamic> json) {
    try {
      return PaperTrade(
        id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
        portfolioId: json['portfolio_id'] is int ? json['portfolio_id'] : int.parse(json['portfolio_id'].toString()),
        symbol: json['symbol'] ?? '',
        companyName: json['company_name'],
        type: json['type'] ?? 'BUY',
        quantity: _parseDouble(json['quantity']),
        price: _parseDouble(json['price']),
        tradeDate: json['trade_date'] != null ? DateTime.parse(json['trade_date']) : DateTime.now(),
        totalAmount: _parseDouble(json['total_amount']),
        createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
        timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : DateTime.now(),
      );
    } catch (e) {
      print('Error parsing trade: $e');
      // Return a default trade object instead of throwing
      return PaperTrade(
        id: 0,
        portfolioId: 0,
        symbol: json['symbol'] ?? 'ERROR',
        type: json['type'] ?? 'BUY',
        quantity: 0,
        price: 0,
        tradeDate: DateTime.now(),
        totalAmount: 0,
        createdAt: DateTime.now(),
        timestamp: DateTime.now(),
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
      'portfolio_id': portfolioId,
      'symbol': symbol,
      'company_name': companyName,
      'type': type,
      'quantity': quantity,
      'price': price,
      'trade_date': tradeDate.toIso8601String(),
      'total_amount': totalAmount,
      'created_at': createdAt.toIso8601String(),
    };
  }
}