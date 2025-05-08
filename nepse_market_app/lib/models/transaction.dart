import 'package:intl/intl.dart';

class Transaction {
  final int id;
  final int portfolioId;
  final String symbol;
  final String type; // Buy, Sell, Dividend, etc.
  final double quantity;
  final double price;
  final DateTime date;

  Transaction({
    required this.id,
    required this.portfolioId,
    required this.symbol,
    required this.type,
    required this.quantity,
    required this.price,
    required this.date,
  });

  // Total value of this transaction
  double get totalValue => quantity * price;

  // Ensure the fromJson method uses standard JSON parsing:
  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      portfolioId: json['portfolioId'] is int ? json['portfolioId'] : int.parse(json['portfolioId'].toString()),
      symbol: json['symbol'],
      type: json['type'],
      quantity: json['quantity']?.toDouble() ?? 0.0,
      price: json['price']?.toDouble() ?? 0.0,
      date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
    );
  }
}