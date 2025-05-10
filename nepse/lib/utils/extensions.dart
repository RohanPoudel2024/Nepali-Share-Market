// Add the import for MapUtils
import 'package:nepse_market_app/utils/map_utils.dart';

extension SafeMapAccess on Map {
  /// Gets a value from a map with the specified key, with safe type casting
  /// Returns the default value if the key is not found or the value has wrong type
  T? getValue<T>(String key, [T? defaultValue]) {
    final value = this[key];
    
    if (value == null) {
      return defaultValue;
    }
    
    if (value is T) {
      return value;
    }
    
    // Try to convert numeric types
    if (T == double && value is num) {
      return value.toDouble() as T;
    }
    
    if (T == int && value is num) {
      return value.toInt() as T;
    }
    
    // Try string conversion for simple types
    if (T == String) {
      return value.toString() as T;
    }
    
    return defaultValue;
  }
  
  /// Gets a nested map with proper type conversion
  Map<String, dynamic> getNestedMap(String key) {
    final value = this[key];
    
    if (value == null) {
      return {};
    }
    
    if (value is Map) {
      return MapUtils.toStringDynamicMap(value);
    }
    
    return {};
  }
}