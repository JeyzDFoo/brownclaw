import 'package:flutter/foundation.dart';
import '../models/transalta_flow_data.dart';
import '../services/transalta_service.dart';
import '../services/sun_times_service.dart';

/// Provider for managing TransAlta Barrier Dam flow data
///
/// Centralizes API calls and caching for TransAlta data used across
/// the app (favorites list, river detail screen, etc.)
class TransAltaProvider extends ChangeNotifier {
  TransAltaFlowData? _flowData;
  DateTime? _lastFetchTime;
  bool _isLoading = false;
  String? _error;
  bool _isFetching = false; // Guard against concurrent fetch calls

  // Civil twilight cache (date string -> DateTime)
  final Map<String, DateTime> _civilTwilightCache = {};

  // Cache duration - matches service cache
  static const Duration _cacheDuration = Duration(minutes: 15);

  TransAltaFlowData? get flowData => _flowData;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasData => _flowData != null;

  /// Get cached data age in minutes
  int? get cacheAgeMinutes {
    if (_lastFetchTime == null) return null;
    return DateTime.now().difference(_lastFetchTime!).inMinutes;
  }

  /// Check if cache is still valid
  bool get isCacheValid {
    if (_lastFetchTime == null || _flowData == null) return false;
    final age = DateTime.now().difference(_lastFetchTime!);
    return age < _cacheDuration;
  }

