import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiEndpoints {
  // Using static field to allow hot reload changes
  static String baseUrl = _getBaseUrl();

  // Add this method to determine the appropriate base URL
  static String _getBaseUrl() {
    // For web, use localhost
    if (kIsWeb) {
      return 'http://localhost:9090/api';
    }
    // For Android emulator, use the special IP
    else if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:9090/api';
    }
    // For other platforms, use localhost
    else {
      return 'http://localhost:9090/api';
    }
  }

  // Auth endpoints
  static String get login => '$baseUrl/auth/login';
  static String get register => '$baseUrl/auth/register';
  static String get logout => '$baseUrl/auth/logout';
  static String get session => '$baseUrl/auth/session';
  static String get me => '$baseUrl/auth/me';
  static String get updateProfile => '$baseUrl/auth/update-profile';

  // Market data endpoints
  static String get gainers => '$baseUrl/market/gainers';
  static String get liveTrading => '$baseUrl/market/live-trading';
  static String get indices => '$baseUrl/market/indices';
  static String get stockBySymbol => '$baseUrl/market/stock'; // + /{symbol}
  static String get companyDetails => '$baseUrl/market/company'; // + /{symbol}
  static String get liveMarket => '$baseUrl/market/live';
  static String get marketSummary => '$baseUrl/market/summary';
  static final String stockHistory = '$baseUrl/market/history';

  // Portfolio endpoints - change from "portfolios" to "portfolio" to match backend
  static String get portfolios => '$baseUrl/portfolio'; // Changed from portfolios
  static String get portfolioDetails => '$baseUrl/portfolio'; // + /{id}
  static String get holdings => '$baseUrl/portfolio'; // + /{portfolioId}/holdings
  static String get updateHolding => '$baseUrl/portfolio/holdings'; // + /{holdingId}

  // Method to update port at runtime for testing
  static void updatePort(String port) {
    baseUrl = 'http://localhost:$port/api';
  }

  // Update this method to respect the platform too
  static void updateBaseUrl(String newBaseUrl) {
    baseUrl = newBaseUrl;
  }
}