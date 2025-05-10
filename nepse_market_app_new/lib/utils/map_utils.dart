class MapUtils {
  /// Safely converts any Map to a Map<String, dynamic>
  static Map<String, dynamic> toStringDynamicMap(Map sourceMap) {
    final Map<String, dynamic> result = {};
    sourceMap.forEach((key, value) {
      // Convert keys to strings
      final String stringKey = key.toString();
      
      // Handle nested maps recursively
      if (value is Map) {
        result[stringKey] = toStringDynamicMap(value);
      } else if (value is List) {
        result[stringKey] = _convertList(value);
      } else {
        result[stringKey] = value;
      }
    });
    return result;
  }
  
  /// Helper to convert lists that might contain maps
  static List _convertList(List sourceList) {
    return sourceList.map((item) {
      if (item is Map) {
        return toStringDynamicMap(item);
      } else if (item is List) {
        return _convertList(item);
      }
      return item;
    }).toList();
  }
}

// // When processing data:
// if (data is Map) {
//   final convertedData = MapUtils.toStringDynamicMap(data);
//   // Use convertedData safely
// }