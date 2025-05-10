class ApiEndpoints {
  // Using static field to allow hot reload changes
  static String baseUrl = 'http://localhost:9090/api';

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

  // Portfolio endpoints - change from "portfolios" to "portfolio" to match backend
  static String get portfolios => '$baseUrl/portfolio'; // Changed from portfolios
  static String get portfolioDetails => '$baseUrl/portfolio'; // + /{id}
  static String get holdings => '$baseUrl/portfolio'; // + /{portfolioId}/holdings
  static String get updateHolding => '$baseUrl/portfolio/holdings'; // + /{holdingId}

  // Method to update port at runtime for testing
  static void updatePort(String port) {
    baseUrl = 'http://localhost:$port/api';
  }
  
  // Method to update the entire base URL
  static void updateBaseUrl(String newBaseUrl) {
    baseUrl = newBaseUrl;
  }
}
