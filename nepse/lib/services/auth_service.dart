import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nepse_market_app/api/api_client.dart';
import 'package:nepse_market_app/api/endpoints.dart';
import 'package:nepse_market_app/models/user.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final ApiClient _apiClient = ApiClient();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<Map<String, dynamic>> register(
      String name, String email, String password) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.register,
        data: {
          'name': name,
          'email': email,
          'password': password,
        },
      );

      final token = response.data['token'];
      final user = User.fromJson(response.data['user']);

      // Store token
      await _storage.write(key: 'auth_token', value: token);

      return {
        'success': true,
        'user': user,
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['error'] ?? 'Registration failed',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Registration failed: $e',
      };
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.login,
        data: {
          'email': email,
          'password': password,
        },
      );

      final token = response.data['token'];
      final user = User.fromJson(response.data['user']);

      // Store token
      await _storage.write(key: 'auth_token', value: token);

      // For web, set up any additional web-specific authentication if needed
      if (kIsWeb) {
        // The token is already stored and will be sent as a header for future requests
      }

      return {
        'success': true,
        'user': user,
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['error'] ?? 'Login failed',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Login failed: $e',
      };
    }
  }

  Future<Map<String, dynamic>> getCurrentUser() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.me);
      final user = User.fromJson(response.data);

      return {
        'success': true,
        'user': user,
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['error'] ?? 'Failed to get user data',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to get user data: $e',
      };
    }
  }

  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: 'auth_token');
    return token != null;
  }

  Future<void> logout() async {
    try {
      // For web platforms, don't make the network request if we're having connection issues
      if (!kIsWeb) {
        try {
          // Call logout endpoint to clear server-side session
          await _apiClient.post(ApiEndpoints.logout);
        } catch (e) {
          print('Error during server logout: $e');
          // Continue with local logout even if server logout fails
        }
      }
    } catch (e) {
      print('Error during logout: $e');
    } finally {
      // Always clear local storage
      await _storage.delete(key: 'auth_token');
    }
  }

  Future<Map<String, dynamic>> testApiConnection() async {
    try {
      // First try a simple GET to the root endpoint
      print('Testing root connection to: ${ApiEndpoints.baseUrl.replaceAll("/api", "")}');
      
      try {
        final rootResponse = await Dio().get('${ApiEndpoints.baseUrl.replaceAll("/api", "")}');
        print('Root connection successful: ${rootResponse.statusCode}');
      } catch (e) {
        print('Root connection failed, still trying registration endpoint');
      }
      
      // Now try the actual registration endpoint
      print('Testing connection to: ${ApiEndpoints.baseUrl}${ApiEndpoints.register}');
      
      final response = await _apiClient.post(
        ApiEndpoints.register,
        data: {
          'name': 'Connection Test',
          'email': 'test${DateTime.now().millisecondsSinceEpoch}@example.com',
          'password': 'password123',
        },
      );
      
      print('Connection successful: ${response.statusCode}');
      print('Response data: ${response.data}');
      
      return {
        'success': true,
        'message': 'Connected to API successfully'
      };
    } on DioException catch (e) {
      print('Connection error: ${e.message}');
      print('Error type: ${e.type}');
      
      // Check if we got a response despite the error
      if (e.response != null) {
        print('Response status: ${e.response?.statusCode}');
        print('Response data: ${e.response?.data}');
        
        // If we got a 400 error due to validation or existing user
        // that still means the connection works!
        if (e.response!.statusCode == 400) {
          return {
            'success': true,
            'message': 'Connected to API (got validation error: ${e.response!.data["error"]})'
          };
        }
      }
      
      return {
        'success': false,
        'message': 'API connection failed: ${e.message}'
      };
    } catch (e) {
      print('Unexpected error: $e');
      return {
        'success': false,
        'message': 'API connection failed with unexpected error: $e'
      };
    }
  }

  Future<Map<String, dynamic>> updateProfile(String name) async {
    try {
      final response = await _apiClient.put(
        ApiEndpoints.updateProfile,
        data: {
          'name': name,
        },
      );
      
      final user = User.fromJson(response.data['user']);
      
      return {
        'success': true,
        'user': user,
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['error'] ?? 'Failed to update profile',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to update profile: $e',
      };
    }
  }

  Future<Map<String, dynamic>> checkSession() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.session);
      
      if (response.data['isLoggedIn'] && response.data['user'] != null) {
        final user = User.fromJson(response.data['user']);
        return {
          'success': true,
          'user': user,
        };
      } else {
        return {
          'success': false,
          'message': 'Session expired',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to check session: $e',
      };
    }
  }

  Future<bool> testConnection() async {
    try {
      // Test the simple health endpoint first
      final response = await _apiClient.get('/health');
      print('Health check response: ${response.statusCode} - ${response.data}');
      return true;
    } catch (e) {
      print('Health check failed: $e');
      return false;
    }
  }
}