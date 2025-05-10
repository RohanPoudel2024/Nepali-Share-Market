import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// Platform-specific implementation
import 'cookie_manager_native.dart' if (dart.library.html) 'cookie_manager_web.dart' as platform;

class CookieManagerFactory {
  static Future<Interceptor?> createCookieManager() async {
    if (kIsWeb) {
      // For web platforms, return null or a web-compatible solution
      return null;
    } else {
      // For native platforms, use platform-specific implementation
      return await platform.createCookieManager();
    }
  }
}