class PaperTrade {
  final int id;
  final String symbol;
  final double quantity;
  final double buyPrice;
  double currentPrice;
  final String type;  // 'buy' or 'sell'
  final DateTime timestamp;
  
  PaperTrade({
    required this.id,
    required this.symbol,
    required this.quantity,
    required this.buyPrice,
    required this.currentPrice,
    required this.type,
    required this.timestamp,
  });
  
  // Calculate profit/loss
  double get profitLoss {
    if (type.toLowerCase() == 'buy') {
      return (currentPrice - buyPrice) * quantity;
    } else {
      return (buyPrice - currentPrice) * quantity;
    }
  }
  
  // Calculate profit/loss percentage
  double get profitLossPercentage {
    if (buyPrice == 0) return 0;
    return (profitLoss / (buyPrice * quantity)) * 100;
  }
  
  // Convert to json
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'symbol': symbol,
      'quantity': quantity,
      'buyPrice': buyPrice,
      'currentPrice': currentPrice,
      'type': type,
      'timestamp': timestamp.toIso8601String(),
    };
  }
  
  // Create from json
  factory PaperTrade.fromJson(Map<String, dynamic> json) {
    return PaperTrade(
      id: json['id'],
      symbol: json['symbol'],
      quantity: json['quantity'],
      buyPrice: json['buyPrice'],
      currentPrice: json['currentPrice'],
      type: json['type'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}
