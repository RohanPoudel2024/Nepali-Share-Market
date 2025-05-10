import 'package:nepse_market_app/models/holding.dart';

class Portfolio {
  final int id;
  final String name;
  final String? description;
  final List<Holding>? holdings;
  final double? totalValue;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Add this field and initialize it in the constructor and fromJson
  final double? totalInvestmentSummary;

  // Additional metrics - with proper null safety
  double get totalInvestment {
    if (holdings == null || holdings!.isEmpty) return 0.0;
    
    double total = 0.0;
    for (var holding in holdings!) {
      if (holding.isActive) {
        total += holding.investmentValue;
      }
    }
    return total;
  }

  double get totalCurrentValue {
    if (holdings == null || holdings!.isEmpty) return 0.0;
    
    double total = 0.0;
    for (var holding in holdings!) {
      if (holding.isActive) {
        total += holding.currentValue;
      }
    }
    return total;
  }

  double get totalProfit => totalCurrentValue - totalInvestment;

  double get profitPercentage =>
      totalInvestment > 0 ? (totalProfit / totalInvestment * 100) : 0.0;

  double get todaysProfitLoss {
    if (holdings == null || holdings!.isEmpty) return 0.0;
    return holdings!.fold(
        0.0,
        (sum, holding) =>
            sum + (holding.quantity * (holding.todayChange ?? 0.0)));
  }

  Portfolio({
    required this.id,
    required this.name,
    this.description,
    this.holdings,
    this.totalValue,
    this.createdAt,
    this.updatedAt,
    this.totalInvestmentSummary,
  });

  factory Portfolio.fromJson(Map<String, dynamic> json) {
    List<Holding>? holdingsList;
    
    if (json['holdings'] != null) {
      try {
        holdingsList = (json['holdings'] as List)
            .map((h) => Holding.fromJson(h as Map<String, dynamic>))
            .toList();
        print('Parsed ${holdingsList.length} holdings successfully');
      } catch (e) {
        print('Error parsing holdings: $e');
        holdingsList = [];
      }
    } else {
      print('No holdings found in portfolio JSON');
    }

    // Parse summary fields if available
    double? totalInvestmentSummary;
    if (json['totalInvestment'] != null) {
      totalInvestmentSummary = double.tryParse(json['totalInvestment'].toString());
    }

    return Portfolio(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      name: json['name'] ?? 'Unnamed Portfolio',
      description: json['description'],
      holdings: holdingsList,
      totalValue: json['totalValue'] != null
          ? double.parse(json['totalValue'].toString())
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : (json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : null),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : (json['updated_at'] != null
              ? DateTime.parse(json['updated_at'])
              : null),
      totalInvestmentSummary: totalInvestmentSummary,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'holdings': holdings?.map((h) => h.toJson()).toList(),
        'totalValue': totalValue,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };
}