  /// Fetch flow data from TransAlta API
  ///
  /// [forceRefresh] - Bypass cache and fetch fresh data
  ///
  /// Implements stale-while-revalidate pattern:
  /// - Returns immediately if cache exists (even if stale)
  /// - Triggers background refresh if cache is stale
  /// - Only blocks if no cache exists
  Future<void> fetchFlowData({bool forceRefresh = false}) async {
    // Guard against concurrent fetch calls
    if (_isFetching) {
      debugPrint(
        'TransAltaProvider: Already fetching, skipping duplicate call',
      );
      return;
    }

    // Stale-while-revalidate: Return cached data immediately if available
    if (!forceRefresh && _flowData != null) {
      if (isCacheValid) {
        // Cache is fresh, just return
        debugPrint(
          'TransAltaProvider: Using fresh cached data (${cacheAgeMinutes}min old)',
        );
        return;
      } else {
        // Cache is stale - return it but refresh in background
        debugPrint(
          'TransAltaProvider: Using stale cache (${cacheAgeMinutes}min old), refreshing in background...',
        );
        _refreshInBackground();
        return;
      }
    }

    // No cache available - block and fetch
    _isFetching = true;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('TransAltaProvider: Fetching flow data from API...');
      final data = await transAltaService.fetchFlowData(
        forceRefresh: forceRefresh,
      );

      if (data != null) {
        _flowData = data;
        _lastFetchTime = DateTime.now();
        _error = null;
        debugPrint(
          'TransAltaProvider: Successfully fetched ${data.forecasts.length} days of data',
        );

        // Pre-fetch civil twilight times for all forecast dates
        await ensureTwilightCached();
        debugPrint('TransAltaProvider: Civil twilight times cached');
      } else {
        // Check if we have cached data to fall back on
        if (_flowData != null && _lastFetchTime != null) {
          final age = DateTime.now().difference(_lastFetchTime!);
          _error =
              'Using cached data (${age.inHours}h old). Unable to fetch updates.';
          debugPrint('TransAltaProvider: API failed but using cached data');
        } else {
          _error =
              'TransAlta service temporarily unavailable. Please try again later.';
          debugPrint(
            'TransAltaProvider: API returned null, no cache available',
          );
        }
      }
    } catch (e) {
      _error = 'Connection error. Please check your internet connection.';
      debugPrint('TransAltaProvider: Error - $e');
    } finally {
      _isLoading = false;
      _isFetching = false;
      notifyListeners();
    }
  }

  /// Background refresh for stale-while-revalidate pattern
  /// Updates cache without blocking the UI or showing loading state
  Future<void> _refreshInBackground() async {
    if (_isFetching) {
      return; // Already refreshing
    }

    _isFetching = true;
    // Don't set _isLoading or show error - this is silent background refresh

    try {
      debugPrint('TransAltaProvider: Background refresh started...');
      final data = await transAltaService.fetchFlowData(forceRefresh: true);

      if (data != null) {
        _flowData = data;
        _lastFetchTime = DateTime.now();
        _error = null;
        debugPrint(
          'TransAltaProvider: Background refresh succeeded (${data.forecasts.length} days)',
        );

        // Pre-fetch civil twilight times for all forecast dates
        await ensureTwilightCached();

        notifyListeners(); // Update UI with fresh data
      } else {
        // Silent failure - keep using stale data
        debugPrint('TransAltaProvider: Background refresh returned null');
      }
    } catch (e) {
      // Silent failure - keep using stale data, don't show error to user
      debugPrint('TransAltaProvider: Background refresh failed: $e');
    } finally {
      _isFetching = false;
    }
  }

  /// Get today's flow periods above threshold
  List<HighFlowPeriod> getTodayFlowPeriods({double threshold = 20.0}) {
    if (_flowData == null) return [];

    return _flowData!
        .getHighFlowHours(threshold: threshold)
        .where((period) => period.dayNumber == 0)
        .toList();
  }

  /// Get flow summary for today (formatted for list tile)
  String getTodayFlowSummary({double threshold = 20.0}) {
    if (_flowData == null) {
      return 'Loading...';
    }

    final todayPeriods = getTodayFlowPeriods(threshold: threshold);

    if (todayPeriods.isEmpty) {
      return 'No flow today';
    }

    // Format the periods
    if (todayPeriods.length == 1) {
      final period = todayPeriods.first;
      return '${period.arrivalTimeRange} • ${period.flowRangeString}';
    } else {
      // Multiple periods - show count
      final totalHours = todayPeriods.fold(0, (sum, p) => sum + p.totalHours);
      return '${todayPeriods.length} periods • ${totalHours}h total';
    }
  }

  /// Get current flow entry
  HourlyFlowEntry? getCurrentFlow() {
    return _flowData?.currentFlow;
  }

  /// Get all high flow periods across all forecast days
  List<HighFlowPeriod> getAllFlowPeriods({double threshold = 20.0}) {
    if (_flowData == null) return [];
    return _flowData!.getHighFlowHours(threshold: threshold);
  }

  /// Clear cached data
  void clearCache() {
    _flowData = null;
    _lastFetchTime = null;
    _error = null;
    _isLoading = false;
    _civilTwilightCache.clear();

    // Also clear service-level caches
    transAltaService.clearCache();
    SunTimesService.clearCache();

    debugPrint('TransAltaProvider: All caches cleared');
    notifyListeners();
  }

  /// Get civil twilight end time for a specific date
  /// Caches results within the provider to avoid repeated API calls
  /// Returns null if not yet fetched - call ensureTwilightCached first
  DateTime? getCivilTwilight(DateTime date) {
    final dateKey = '${date.year}-${date.month}-${date.day}';
    return _civilTwilightCache[dateKey];
  }

  /// Ensure civil twilight times are cached for the forecast period
  /// Call this during fetchFlowData to pre-populate the cache
  Future<void> ensureTwilightCached() async {
    if (_flowData == null) return;

    // Get all unique dates from the forecast
    final dates = <String>{};
    for (final forecast in _flowData!.forecasts) {
      for (final entry in forecast.entries) {
        final date = entry.dateTime;
        final dateKey = '${date.year}-${date.month}-${date.day}';
        dates.add(dateKey);
      }
    }

    // Fetch twilight times for any missing dates
    for (final dateKey in dates) {
      if (!_civilTwilightCache.containsKey(dateKey)) {
        final parts = dateKey.split('-');
        final date = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );

        try {
          final twilight = await SunTimesService.getCivilTwilightEnd(date);
          _civilTwilightCache[dateKey] = twilight;
        } catch (e) {
          debugPrint(
            'TransAltaProvider: Failed to fetch twilight for $dateKey: $e',
          );
        }
      }
    }
  }
}
