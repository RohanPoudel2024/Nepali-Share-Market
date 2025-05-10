import 'package:dio/dio.dart';
import 'package:nepse_market_app/api/api_client.dart';
import 'package:nepse_market_app/api/endpoints.dart';
import 'package:nepse_market_app/models/stock.dart';
import 'package:nepse_market_app/utils/map_utils.dart'; // Add this import

class MarketService {
  final ApiClient _apiClient = ApiClient();
  
  Future<List<Stock>> getLiveTrading() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.liveTrading);
      
      // Handle the response based on the format with success and data fields
      if (response.data is Map && response.data['success'] == true && response.data['data'] is List) {
        return (response.data['data'] as List)
            .map((item) => Stock.fromJson(item))
            .toList();
      } else {
        throw Exception('Unexpected live trading data format');
      }
    } on DioException catch (e) {
      throw Exception(e.response?.data['error'] ?? 'Failed to load live trading data');
    } catch (e) {
      throw Exception('Failed to load live trading data: $e');
    }
  }
  
  Future<List<Map<String, dynamic>>> getIndices() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.indices);
      
      // Handle the indices response with success and data fields
      if (response.data is Map && response.data['success'] == true && response.data['data'] is List) {
        return List<Map<String, dynamic>>.from(response.data['data']);
      } else {
        throw Exception('Unexpected indices data format');
      }
    } on DioException catch (e) {
      throw Exception(e.response?.data['error'] ?? 'Failed to load indices');
    } catch (e) {
      throw Exception('Failed to load indices: $e');
    }
  }
  
  // Helper methods to calculate gainers and losers from existing data
  List<Stock> calculateTopGainers(List<Stock> stocks, {int limit = 10}) {
    // Make a copy to avoid modifying the original list
    final stocksCopy = List<Stock>.from(stocks);
    
    // Filter out stocks with no change or negative change
    final gainers = stocksCopy.where((stock) => stock.changePercent > 0).toList();
    
    // Sort by percentage change (descending)
    gainers.sort((a, b) => b.changePercent.compareTo(a.changePercent));
    
    // Return top n gainers
    return gainers.take(limit).toList();
  }

  List<Stock> calculateTopLosers(List<Stock> stocks, {int limit = 10}) {
    // Make a copy to avoid modifying the original list
    final stocksCopy = List<Stock>.from(stocks);
    
    // Filter out stocks with no change or positive change
    final losers = stocksCopy.where((stock) => stock.changePercent < 0).toList();
    
    // Sort by percentage change (ascending)
    losers.sort((a, b) => a.changePercent.compareTo(b.changePercent));
    
    // Return top n losers
    return losers.take(limit).toList();
  }

  // Update the getTopGainers method to use calculateTopGainers
  Future<List<Stock>> getTopGainers({int limit = 10}) async {
    final stocks = await getLiveTrading();
    return calculateTopGainers(stocks, limit: limit);
  }

  // Update the getTopLosers method to use calculateTopLosers
  Future<List<Stock>> getTopLosers({int limit = 10}) async {
    final stocks = await getLiveTrading();
    return calculateTopLosers(stocks, limit: limit);
  }
  
  Future<Stock> getStockBySymbol(String symbol) async {
    try {
      final response = await _apiClient.get('${ApiEndpoints.stockBySymbol}/$symbol');
      if (response.data is Map && response.data['success'] == true && response.data['data'] != null) {
        return Stock.fromJson(response.data['data']);
      } else {
        throw Exception('Unexpected stock data format');
      }
    } on DioException catch (e) {
      throw Exception(e.response?.data['error'] ?? 'Failed to load stock details');
    } catch (e) {
      throw Exception('Failed to load stock details: $e');
    }
  }
  
  Future<Map<String, dynamic>> getCompanyDetails(String symbol) async {
    try {
      final response = await _apiClient.get('${ApiEndpoints.companyDetails}/$symbol');
      
      if (response.data is Map) {
        final Map<String, dynamic> outerData = Map<String, dynamic>.from(response.data);
        
        // Check first level
        if (outerData.containsKey('success') && outerData['success'] == true && outerData.containsKey('data')) {
          final innerData = outerData['data'];
          
          // Check for second level of nesting
          if (innerData is Map && innerData.containsKey('success') && 
              innerData['success'] == true && innerData.containsKey('data')) {
            return Map<String, dynamic>.from(innerData['data']);
          } else if (innerData is Map) {
            // Just one level of nesting
            return Map<String, dynamic>.from(innerData);
          }
        }
        
        return outerData;
      }
      
      throw Exception('Unexpected company details format');
    } catch (e) {
      print('Error fetching company details: $e');
      throw Exception('Failed to load company details: $e');
    }
  }
}