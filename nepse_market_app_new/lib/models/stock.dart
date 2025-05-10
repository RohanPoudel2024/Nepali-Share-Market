class Stock {
  final String symbol;
  final String name;
  final double ltp;  // Last traded price
  final double changePercent;
  final double high;
  final double low;
  final double open;
  final int quantity;
  double change;
  final String? changeType;
  final double previousClose; // Add this field

  Stock({
    required this.symbol,
    required this.name,
    required this.ltp,
    required this.changePercent,
    required this.high,
    required this.low,
    required this.open,
    required this.quantity,
    this.change = 0.0,
    this.changeType,
    required this.previousClose, // Add this parameter

  });

  factory Stock.fromJson(Map<String, dynamic> json) {
    double percentChange = _parseDouble(json['percentChange']);
    
    // Calculate change if not provided but ltp and percentChange are available
    double calculatedChange = 0.0;
    if (json['diff'] == null && json['ltp'] != null && json['percentChange'] != null) {
      calculatedChange = _parseDouble(json['ltp']) * percentChange / 100;
    }
    
    return Stock(
      symbol: json['symbol'] ?? '',
      // Handle both name and fullName
      name: json['fullName'] ?? json['name'] ?? '',
      ltp: _parseDouble(json['ltp']),
      changePercent: percentChange,
      high: _parseDouble(json['high']),
      low: _parseDouble(json['low']),
      open: _parseDouble(json['open']),
      quantity: json['quantity'] != null ? int.tryParse(json['quantity'].toString()) ?? 0 : 0,
      change: _parseDouble(json['diff'] ?? json['change'] ?? calculatedChange),
      changeType: json['changeType'] ?? json['direction'],
      previousClose: _parseDouble(json['previousClose'] ?? 0.0),
    );
  }
  
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    if (value is double) return value;
    return 0.0;
  }

  bool get isPositive => changePercent > 0 || (changeType != null && changeType == 'increase');

  String get companyName => name;
  double get lastTradedPrice => ltp;
}