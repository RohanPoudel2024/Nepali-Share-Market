class PaperHolding {
  final String symbol;
  final String companyName;
  double quantity;
  double buyPrice;
  double _currentPrice;
  double _marketValue;
  double _currentValue;

  PaperHolding({
    required this.symbol,
    required this.companyName,
    required this.quantity,
    required this.buyPrice,
    double currentPrice = 0.0,
    double marketValue = 0.0,
    double currentValue = 0.0,
  })  : _currentPrice = currentPrice,
        _marketValue = marketValue,
        _currentValue = currentValue;
        
  // Add getters and setters
  double get currentPrice => _currentPrice;
  set currentPrice(double value) {
    _currentPrice = value;
    // Update marketValue and currentValue when price changes
    _marketValue = quantity * value;
    _currentValue = _marketValue;
  }

  double get marketValue => _marketValue;
  set marketValue(double value) {
    _marketValue = value;
  }

  double get currentValue => _currentValue;
  set currentValue(double value) {
    _currentValue = value;
  }

  // Add an averageBuyPrice getter that returns buyPrice
  double get averageBuyPrice => buyPrice;
  
  double get investmentValue => quantity * averageBuyPrice;
  double get calculatedCurrentValue => quantity * (currentPrice > 0 ? currentPrice : averageBuyPrice);
  
  // Fix profit calculation to use calculatedCurrentValue instead of currentValue
  double get profit => calculatedCurrentValue - investmentValue;

  double get profitPercentage {
    if (investmentValue == 0) return 0;
    // Ensure proper rounding to avoid floating point errors
    return ((profit / investmentValue) * 100).roundToDouble() / 100;
  }

  factory PaperHolding.fromJson(Map<String, dynamic> json) {
    return PaperHolding(
      symbol: json['symbol'],
      companyName: json['company_name'] ?? json['symbol'],
      quantity: _parseDouble(json['quantity']),
      buyPrice: _parseDouble(json['buy_price']),
    );
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