import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/historical_water_data_service.dart';

/// Provider for historical water data
/// Manages fetching and caching of historical water data from Government of Canada API
/// Includes persistent storage across app sessions
class HistoricalWaterDataProvider extends ChangeNotifier {
  // Cache for combined timeline data per station
  final Map<String, Map<String, dynamic>> _combinedTimelineCache = {};
  final Map<String, DateTime> _combinedTimelineCacheTime = {};

  // Cache for historical data queries
  final Map<String, List<Map<String, dynamic>>> _historicalDataCache = {};
  final Map<String, DateTime> _historicalDataCacheTime = {};

  // Cache for recent trend data
  final Map<String, Map<String, dynamic>> _recentTrendCache = {};
  final Map<String, DateTime> _recentTrendCacheTime = {};

  // Loading states per station
  final Map<String, bool> _loadingStates = {};
  final Map<String, String?> _errors = {};

  // Initialization state
  bool _isInitialized = false;

  // Cache timeouts
  static const Duration _combinedTimelineCacheDuration = Duration(minutes: 5);
  static const Duration _historicalDataCacheDuration = Duration(minutes: 15);
  static const Duration _recentTrendCacheDuration = Duration(minutes: 5);

  // Persistent storage keys
  static const String _prefixCombined = 'hist_combined_';
  static const String _prefixCombinedTime = 'hist_combined_time_';

  HistoricalWaterDataProvider() {
    _initializeCache();
  }

