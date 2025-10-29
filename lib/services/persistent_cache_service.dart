import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent cache service for storing data locally across app sessions
/// Works on all platforms (Web, Android, iOS)
///
/// This service provides:
/// - Persistent storage of cache data (survives app restarts)
/// - Automatic serialization/deserialization
/// - Separate namespaces for static and live data
/// - Cross-platform compatibility
class PersistentCacheService {
  static const String _staticCachePrefix = 'cache_static_';
  static const String _liveDataCachePrefix = 'cache_live_';
  static const String _staticTimestampPrefix = 'cache_static_ts_';
  static const String _liveTimestampPrefix = 'cache_live_ts_';

  /// Save static cache data to local storage
  static Future<void> saveStaticCache(
    Map<String, dynamic> cache,
    Map<String, DateTime> timestamps,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save each cache entry
      for (final entry in cache.entries) {
        final key = _staticCachePrefix + entry.key;
        final value = jsonEncode(entry.value);
        await prefs.setString(key, value);
      }

      // Save timestamps
      for (final entry in timestamps.entries) {
        final key = _staticTimestampPrefix + entry.key;
        await prefs.setString(key, entry.value.toIso8601String());
      }

      if (kDebugMode) {
        print('💾 Saved ${cache.length} static cache entries to local storage');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error saving static cache: $e');
      }
    }
  }

  /// Load static cache data from local storage
  static Future<Map<String, dynamic>> loadStaticCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cache = <String, dynamic>{};

      // Get all keys with our prefix
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith(_staticCachePrefix)) {
          final cacheKey = key.substring(_staticCachePrefix.length);
          final value = prefs.getString(key);
          if (value != null) {
            try {
              cache[cacheKey] = jsonDecode(value);
            } catch (e) {
              // Skip entries that can't be decoded
              if (kDebugMode) {
                print('⚠️ Skipping invalid static cache entry: $cacheKey');
              }
            }
          }
        }
      }

      if (kDebugMode && cache.isNotEmpty) {
        print(
          '📂 Loaded ${cache.length} static cache entries from local storage',
        );
      }

      return cache;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading static cache: $e');
      }
      return {};
    }
  }

  /// Load static cache timestamps from local storage
  static Future<Map<String, DateTime>> loadStaticTimestamps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamps = <String, DateTime>{};

      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith(_staticTimestampPrefix)) {
          final cacheKey = key.substring(_staticTimestampPrefix.length);
          final value = prefs.getString(key);
          if (value != null) {
            try {
              timestamps[cacheKey] = DateTime.parse(value);
            } catch (e) {
              // Skip invalid timestamps
              if (kDebugMode) {
                print('⚠️ Skipping invalid static timestamp: $cacheKey');
              }
            }
          }
        }
      }

      return timestamps;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading static timestamps: $e');
      }
      return {};
    }
  }

  /// Save live data cache to local storage
  static Future<void> saveLiveDataCache(
    Map<String, dynamic> cache,
    Map<String, DateTime> timestamps,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save each cache entry
      for (final entry in cache.entries) {
        final key = _liveDataCachePrefix + entry.key;
        final value = jsonEncode(entry.value);
        await prefs.setString(key, value);
      }

      // Save timestamps
      for (final entry in timestamps.entries) {
        final key = _liveTimestampPrefix + entry.key;
        await prefs.setString(key, entry.value.toIso8601String());
      }

      if (kDebugMode) {
        print(
          '💾 Saved ${cache.length} live data cache entries to local storage',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error saving live data cache: $e');
      }
    }
  }

  /// Load live data cache from local storage
  static Future<Map<String, dynamic>> loadLiveDataCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cache = <String, dynamic>{};

      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith(_liveDataCachePrefix)) {
          final cacheKey = key.substring(_liveDataCachePrefix.length);
          final value = prefs.getString(key);
          if (value != null) {
            try {
              cache[cacheKey] = jsonDecode(value);
            } catch (e) {
              // Skip entries that can't be decoded
              if (kDebugMode) {
                print('⚠️ Skipping invalid live cache entry: $cacheKey');
              }
            }
          }
        }
      }

      if (kDebugMode && cache.isNotEmpty) {
        print(
          '📂 Loaded ${cache.length} live data cache entries from local storage',
        );
      }

      return cache;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading live data cache: $e');
      }
      return {};
    }
  }

  /// Load live data timestamps from local storage
  static Future<Map<String, DateTime>> loadLiveTimestamps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamps = <String, DateTime>{};

      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith(_liveTimestampPrefix)) {
          final cacheKey = key.substring(_liveTimestampPrefix.length);
          final value = prefs.getString(key);
          if (value != null) {
            try {
              timestamps[cacheKey] = DateTime.parse(value);
            } catch (e) {
              // Skip invalid timestamps
              if (kDebugMode) {
                print('⚠️ Skipping invalid live timestamp: $cacheKey');
              }
            }
          }
        }
      }

      return timestamps;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading live timestamps: $e');
      }
      return {};
    }
  }

  /// Clear all cached data from local storage
  static Future<void> clearAllCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      int cleared = 0;
      for (final key in keys) {
        if (key.startsWith(_staticCachePrefix) ||
            key.startsWith(_liveDataCachePrefix) ||
            key.startsWith(_staticTimestampPrefix) ||
            key.startsWith(_liveTimestampPrefix)) {
          await prefs.remove(key);
          cleared++;
        }
      }

      if (kDebugMode) {
        print('🗑️ Cleared $cleared cache entries from local storage');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error clearing cache: $e');
      }
    }
  }

  /// Clear only static cache from local storage
  static Future<void> clearStaticCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      int cleared = 0;
      for (final key in keys) {
        if (key.startsWith(_staticCachePrefix) ||
            key.startsWith(_staticTimestampPrefix)) {
          await prefs.remove(key);
          cleared++;
        }
      }

      if (kDebugMode) {
        print('🗑️ Cleared $cleared static cache entries from local storage');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error clearing static cache: $e');
      }
    }
  }

  /// Clear only live data cache from local storage
  static Future<void> clearLiveDataCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      int cleared = 0;
      for (final key in keys) {
        if (key.startsWith(_liveDataCachePrefix) ||
            key.startsWith(_liveTimestampPrefix)) {
          await prefs.remove(key);
          cleared++;
        }
      }

      if (kDebugMode) {
        print(
          '🗑️ Cleared $cleared live data cache entries from local storage',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error clearing live data cache: $e');
      }
    }
  }

  /// Remove a specific cache entry
  static Future<void> removeEntry(
    String key, {
    required bool isLiveData,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (isLiveData) {
        await prefs.remove(_liveDataCachePrefix + key);
        await prefs.remove(_liveTimestampPrefix + key);
      } else {
        await prefs.remove(_staticCachePrefix + key);
        await prefs.remove(_staticTimestampPrefix + key);
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error removing cache entry: $e');
      }
    }
  }
}
