import 'package:flutter/foundation.dart';

/// Centralized cache provider for managing static and live data caching
///
/// This provider implements:
/// - LRU eviction for cache size management
/// - TTL-based expiration for static and live data
/// - Offline mode support
/// - Type-safe cache operations
class CacheProvider extends ChangeNotifier {
  // Static data cache (rivers, runs, stations)
  final Map<String, dynamic> _staticCache = {};
  final Map<String, DateTime> _staticCacheTimestamps = {};
  final Map<String, int> _staticCacheAccessCount = {};

  // Live data cache (water levels, flow rates)
  final Map<String, dynamic> _liveDataCache = {};
  final Map<String, DateTime> _liveDataTimestamps = {};
  final Map<String, int> _liveDataAccessCount = {};

  // Cache timeouts
  static const Duration staticCacheTimeout = Duration(hours: 1);
  static const Duration liveDataCacheTimeout = Duration(minutes: 5);

  // Cache size limits
  static const int maxCacheSize = 1000;
  static const int maxLiveDataCacheSize = 500;

  // Offline mode support
  bool _isOffline = false;
  bool get isOffline => _isOffline;

  // Cache statistics
  int _staticCacheHits = 0;
  int _staticCacheMisses = 0;
  int _liveDataCacheHits = 0;
  int _liveDataCacheMisses = 0;

  /// Get cache hit rate for static data (0.0 to 1.0)
  double get staticCacheHitRate {
    final total = _staticCacheHits + _staticCacheMisses;
    return total == 0 ? 0.0 : _staticCacheHits / total;
  }

  /// Get cache hit rate for live data (0.0 to 1.0)
  double get liveDataCacheHitRate {
    final total = _liveDataCacheHits + _liveDataCacheMisses;
    return total == 0 ? 0.0 : _liveDataCacheHits / total;
  }

  // ========== Static Cache Methods ==========

  /// Get static data from cache
  /// Returns null if key doesn't exist or cache is expired
  T? getStatic<T>(String key) {
    if (!_staticCache.containsKey(key)) {
      _staticCacheMisses++;
      return null;
    }

    if (!isStaticCacheValid(key)) {
      // Cache expired, remove it
      _staticCache.remove(key);
      _staticCacheTimestamps.remove(key);
      _staticCacheAccessCount.remove(key);
      _staticCacheMisses++;
      return null;
    }

    // Update access count for LRU
    _staticCacheAccessCount[key] = (_staticCacheAccessCount[key] ?? 0) + 1;
    _staticCacheHits++;

    return _staticCache[key] as T?;
  }

  /// Set static data in cache
  void setStatic<T>(String key, T data) {
    // Evict oldest items if cache is full
    if (_staticCache.length >= maxCacheSize) {
      _evictOldestStatic();
    }

    _staticCache[key] = data;
    _staticCacheTimestamps[key] = DateTime.now();
    _staticCacheAccessCount[key] = 1;

    notifyListeners();
  }

  /// Check if static cache entry is still valid
  bool isStaticCacheValid(String key) {
    if (!_staticCacheTimestamps.containsKey(key)) return false;

    final timestamp = _staticCacheTimestamps[key]!;
    final age = DateTime.now().difference(timestamp);

    return age < staticCacheTimeout;
  }

  /// Get all keys in static cache
  List<String> getStaticCacheKeys() {
    return _staticCache.keys.toList();
  }

  /// Check if key exists in static cache (regardless of validity)
  bool hasStaticKey(String key) {
    return _staticCache.containsKey(key);
  }

  // ========== Live Data Cache Methods ==========

  /// Get live data from cache
  /// Returns null if key doesn't exist or cache is expired
  T? getLiveData<T>(String key) {
    if (!_liveDataCache.containsKey(key)) {
      _liveDataCacheMisses++;
      return null;
    }

    if (!isLiveDataCacheValid(key)) {
      // Cache expired, remove it
      _liveDataCache.remove(key);
      _liveDataTimestamps.remove(key);
      _liveDataAccessCount.remove(key);
      _liveDataCacheMisses++;
      return null;
    }

    // Update access count for LRU
    _liveDataAccessCount[key] = (_liveDataAccessCount[key] ?? 0) + 1;
    _liveDataCacheHits++;

    return _liveDataCache[key] as T?;
  }

  /// Set live data in cache
  void setLiveData<T>(String key, T data) {
    // Evict oldest items if cache is full
    if (_liveDataCache.length >= maxLiveDataCacheSize) {
      _evictOldestLiveData();
    }

    _liveDataCache[key] = data;
    _liveDataTimestamps[key] = DateTime.now();
    _liveDataAccessCount[key] = 1;

    notifyListeners();
  }

  /// Check if live data cache entry is still valid
  bool isLiveDataCacheValid(String key) {
    if (!_liveDataTimestamps.containsKey(key)) return false;

    final timestamp = _liveDataTimestamps[key]!;
    final age = DateTime.now().difference(timestamp);

    // In offline mode, allow stale data
    if (_isOffline) return true;

    return age < liveDataCacheTimeout;
  }

  /// Get all keys in live data cache
  List<String> getLiveDataCacheKeys() {
    return _liveDataCache.keys.toList();
  }

  /// Check if key exists in live data cache (regardless of validity)
  bool hasLiveDataKey(String key) {
    return _liveDataCache.containsKey(key);
  }

  // ========== Cache Management Methods ==========

