import 'package:dio/dio.dart';
import 'package:nepse_market_app/models/holding.dart';
import 'package:nepse_market_app/models/portfolio.dart';
import 'package:nepse_market_app/models/transaction.dart' as app_models;
import 'package:nepse_market_app/api/api_client.dart';
import 'package:nepse_market_app/api/endpoints.dart';

class PortfolioService {
  final ApiClient _apiClient = ApiClient();
  
  // Get all portfolios for the user
  Future<List<Portfolio>> getUserPortfolios() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.portfolios);
      
      if (response.data is Map && response.data['success'] == true) {
        final portfolioList = (response.data['data'] as List).map((item) {
          return Portfolio.fromJson(item);
        }).toList();
        
        return portfolioList;
      } else if (response.data is List) {
        // Handle case where API might return direct list without success wrapper
        // Add proper casting for web platform
        return List<Portfolio>.from(
          (response.data as List).map((item) => Portfolio.fromJson(item as Map<String, dynamic>))
        );
      } else {
        // Return empty list instead of throwing
        print('Unexpected portfolio response format: ${response.data}');
        return [];
      }
    } catch (e) {
      print('Error getting portfolios: $e');
      // Return empty list on error instead of throwing
      return [];
    }
  }
  
  // Create a new portfolio
  Future<Portfolio> createPortfolio(String name, String description) async {
    try {
      print('Sending portfolio creation request: name=$name, description=$description');
      final response = await _apiClient.post(
        ApiEndpoints.portfolios,
        data: {
          'name': name,
          'description': description,
        },
      );
      
      print('Portfolio creation response: ${response.data}');
      
      if (response.data is Map && response.data['success'] == true) {
        return Portfolio.fromJson(response.data['data']);
      } else if (response.data is Map) {
        throw Exception('Failed to create portfolio: ${response.data['error'] ?? 'Unknown error'}');
      } else {
        throw Exception('Failed to create portfolio: Invalid response format');
      }
    } catch (e) {
      print('Error creating portfolio: $e');
      rethrow;
    }
  }
  
  // Get portfolio details with holdings
  Future<Portfolio> getPortfolioDetails(int portfolioId) async {
    try {
      final response = await _apiClient.get('${ApiEndpoints.portfolios}/$portfolioId');
      
      if (response.data is Map && response.data['success'] == true) {
        return Portfolio.fromJson(response.data['data']);
      } else if (response.data is Map && response.data['id'] != null) {
        // Direct portfolio response without success wrapper
        return Portfolio.fromJson(response.data);
      } else {
        throw Exception('Failed to load portfolio details');
      }
    } catch (e) {
      print('Error getting portfolio details: $e');
      rethrow;
    }
  }
  
  // Add a new holding to a portfolio
  Future<Holding> addHolding(
    int portfolioId,
    String symbol,
    double quantity,
    double averageBuyPrice,
  ) async {
    try {
      print('Adding holding: portfolioId=$portfolioId, symbol=$symbol, quantity=$quantity, price=$averageBuyPrice');
      
      // Make sure none of these values are null
      if (symbol.isEmpty || quantity <= 0 || averageBuyPrice <= 0) {
        throw Exception('Symbol, quantity, and average buy price are required');
      }
      
      final response = await _apiClient.post(
        '${ApiEndpoints.portfolios}/$portfolioId/holdings',
        data: {
          'symbol': symbol,
          'quantity': quantity,
          'averageBuyPrice': averageBuyPrice,
        },
      );
      
      print('Holding response: ${response.data}');
      
      if (response.data is Map && response.data['success'] == true) {
        return Holding.fromJson(response.data['data']);
      } else {
        throw Exception('Failed to add holding: ${response.data['error'] ?? 'Unknown error'}');
      }
    } catch (e) {
      print('Error adding holding: $e');
      rethrow;
    }
  }
  
  // Update an existing holding
  Future<Holding> updateHolding(
    int holdingId,
    double quantity,
    double price,
    String type,
  ) async {
    try {
      final response = await _apiClient.put(
        '${ApiEndpoints.holdings}/$holdingId',
        data: {
          'quantity': quantity,
          'price': price,
          'type': type,
        },
      );
      
      if (response.data is Map && response.data['success'] == true) {
        return Holding.fromJson(response.data['data']);
      } else {
        throw Exception('Failed to update holding');
      }
    } catch (e) {
      print('Error updating holding: $e');
      rethrow;
    }
  }
  
  // Get transactions for a portfolio
  Future<List<app_models.Transaction>> getTransactions(int portfolioId) async {
    try {
      final response = await _apiClient.get('${ApiEndpoints.portfolios}/$portfolioId/transactions');
      
      if (response.data is Map && response.data['success'] == true) {
        return (response.data['data'] as List).map((item) {
          return app_models.Transaction.fromJson(item);
        }).toList();
      } else {
        return []; // Return empty list if no transactions
      }
    } catch (e) {
      print('Error getting transactions: $e');
      // Return empty list on error instead of throwing
      return [];
    }
  }
  
  // Add a new transaction
  Future<app_models.Transaction> addTransaction(
    int portfolioId,
    String symbol,
    String type,
    double quantity,
    double price,
    DateTime date,
  ) async {
    try {
      print('Adding transaction: portfolioId=$portfolioId, symbol=$symbol, type=$type, quantity=$quantity, price=$price');
      final response = await _apiClient.post(
        '${ApiEndpoints.portfolios}/$portfolioId/transactions',
        data: {
          'symbol': symbol,
          'type': type.toUpperCase(),
          'quantity': quantity,
          'price': price,
          'date': date.toIso8601String(),
        },
      );
      
      print('Transaction response: ${response.data}');
      
      if (response.data is Map && response.data['success'] == true) {
        final responseData = response.data['data'];
        
        // Create a complete transaction object by combining backend data with local data
        Map<String, dynamic> transactionData;
        if (responseData is List && responseData.isNotEmpty) {
          transactionData = Map<String, dynamic>.from(responseData[0]);
        } else if (responseData is Map) {
          transactionData = Map<String, dynamic>.from(responseData);
        } else {
          throw Exception('Unexpected transaction data format');
        }
        
        // Add missing fields required by the Transaction model
        transactionData['portfolioId'] = portfolioId;  // Use the portfolioId passed to this method
        transactionData['symbol'] = symbol;            // Use the symbol passed to this method
        
        return app_models.Transaction.fromJson(transactionData);
      } else {
        throw Exception('Failed to add transaction: ${response.data['error'] ?? 'Unknown error'}');
      }
    } catch (e) {
      print('Error adding transaction: $e');
      rethrow;
    }
  }
}