  /// Initialize cache by loading from persistent storage
  Future<void> _initializeCache() async {
    if (_isInitialized) {
      if (kDebugMode) {
        print('✅ HistoricalWaterDataProvider: Already initialized');
      }
      return;
    }

    try {
      if (kDebugMode) {
        print('🔄 HistoricalWaterDataProvider: Loading cache from storage...');
      }

      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      if (kDebugMode) {
        print('🔍 Found ${keys.length} total SharedPreferences keys');
      }

      // Load combined timeline cache
      int combinedCount = 0;
      int timeCount = 0;

      for (final key in keys) {
        if (key.startsWith(_prefixCombined) && !key.contains('time_')) {
          final cacheKey = key.substring(_prefixCombined.length);
          final value = prefs.getString(key);
          if (value != null) {
            try {
              _combinedTimelineCache[cacheKey] =
                  jsonDecode(value) as Map<String, dynamic>;
              combinedCount++;

              if (kDebugMode) {
                print('💾   Loaded cache: $cacheKey (${value.length} bytes)');
              }
            } catch (e) {
              if (kDebugMode) {
                print('⚠️ Skipping invalid cache entry: $cacheKey - $e');
              }
            }
          }
        } else if (key.startsWith(_prefixCombinedTime)) {
          final cacheKey = key.substring(_prefixCombinedTime.length);
          final value = prefs.getString(key);
          if (value != null) {
            try {
              _combinedTimelineCacheTime[cacheKey] = DateTime.parse(value);
              timeCount++;

              if (kDebugMode) {
                print('💾   Loaded timestamp: $cacheKey = $value');
              }
            } catch (e) {
              if (kDebugMode) {
                print('⚠️ Skipping invalid timestamp: $cacheKey - $e');
              }
            }
          }
        }
      }

      if (kDebugMode) {
        print(
          '✅ HistoricalWaterDataProvider: Loaded $combinedCount cache entries, $timeCount timestamps',
        );
      }

      _isInitialized = true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing historical cache: $e');
      }
      _isInitialized = true; // Don't block app on cache error
    }
  }

  /// Ensure cache is initialized
  Future<void> ensureInitialized() async {
    if (!_isInitialized) {
      await _initializeCache();
    }
  }

  /// Save cache to persistent storage
  Future<void> _saveToStorage() async {
    try {
      if (kDebugMode) {
        print('💾 HistoricalWaterDataProvider: Starting save to storage...');
      }

      final prefs = await SharedPreferences.getInstance();

      // Save combined timeline cache
      for (final entry in _combinedTimelineCache.entries) {
        final key = _prefixCombined + entry.key;
        final value = jsonEncode(entry.value);
        await prefs.setString(key, value);

        if (kDebugMode) {
          print('💾   Saved cache entry: $key (${value.length} bytes)');
        }
      }

      // Save combined timeline timestamps
      for (final entry in _combinedTimelineCacheTime.entries) {
        final key = _prefixCombinedTime + entry.key;
        final value = entry.value.toIso8601String();
        await prefs.setString(key, value);

        if (kDebugMode) {
          print('💾   Saved timestamp: $key = $value');
        }
      }

      if (kDebugMode) {
        print(
          '✅ Saved ${_combinedTimelineCache.length} historical cache entries to storage',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error saving historical cache: $e');
      }
    }
  }

  /// Check if a station is currently loading
  bool isLoading(String stationId) => _loadingStates[stationId] ?? false;

  /// Get error for a station
  String? getError(String stationId) => _errors[stationId];

  /// Fetch combined timeline data (historical + realtime)
  /// [stationId] - Station to fetch data for
  /// [forceRefresh] - Bypass cache and fetch fresh data
  /// [includeRealtimeData] - Whether to include real-time data in the timeline
  ///
  /// Implements stale-while-revalidate pattern:
  /// - Returns stale cache immediately if available
  /// - Triggers background refresh if cache is stale
  /// - Only blocks if no cache exists
  Future<Map<String, dynamic>> getCombinedTimeline(
    String stationId, {
    bool forceRefresh = false,
    bool includeRealtimeData = true,
  }) async {
    // Ensure cache is loaded from storage
    await ensureInitialized();

    final cacheKey = '${stationId}_realtime_$includeRealtimeData';

    // Check cache - stale-while-revalidate pattern
    if (!forceRefresh) {
      final cached = _combinedTimelineCache[cacheKey];
      final cacheTime = _combinedTimelineCacheTime[cacheKey];

      if (cached != null && cacheTime != null) {
        final age = DateTime.now().difference(cacheTime);
        if (age < _combinedTimelineCacheDuration) {
          // Cache is fresh
          if (kDebugMode) {
            print(
              '💾 HistoricalWaterDataProvider: Cache hit for combined timeline $cacheKey',
            );
          }
          return cached;
        } else {
          // Cache is stale - return it but refresh in background
          if (kDebugMode) {
            print(
              '💾 HistoricalWaterDataProvider: Using stale cache for $cacheKey (${age.inMinutes}min old), refreshing...',
            );
          }
          _refreshCombinedTimelineInBackground(
            stationId,
            includeRealtimeData: includeRealtimeData,
          );
          return cached;
        }
      }
    }

    // No cache - blocking fetch

    try {
      if (kDebugMode) {
        print(
          '🌐 HistoricalWaterDataProvider: Fetching combined timeline for $stationId',
        );
      }

      final result = await HistoricalWaterDataService.getCombinedTimeline(
        stationId,
        includeRealtimeData: includeRealtimeData,
      );

      if (kDebugMode) {
        print(
          '✅ HistoricalWaterDataProvider: Got combined timeline, caching with key: $cacheKey',
        );
      }

      // Cache the result in memory
      _combinedTimelineCache[cacheKey] = result;
      _combinedTimelineCacheTime[cacheKey] = DateTime.now();

      // Save to persistent storage (AWAIT to ensure it completes)
      await _saveToStorage();

      return result;
    } catch (e) {
      if (kDebugMode) {
        print(
          '❌ HistoricalWaterDataProvider: Error fetching combined timeline: $e',
        );
      }

      rethrow;
    }
  }

  /// Fetch historical data for a specific station and date range
  /// [stationId] - Station to fetch data for
  /// [startDate] - Start date for data range (optional)
  /// [endDate] - End date for data range (defaults to December 31, 2024)
  /// [daysBack] - Number of days back from endDate (defaults to 365)
  /// [year] - Specific year to fetch data for (e.g., 2024)
  /// [forceRefresh] - Bypass cache and fetch fresh data
  ///
  /// Implements stale-while-revalidate pattern:
  /// - Returns stale cache immediately if available
  /// - Triggers background refresh if cache is stale
  /// - Only blocks if no cache exists
  Future<List<Map<String, dynamic>>> fetchHistoricalData(
    String stationId, {
    DateTime? startDate,
    DateTime? endDate,
    int? daysBack,
    int? year,
    bool forceRefresh = false,
  }) async {
    // Ensure cache is loaded from storage
    await ensureInitialized();

    final cacheKey =
        '${stationId}_${startDate?.millisecondsSinceEpoch}_${endDate?.millisecondsSinceEpoch}_${daysBack}_$year';

    // Check cache - stale-while-revalidate pattern
    if (!forceRefresh) {
      final cached = _historicalDataCache[cacheKey];
      final cacheTime = _historicalDataCacheTime[cacheKey];

      if (cached != null && cacheTime != null) {
        final age = DateTime.now().difference(cacheTime);
        if (age < _historicalDataCacheDuration) {
          // Cache is fresh
          if (kDebugMode) {
            print(
              '💾 HistoricalWaterDataProvider: Cache hit for historical data $cacheKey',
            );
          }
          return cached;
        } else {
          // Cache is stale - return it but refresh in background
          if (kDebugMode) {
            print(
              '💾 HistoricalWaterDataProvider: Using stale cache for $cacheKey (${age.inMinutes}min old), refreshing...',
            );
          }
          _refreshHistoricalDataInBackground(
            stationId,
            cacheKey: cacheKey,
            startDate: startDate,
            endDate: endDate,
            daysBack: daysBack,
            year: year,
          );
          return cached;
        }
      }
    }

    // No cache - blocking fetch

    try {
      if (kDebugMode) {
        print(
          '🌐 HistoricalWaterDataProvider: Fetching historical data for $stationId',
        );
      }

      final result = await HistoricalWaterDataService.fetchHistoricalData(
        stationId,
        startDate: startDate,
        endDate: endDate,
        daysBack: daysBack,
        year: year,
      );

      // Cache the result
      _historicalDataCache[cacheKey] = result;
      _historicalDataCacheTime[cacheKey] = DateTime.now();

      return result;
    } catch (e) {
      if (kDebugMode) {
        print(
          '❌ HistoricalWaterDataProvider: Error fetching historical data: $e',
        );
      }

      rethrow;
    }
  }

  /// Get recent trend data for a station
  /// [stationId] - Station to fetch data for
  /// [recentDays] - Number of recent days to analyze (default: 7)
  /// [historicalDays] - Number of historical days for comparison (default: 30)
  /// [forceRefresh] - Bypass cache and fetch fresh data
  ///
  /// Implements stale-while-revalidate pattern:
  /// - Returns stale cache immediately if available
  /// - Triggers background refresh if cache is stale
  /// - Only blocks if no cache exists
  Future<Map<String, dynamic>> getRecentTrend(
    String stationId, {
    int recentDays = 7,
    int historicalDays = 30,
    bool forceRefresh = false,
  }) async {
    // Ensure cache is loaded from storage
    await ensureInitialized();

    final cacheKey = '${stationId}_trend_${recentDays}_$historicalDays';

    // Check cache - stale-while-revalidate pattern
    if (!forceRefresh) {
      final cached = _recentTrendCache[cacheKey];
      final cacheTime = _recentTrendCacheTime[cacheKey];

      if (cached != null && cacheTime != null) {
        final age = DateTime.now().difference(cacheTime);
        if (age < _recentTrendCacheDuration) {
          // Cache is fresh
          if (kDebugMode) {
            print(
              '💾 HistoricalWaterDataProvider: Cache hit for recent trend $cacheKey',
            );
          }
          return cached;
        } else {
          // Cache is stale - return it but refresh in background
          if (kDebugMode) {
            print(
              '💾 HistoricalWaterDataProvider: Using stale cache for $cacheKey (${age.inMinutes}min old), refreshing...',
            );
          }
          _refreshRecentTrendInBackground(
            stationId,
            cacheKey: cacheKey,
            recentDays: recentDays,
            historicalDays: historicalDays,
          );
          return cached;
        }
      }
    }

    // No cache - blocking fetch

    try {
      if (kDebugMode) {
        print(
          '🌐 HistoricalWaterDataProvider: Fetching recent trend for $stationId',
        );
      }

      final result = await HistoricalWaterDataService.getRecentTrend(
        stationId,
        recentDays: recentDays,
        historicalDays: historicalDays,
      );

      // Cache the result
      _recentTrendCache[cacheKey] = result;
      _recentTrendCacheTime[cacheKey] = DateTime.now();

      return result;
    } catch (e) {
      if (kDebugMode) {
        print('❌ HistoricalWaterDataProvider: Error fetching recent trend: $e');
      }

      rethrow;
    }
  }

  /// Background refresh for combined timeline (stale-while-revalidate pattern)
  Future<void> _refreshCombinedTimelineInBackground(
    String stationId, {
    required bool includeRealtimeData,
  }) async {
    final cacheKey = '${stationId}_realtime_$includeRealtimeData';

    try {
      if (kDebugMode) {
        print(
          '🔄 HistoricalWaterDataProvider: Background refresh for $cacheKey',
        );
      }

      final result = await HistoricalWaterDataService.getCombinedTimeline(
        stationId,
        includeRealtimeData: includeRealtimeData,
      );

      // Update cache
      _combinedTimelineCache[cacheKey] = result;
      _combinedTimelineCacheTime[cacheKey] = DateTime.now();

      // Save to persistent storage
      await _saveToStorage();

      if (kDebugMode) {
        print(
          '✅ HistoricalWaterDataProvider: Background refresh completed for $cacheKey',
        );
      }

      notifyListeners(); // Update UI with fresh data
    } catch (e) {
      // Silent failure - keep using stale data
      if (kDebugMode) {
        print(
          '❌ HistoricalWaterDataProvider: Background refresh failed for $cacheKey: $e',
        );
      }
    }
  }

  /// Background refresh for historical data (stale-while-revalidate pattern)
  Future<void> _refreshHistoricalDataInBackground(
    String stationId, {
    required String cacheKey,
    DateTime? startDate,
    DateTime? endDate,
    int? daysBack,
    int? year,
  }) async {
    try {
      if (kDebugMode) {
        print(
          '🔄 HistoricalWaterDataProvider: Background refresh for historical data $cacheKey',
        );
      }

      final result = await HistoricalWaterDataService.fetchHistoricalData(
        stationId,
        startDate: startDate,
        endDate: endDate,
        daysBack: daysBack,
        year: year,
      );

      // Update cache
      _historicalDataCache[cacheKey] = result;
      _historicalDataCacheTime[cacheKey] = DateTime.now();

      if (kDebugMode) {
        print(
          '✅ HistoricalWaterDataProvider: Background refresh completed for $cacheKey',
        );
      }

      notifyListeners(); // Update UI with fresh data
    } catch (e) {
      // Silent failure - keep using stale data
      if (kDebugMode) {
        print(
          '❌ HistoricalWaterDataProvider: Background refresh failed for $cacheKey: $e',
        );
      }
    }
  }

  /// Background refresh for recent trend (stale-while-revalidate pattern)
  Future<void> _refreshRecentTrendInBackground(
    String stationId, {
    required String cacheKey,
    required int recentDays,
    required int historicalDays,
  }) async {
    try {
      if (kDebugMode) {
        print(
          '🔄 HistoricalWaterDataProvider: Background refresh for trend $cacheKey',
        );
      }

      final result = await HistoricalWaterDataService.getRecentTrend(
        stationId,
        recentDays: recentDays,
        historicalDays: historicalDays,
      );

      // Update cache
      _recentTrendCache[cacheKey] = result;
      _recentTrendCacheTime[cacheKey] = DateTime.now();

      if (kDebugMode) {
        print(
          '✅ HistoricalWaterDataProvider: Background refresh completed for $cacheKey',
        );
      }

      notifyListeners(); // Update UI with fresh data
    } catch (e) {
      // Silent failure - keep using stale data
      if (kDebugMode) {
        print(
          '❌ HistoricalWaterDataProvider: Background refresh failed for $cacheKey: $e',
        );
      }
    }
  }

  /// Clear cache for a specific station or all stations
  void clearCache([String? stationId]) {
    if (stationId != null) {
      // Clear specific station cache
      _combinedTimelineCache.removeWhere((key, _) => key.startsWith(stationId));
      _combinedTimelineCacheTime.removeWhere(
        (key, _) => key.startsWith(stationId),
      );
      _historicalDataCache.removeWhere((key, _) => key.startsWith(stationId));
      _historicalDataCacheTime.removeWhere(
        (key, _) => key.startsWith(stationId),
      );
      _recentTrendCache.removeWhere((key, _) => key.startsWith(stationId));
      _recentTrendCacheTime.removeWhere((key, _) => key.startsWith(stationId));
      _loadingStates.remove(stationId);
      _errors.remove(stationId);

      if (kDebugMode) {
        print('🗑️ HistoricalWaterDataProvider: Cleared cache for $stationId');
      }
    } else {
      // Clear all caches
      _combinedTimelineCache.clear();
      _combinedTimelineCacheTime.clear();
      _historicalDataCache.clear();
      _historicalDataCacheTime.clear();
      _recentTrendCache.clear();
      _recentTrendCacheTime.clear();
      _loadingStates.clear();
      _errors.clear();

      if (kDebugMode) {
        print('🗑️ HistoricalWaterDataProvider: Cleared all caches');
      }
    }

    notifyListeners();
  }

  /// Get data availability information
  Map<String, dynamic> getDataAvailabilityInfo() {
    return HistoricalWaterDataService.getDataAvailabilityInfo();
  }
}
