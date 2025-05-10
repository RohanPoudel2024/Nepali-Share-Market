import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'cookie_manager_factory.dart';

class ApiClient {
  late Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: dotenv.env['API_BASE_URL'] ?? 'http://localhost:9090',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      validateStatus: (status) => status! < 500,
    ));
    
    _setupInterceptors();
    _setupCookies();

    // Add logging interceptor
    _dio.interceptors.add(LogInterceptor(
      request: kDebugMode,
      requestHeader: kDebugMode,
      requestBody: kDebugMode,
      responseHeader: kDebugMode,
      responseBody: kDebugMode,
      error: true,
    ));

    // Add retry interceptor for connection issues
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException e, ErrorInterceptorHandler handler) async {
          if (e.type == DioExceptionType.connectionError) {
            // Try with fallback URL if main URL fails
            if (e.requestOptions.path.contains('localhost')) {
              try {
                // Replace localhost with 127.0.0.1
                final newPath = e.requestOptions.path.replaceAll('localhost', '127.0.0.1');
                print('Retrying with fallback URL: $newPath');
                
                final response = await _dio.request(
                  newPath,
                  data: e.requestOptions.data,
                  queryParameters: e.requestOptions.queryParameters,
                  options: Options(
                    method: e.requestOptions.method,
                    headers: e.requestOptions.headers,
                  ),
                );
                
                return handler.resolve(response);
              } catch (retryError) {
                // If retry also fails, continue with original error
                print('Retry also failed: $retryError');
              }
            }
          }
          return handler.next(e);
        },
      ),
    );
  }
  
  Future<void> _setupCookies() async {
    try {
      // Set up Dio to properly handle cookies
      if (kIsWeb) {
        // For web, need to use withCredentials
        _dio.options.extra['withCredentials'] = true;
      } else {
        // For mobile, use cookie manager
        final cookieManager = await CookieManagerFactory.createCookieManager();
        if (cookieManager != null) {
          _dio.interceptors.add(cookieManager);
        }
      }
    } catch (e) {
      print('Error setting up cookies: $e');
    }
  }
  
  void _setupInterceptors() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        try {
          final token = await _storage.read(key: 'auth_token');
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          
          // If web, enable CORS with credentials
          if (kIsWeb) {
            options.extra['withCredentials'] = true;
          }
        } catch (e) {
          print('Error reading auth token: $e');
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        if (e.response?.statusCode == 401) {
          try {
            await _storage.delete(key: 'auth_token');
          } catch (storageError) {
            print('Error clearing auth token: $storageError');
          }
        }
        return handler.next(e);
      },
    ));
  }

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      return await _dio.get(path, queryParameters: queryParameters);
    } catch (e) {
      if (kIsWeb && e is DioException && e.type == DioExceptionType.connectionError) {
        print('Web connection error - possibly CORS related: $e');
      }
      print('GET request error for $path: $e');
      rethrow;
    }
  }
  
  Future<Response> post(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
    try {
      return await _dio.post(path, data: data, queryParameters: queryParameters);
    } catch (e) {
      if (kIsWeb && e is DioException && e.type == DioExceptionType.connectionError) {
        print('Web connection error during POST - possibly CORS related: $e');
      }
      print('POST request error for $path: $e');
      rethrow;
    }
  }

  Future<Response> put(String path, {dynamic data}) async {
    try {
      return await _dio.put(path, data: data);
    } catch (e) {
      if (kIsWeb && e is DioException && e.type == DioExceptionType.connectionError) {
        print('Web connection error during PUT - possibly CORS related: $e');
      }
      rethrow;
    }
  }
}