import 'package:dio/dio.dart';

class ApiTester {
  static Future<Map<String, dynamic>> testBackendConnection(String baseUrl) async {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ));
    
    try {
      print('Testing direct connection to: $baseUrl');
      final response = await dio.get('$baseUrl/health'); // Create a simple health endpoint
      
      return {
        'success': true,
        'status': response.statusCode,
        'message': 'Connected to backend successfully',
      };
    } catch (e) {
      String errorDetails = 'Unknown error';
      if (e is DioException) {
        errorDetails = 'Type: ${e.type}, Message: ${e.message}';
      } else {
        errorDetails = e.toString();
      }
      
      return {
        'success': false,
        'message': 'Connection failed: $errorDetails',
      };
    }
  }
}