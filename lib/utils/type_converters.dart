/// Shared utility functions for type conversions
///
/// Consolidates duplicate _safeToDouble() methods found throughout the codebase
library;

/// Safely converts a dynamic value to double
///
/// Handles conversion from:
/// - double (returns as-is)
/// - int (converts to double)
/// - String (parses to double)
/// - null (returns null)
/// - Other types (returns null)
///
/// Returns null if conversion fails or value is null
double? safeToDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}

/// Safely converts a dynamic value to int
///
/// Handles conversion from:
/// - int (returns as-is)
/// - double (converts to int)
/// - String (parses to int)
/// - null (returns null)
/// - Other types (returns null)
///
/// Returns null if conversion fails or value is null
int? safeToInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

/// Safely converts a dynamic value to String
///
/// Handles conversion from:
/// - String (returns as-is)
/// - num (converts to string)
/// - bool (converts to string)
/// - null (returns null)
/// - Other types (calls toString())
///
/// Returns null if value is null
String? safeToString(dynamic value) {
  if (value == null) return null;
  if (value is String) return value;
  return value.toString();
}

/// Safely converts a dynamic value to bool
///
/// Handles conversion from:
/// - bool (returns as-is)
/// - int (0 = false, non-zero = true)
/// - String ('true', '1', 'yes' = true, case insensitive)
/// - null (returns null)
/// - Other types (returns null)
///
/// Returns null if conversion fails or value is null
bool? safeToBool(dynamic value) {
  if (value == null) return null;
  if (value is bool) return value;
  if (value is int) return value != 0;
  if (value is String) {
    final lower = value.toLowerCase().trim();
    if (lower == 'true' || lower == '1' || lower == 'yes') return true;
    if (lower == 'false' || lower == '0' || lower == 'no') return false;
  }
  return null;
}

/// Safely converts a timestamp to DateTime
///
/// Handles conversion from:
/// - DateTime (returns as-is)
/// - int (milliseconds since epoch)
/// - String (ISO8601 format)
/// - null (returns null)
/// - Other types (returns null)
///
/// Returns null if conversion fails or value is null
DateTime? safeToDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is int) {
    try {
      return DateTime.fromMillisecondsSinceEpoch(value);
    } catch (_) {
      return null;
    }
  }
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}

/// Safely converts a value to List<T>
///
/// Handles conversion from:
/// - List (returns as-is, casting if needed)
/// - null (returns null)
/// - Other types (returns null)
///
/// Returns null if value is null or not a List
List<T>? safeToList<T>(dynamic value) {
  if (value == null) return null;
  if (value is List<T>) return value;
  if (value is List) {
    try {
      return value.cast<T>();
    } catch (_) {
      return null;
    }
  }
  return null;
}

/// Safely converts a value to Map<K, V>
///
/// Handles conversion from:
/// - Map (returns as-is, casting if needed)
/// - null (returns null)
/// - Other types (returns null)
///
/// Returns null if value is null or not a Map
Map<K, V>? safeToMap<K, V>(dynamic value) {
  if (value == null) return null;
  if (value is Map<K, V>) return value;
  if (value is Map) {
    try {
      return value.cast<K, V>();
    } catch (_) {
      return null;
    }
  }
  return null;
}
