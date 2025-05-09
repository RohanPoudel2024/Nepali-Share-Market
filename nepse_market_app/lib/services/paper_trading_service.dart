import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:nepse_market_app/api/api_client.dart';
import 'package:nepse_market_app/api/endpoints.dart';
import 'package:nepse_market_app/models/paper_portfolio.dart';
import 'package:nepse_market_app/models/paper_trade.dart';

class PaperTradingService {
  final ApiClient _apiClient = ApiClient();
  final String baseUrl = '${ApiEndpoints.baseUrl}/paper-trading';
  
  // Local storage keys
  static const String _localPortfoliosKey = 'paper_trading_portfolios';
  static const String _localTradesKey = 'paper_trading_trades';
  
  // Get all portfolios with offline support
  Future<List<PaperPortfolio>> getPaperPortfolios() async {
    try {
      final response = await _apiClient.get('$baseUrl/portfolios');
      
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<PaperPortfolio> portfolios = (response.data['data'] as List)
            .map((item) => PaperPortfolio.fromJson(item))
            .toList();
            
        // Save to local storage for offline use
        _savePortfoliosLocally(portfolios);
        
        return portfolios;
      }
      
      throw Exception('Failed to load portfolios');
    } catch (e) {
      print('Error fetching paper portfolios: $e');
      
      // Try to load from local storage
      final localPortfolios = await _getLocalPortfolios();
      if (localPortfolios.isNotEmpty) {
        print('Loaded ${localPortfolios.length} portfolios from local storage');
        return localPortfolios;
      }
      
      // Create default portfolio if nothing in local storage
      final defaultPortfolio = PaperPortfolio(
        id: 1,
        name: "Default Paper Portfolio",
        description: "Trade with NPR 150,000 virtual money without risk!",
        initialBalance: 150000.0,
        currentBalance: 150000.0,
        holdings: [],
        paperTrades: [],
      );
      
      _savePortfoliosLocally([defaultPortfolio]);
      return [defaultPortfolio];
    }
  }
  
  // Save portfolios to local storage
  Future<void> _savePortfoliosLocally(List<PaperPortfolio> portfolios) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonData = jsonEncode(portfolios.map((p) => p.toJson()).toList());
      await prefs.setString(_localPortfoliosKey, jsonData);
    } catch (e) {
      print('Error saving portfolios locally: $e');
    }
  }
  
  // Get portfolios from local storage
  Future<List<PaperPortfolio>> _getLocalPortfolios() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonData = prefs.getString(_localPortfoliosKey);
      
      if (jsonData == null) {
        return [];
      }
      
      final List<dynamic> decoded = jsonDecode(jsonData);
      return decoded.map((json) => PaperPortfolio.fromJson(json)).toList();
    } catch (e) {
      print('Error loading portfolios from local storage: $e');
      return [];
    }
  }
  
  // Get portfolio details with improved error handling
  Future<PaperPortfolio> getPaperPortfolioDetails(int portfolioId) async {
    try {
      print('Fetching portfolio details for ID: $portfolioId');
      final response = await _apiClient.get('$baseUrl/portfolios/$portfolioId');
      
      print('Portfolio details response: ${response.statusCode}');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final portfolioData = response.data['data'];
        print('Portfolio data received: ${portfolioData != null}');
        
        if (portfolioData != null) {
          final portfolio = PaperPortfolio.fromJson(portfolioData);
          return portfolio;
        }
      }
      
      throw Exception('Failed to load portfolio details - invalid response');
    } catch (e) {
      print('Error fetching paper portfolio details: $e');
      
      // Try to get the basic portfolio list first
      try {
        final portfolios = await getPaperPortfolios();
        for (var portfolio in portfolios) {
          if (portfolio.id == portfolioId) {
            // Found the portfolio, but without details
            return portfolio;
          }
        }
        
        // If we can't find the specific portfolio, return the first available or create a new one
        if (portfolios.isNotEmpty) {
          return portfolios.first;
        }
      } catch (innerError) {
        print('Failed to fetch portfolios as fallback: $innerError');
      }
      
      // Last resort - create a default portfolio
      return _createDefaultPortfolio(portfolioId);
    }
  }
  
  // Create new portfolio
  Future<PaperPortfolio> createPaperPortfolio(String name, String? description, double initialBalance) async {
    try {
      final response = await _apiClient.post(
        '$baseUrl/portfolios',
        data: {
          'name': name,
          'description': description,
          'initialBalance': initialBalance
        },
      );
      
      if (response.statusCode == 201 && response.data['success'] == true) {
        return PaperPortfolio.fromJson(response.data['data']);
      }
      
      throw Exception('Failed to create portfolio');
    } catch (e) {
      print('Error creating paper portfolio: $e');
      rethrow;
    }
  }
  
  // Execute paper trade
  Future<bool> executePaperTrade(
    int portfolioId,
    String symbol,
    String type,
    double quantity,
    double price,
  ) async {
    try {
      print('Executing paper trade: portfolioId=$portfolioId, symbol=$symbol, type=$type, quantity=$quantity, price=$price');
      
      final response = await _apiClient.post(
        '$baseUrl/portfolios/$portfolioId/trades',
        data: {
          'symbol': symbol,
          'type': type,
          'quantity': quantity.toString(), // Convert to string to avoid precision issues
          'price': price.toString(), // Convert to string to avoid precision issues
          'companyName': symbol, // Include symbol as company name as fallback
        },
      );
      
      print('Trade API response: ${response.statusCode} - ${response.data}');
      
      if (response.statusCode == 200 && response.data['success'] == true) {
        return true;
      }
      
      // Handle specific balance error
      if (response.statusCode == 400 && 
          response.data['message']?.toString().contains('Invalid balance format') == true) {
        
        print('Detected balance format error, attempting auto-recovery...');
        
        // Try to fix the balance automatically
        final fixResult = await fixPortfolioBalanceAuto(portfolioId);
        
        if (fixResult) {
          // Try the trade again
          print('Auto-recovery successful, retrying trade...');
          
          final retryResponse = await _apiClient.post(
            '$baseUrl/portfolios/$portfolioId/trades',
            data: {
              'symbol': symbol,
              'type': type,
              'quantity': quantity.toString(),
              'price': price.toString(),
              'companyName': symbol,
            },
          );
          
          if (retryResponse.statusCode == 200 && retryResponse.data['success'] == true) {
            return true;
          }
        }
        
        // If we get here, the auto-recovery failed or the retry failed
        throw Exception('Failed to execute trade after balance recovery attempt');
      }
      
      throw Exception(response.data['message'] ?? 'Failed to execute trade');
    } catch (e) {
      print('Error executing paper trade: $e');
      rethrow;
    }
  }
  
  // Add a method to manually fix portfolio balance with a specific value
  Future<bool> fixPortfolioBalance(int portfolioId, double newBalance) async {
    try {
      final response = await _apiClient.post(
        '$baseUrl/portfolios/$portfolioId/reset-balance',
        data: {
          'balance': newBalance.toString(),
        },
      );
      
      return response.statusCode == 200 && response.data['success'] == true;
    } catch (e) {
      print('Error fixing portfolio balance: $e');
      return false;
    }
  }
  
  // Automatically fix portfolio balance by calling the server-side fix endpoint
  Future<bool> fixPortfolioBalanceAuto(int portfolioId) async {
    try {
      print('Attempting to fix balance for portfolio $portfolioId');
      
      final response = await _apiClient.post(
        '$baseUrl/portfolios/$portfolioId/fix-balance',
      );
      
      print('Fix balance response: ${response.statusCode} - ${response.data}');
      
      if (response.statusCode == 200 && response.data['success'] == true) {
        return true;
      }
      
      throw Exception(response.data['message'] ?? 'Failed to fix portfolio balance');
    } catch (e) {
      print('Error fixing portfolio balance: $e');
      rethrow;
    }
  }
  
  // New method to attempt balance recovery
  Future<bool> _attemptBalanceRecovery(int portfolioId) async {
    try {
      print('Attempting balance recovery for portfolio $portfolioId');
      
      // 1. First try to get portfolio details to check if we can get initial balance
      final portfolio = await getPaperPortfolioDetails(portfolioId);
      
      if (portfolio.initialBalance > 0) {
        // 2. Estimate the correct balance based on initial balance and trades
        double estimatedBalance = portfolio.initialBalance;
        
        // Get all trades to calculate balance
        final trades = await getPaperTradeHistory(portfolioId);
        
        // Apply all trades to estimate balance
        for (var trade in trades) {
          if (trade.type.toUpperCase() == 'BUY') {
            estimatedBalance -= trade.totalAmount;
          } else if (trade.type.toUpperCase() == 'SELL') {
            estimatedBalance += trade.totalAmount;
          }
        }
        
        // 3. Reset the portfolio balance via API
        print('Resetting portfolio $portfolioId balance to ${estimatedBalance}');
        final resetResponse = await fixPortfolioBalance(portfolioId, estimatedBalance);
        
        if (resetResponse) {
          print('Balance successfully reset to $estimatedBalance');
          return true;
        } else {
          print('Failed to reset balance');
          return false;
        }
      }
      
      return false;
    } catch (e) {
      print('Error in balance recovery: $e');
      return false;
    }
  }
  
  // Retry trade execution after recovery
  Future<bool> _retryTradeExecution(
    int portfolioId,
    String symbol,
    String type,
    double quantity,
    double price,
  ) async {
    try {
      final response = await _apiClient.post(
        '$baseUrl/portfolios/$portfolioId/trades',
        data: {
          'symbol': symbol,
          'type': type,
          'quantity': quantity.toString(),
          'price': price.toString(),
        },
      );
      
      print('Retry trade API response: ${response.statusCode} - ${response.data}');
      
      if (response.statusCode == 200 && response.data['success'] == true) {
        return true;
      }
      
      throw Exception('Trade retry failed: ${response.data['message'] ?? 'Unknown error'}');
    } catch (e) {
      print('Error in trade retry: $e');
      return false;
    }
  }
  
  // Get paper trade history with improved error handling
  Future<List<PaperTrade>> getPaperTradeHistory(int portfolioId) async {
    try {
      print('Getting trade history for portfolio $portfolioId');
      final response = await _apiClient.get('$baseUrl/portfolios/$portfolioId/trades');
      
      print('Trade history response: ${response.statusCode} - ${response.data}');
      
      if (response.statusCode == 200 && response.data['success'] == true) {
        if (response.data['data'] == null) {
          print('Received null data for trade history');
          return [];
        }
        
        final tradeData = response.data['data'] as List;
        print('Received ${tradeData.length} trades from server');
        
        final List<PaperTrade> trades = tradeData
            .map((item) => PaperTrade.fromJson(item))
            .toList();
        
        return trades;
      }
      
      print('Unexpected response format from server: ${response.data}');
      return []; // Return empty list on unexpected response
    } catch (e) {
      print('Error fetching paper trade history: $e');
      // Return empty list on error
      return [];
    }
  }
  
  // Create a default portfolio locally
  PaperPortfolio _createDefaultPortfolio([int? id]) {
    return PaperPortfolio(
      id: id ?? DateTime.now().millisecondsSinceEpoch,
      name: "Default Paper Portfolio",
      description: "Trade with NPR 150,000 virtual money without risk!",
      initialBalance: 150000.0,
      currentBalance: 150000.0,
      holdings: [],
      paperTrades: [],
    );
  }
}