  /// Clear all expired cache entries
  int clearExpiredCache() {
    int cleared = 0;

    // Clear expired static cache
    final staticKeysToRemove = <String>[];
    for (final key in _staticCache.keys) {
      if (!isStaticCacheValid(key)) {
        staticKeysToRemove.add(key);
      }
    }
    for (final key in staticKeysToRemove) {
      _staticCache.remove(key);
      _staticCacheTimestamps.remove(key);
      _staticCacheAccessCount.remove(key);
      cleared++;
    }

    // Clear expired live data cache
    final liveDataKeysToRemove = <String>[];
    for (final key in _liveDataCache.keys) {
      if (!isLiveDataCacheValid(key)) {
        liveDataKeysToRemove.add(key);
      }
    }
    for (final key in liveDataKeysToRemove) {
      _liveDataCache.remove(key);
      _liveDataTimestamps.remove(key);
      _liveDataAccessCount.remove(key);
      cleared++;
    }

    if (cleared > 0) {
      notifyListeners();
    }

    return cleared;
  }

  /// Clear all cache (both static and live data)
  void clearAllCache() {
    _staticCache.clear();
    _staticCacheTimestamps.clear();
    _staticCacheAccessCount.clear();
    _liveDataCache.clear();
    _liveDataTimestamps.clear();
    _liveDataAccessCount.clear();

    // Reset statistics
    _staticCacheHits = 0;
    _staticCacheMisses = 0;
    _liveDataCacheHits = 0;
    _liveDataCacheMisses = 0;

    notifyListeners();
  }

  /// Clear only static cache
  void clearStaticCache() {
    _staticCache.clear();
    _staticCacheTimestamps.clear();
    _staticCacheAccessCount.clear();
    notifyListeners();
  }

  /// Clear only live data cache
  void clearLiveDataCache() {
    _liveDataCache.clear();
    _liveDataTimestamps.clear();
    _liveDataAccessCount.clear();
    notifyListeners();
  }

  /// Remove specific key from static cache
  void removeStatic(String key) {
    _staticCache.remove(key);
    _staticCacheTimestamps.remove(key);
    _staticCacheAccessCount.remove(key);
    notifyListeners();
  }

  /// Remove specific key from live data cache
  void removeLiveData(String key) {
    _liveDataCache.remove(key);
    _liveDataTimestamps.remove(key);
    _liveDataAccessCount.remove(key);
    notifyListeners();
  }

  // ========== Offline Mode Methods ==========

  /// Set offline mode
  /// In offline mode, cache never expires and we always use cached data
  void setOfflineMode(bool offline) {
    if (_isOffline != offline) {
      _isOffline = offline;
      notifyListeners();
    }
  }

  // ========== LRU Eviction Methods ==========

  /// Evict oldest (least recently used) item from static cache
  void _evictOldestStatic() {
    if (_staticCache.isEmpty) return;

    // Find key with lowest access count
    String? oldestKey;
    int lowestCount = double.maxFinite.toInt();

    for (final entry in _staticCacheAccessCount.entries) {
      if (entry.value < lowestCount) {
        lowestCount = entry.value;
        oldestKey = entry.key;
      }
    }

    if (oldestKey != null) {
      _staticCache.remove(oldestKey);
      _staticCacheTimestamps.remove(oldestKey);
      _staticCacheAccessCount.remove(oldestKey);
    }
  }

  /// Evict oldest (least recently used) item from live data cache
  void _evictOldestLiveData() {
    if (_liveDataCache.isEmpty) return;

    // Find key with lowest access count
    String? oldestKey;
    int lowestCount = double.maxFinite.toInt();

    for (final entry in _liveDataAccessCount.entries) {
      if (entry.value < lowestCount) {
        lowestCount = entry.value;
        oldestKey = entry.key;
      }
    }

    if (oldestKey != null) {
      _liveDataCache.remove(oldestKey);
      _liveDataTimestamps.remove(oldestKey);
      _liveDataAccessCount.remove(oldestKey);
    }
  }

  // ========== Debug & Statistics Methods ==========

  /// Get cache statistics as a map
  Map<String, dynamic> getStatistics() {
    return {
      'staticCacheSize': _staticCache.length,
      'liveDataCacheSize': _liveDataCache.length,
      'staticCacheHits': _staticCacheHits,
      'staticCacheMisses': _staticCacheMisses,
      'staticCacheHitRate': staticCacheHitRate,
      'liveDataCacheHits': _liveDataCacheHits,
      'liveDataCacheMisses': _liveDataCacheMisses,
      'liveDataCacheHitRate': liveDataCacheHitRate,
      'isOffline': _isOffline,
      'totalMemoryUsage': _estimateMemoryUsage(),
    };
  }

  /// Estimate total memory usage in bytes (rough approximation)
  int _estimateMemoryUsage() {
    // Very rough estimation: 1KB per cache entry on average
    return (_staticCache.length + _liveDataCache.length) * 1024;
  }

  /// Print cache statistics for debugging
  void printStatistics() {
    final stats = getStatistics();
    debugPrint('=== Cache Statistics ===');
    debugPrint('Static Cache: ${stats['staticCacheSize']} items');
    debugPrint('Live Data Cache: ${stats['liveDataCacheSize']} items');
    debugPrint(
      'Static Hit Rate: ${(stats['staticCacheHitRate'] * 100).toStringAsFixed(1)}%',
    );
    debugPrint(
      'Live Data Hit Rate: ${(stats['liveDataCacheHitRate'] * 100).toStringAsFixed(1)}%',
    );
    debugPrint('Offline Mode: ${stats['isOffline']}');
    debugPrint('Memory Usage: ~${stats['totalMemoryUsage'] ~/ 1024}KB');
    debugPrint('=======================');
  }
}
