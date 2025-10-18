import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/transalta_flow_data.dart';

/// Service for fetching TransAlta Barrier Dam flow data
///
/// TransAlta operates hydro facilities in Kananaskis, Alberta:
/// - Barrier Dam
/// - Pocaterra Hydro Facility
///
/// This service provides real-time and forecasted flow data for planning
/// whitewater activities on the Kananaskis River.
class TransAltaService {
  static const String _baseUrl = 'https://transalta.com/river-flows/';
  static const String _transAltaEndpoint = '$_baseUrl?get-riverflow-data=1';

  // Multiple CORS proxies as fallbacks
  static const List<String> _corsProxies = [
    'https://api.allorigins.win/raw?url=',
    'https://corsproxy.io/?',
    'https://api.codetabs.com/v1/proxy?quest=',
  ];

  int _currentProxyIndex = 0;

  // Water travel time from Barrier Dam to downstream locations
  static const int travelTimeMinutes = 45; // to Canoe Meadows

  // Cache for flow data
  TransAltaFlowData? _cachedData;
  DateTime? _cacheTime;
  static const Duration _cacheDuration = Duration(minutes: 15);

  /// Fetch current and forecasted flow data from TransAlta
  Future<TransAltaFlowData?> fetchFlowData({bool forceRefresh = false}) async {
    // Check cache first
    if (!forceRefresh && _cachedData != null && _cacheTime != null) {
      final cacheAge = DateTime.now().difference(_cacheTime!);
      if (cacheAge < _cacheDuration) {
        debugPrint(
          'TransAlta: Using cached data (${cacheAge.inMinutes} minutes old)',
        );
        return _cachedData;
      }
    }

    // Try each CORS proxy until one works
    for (int i = 0; i < _corsProxies.length; i++) {
      final proxyIndex = (_currentProxyIndex + i) % _corsProxies.length;
      final proxy = _corsProxies[proxyIndex];
      final endpoint = '$proxy$_transAltaEndpoint';

      try {
        debugPrint(
          'TransAlta: Trying proxy ${proxyIndex + 1}/${_corsProxies.length}...',
        );

        final response = await http
            .get(
              Uri.parse(endpoint),
              headers: {
                'User-Agent': 'BrownClaw-Flutter-App/1.0',
                'Accept': 'application/json, text/javascript, */*; q=0.01',
                'Accept-Language': 'en-US,en;q=0.9',
              },
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final jsonData = json.decode(response.body) as Map<String, dynamic>;
          final flowData = TransAltaFlowData.fromJson(jsonData);

          // Update cache and remember working proxy
          _cachedData = flowData;
          _cacheTime = DateTime.now();
          _currentProxyIndex = proxyIndex;

          debugPrint(
            'TransAlta: ✅ Success via proxy ${proxyIndex + 1} - ${flowData.forecasts.length} days of data',
          );
          return flowData;
        } else {
          debugPrint(
            'TransAlta: ❌ Proxy ${proxyIndex + 1} returned HTTP ${response.statusCode}',
          );
        }
      } catch (e) {
        debugPrint('TransAlta: ❌ Proxy ${proxyIndex + 1} failed: $e');
      }
    }

    // All proxies failed
    debugPrint(
      'TransAlta: ⚠️ All proxies failed. Returning cached data if available.',
    );

    // Return cached data even if expired - better than nothing
    if (_cachedData != null) {
      final age = DateTime.now().difference(_cacheTime!);
      debugPrint('TransAlta: Using stale cache (${age.inMinutes} minutes old)');
    }

    return _cachedData;
  }

  /// Get current flow conditions
  Future<HourlyFlowEntry?> getCurrentFlow({bool forceRefresh = false}) async {
    final data = await fetchFlowData(forceRefresh: forceRefresh);
    return data?.currentFlow;
  }

  /// Get high flow schedule for all forecast days
  ///
  /// [threshold] - Minimum flow rate in m³/s (default 20.0)
  /// Returns list of days with high flow periods
  Future<List<HighFlowPeriod>> getHighFlowSchedule({
    double threshold = 20.0,
    bool forceRefresh = false,
  }) async {
    final data = await fetchFlowData(forceRefresh: forceRefresh);
    if (data == null) return [];

    return data.getHighFlowHours(threshold: threshold);
  }

  /// Get a simple text summary of high flow hours for a specific day
  String getHighFlowSummary(HighFlowPeriod period) {
    if (period.entries.isEmpty) {
      return '${period.dateString}: No high flow';
    }

    return '${period.dateString}: Water arrives ${period.arrivalTimeRange} (${period.totalHours}h of flow ≥${period.threshold} m³/s)';
  }

  /// Get a formatted schedule for all high flow days
  Future<String> getHighFlowScheduleText({
    double threshold = 20.0,
    bool forceRefresh = false,
  }) async {
    final periods = await getHighFlowSchedule(
      threshold: threshold,
      forceRefresh: forceRefresh,
    );

    if (periods.isEmpty) {
      return 'No high flow periods in the forecast';
    }

    final buffer = StringBuffer();
    buffer.writeln('🌊 KANANASKIS RIVER HIGH FLOW SCHEDULE');
    buffer.writeln('Threshold: ≥$threshold m³/s at Barrier Dam');
    buffer.writeln('Water arrival times (+${travelTimeMinutes}min from dam)');
    buffer.writeln('');

    for (final period in periods) {
      buffer.writeln(getHighFlowSummary(period));
    }

    return buffer.toString();
  }

  /// Check if there is runnable flow right now
  ///
  /// [minFlow] - Minimum flow rate to be considered runnable (default 20.0)
  Future<bool> isRunnableNow({
    double minFlow = 20.0,
    bool forceRefresh = false,
  }) async {
    final current = await getCurrentFlow(forceRefresh: forceRefresh);
    if (current == null) return false;

    return current.barrierFlow >= minFlow;
  }

  /// Get the next time high flow will be available
  /// Returns null if no high flow in forecast
  Future<DateTime?> getNextHighFlowTime({
    double threshold = 20.0,
    bool forceRefresh = false,
  }) async {
    final periods = await getHighFlowSchedule(
      threshold: threshold,
      forceRefresh: forceRefresh,
    );

    if (periods.isEmpty) return null;

    final now = DateTime.now();

    // Look through all periods to find the next high flow
    for (final period in periods) {
      for (final entry in period.entries) {
        final arrivalTime = entry.getWaterArrivalTime(
          travelTimeMinutes: travelTimeMinutes,
        );

        if (arrivalTime.isAfter(now)) {
          return arrivalTime;
        }
      }
    }

    return null;
  }

  /// Clear the cache (useful for testing or forcing refresh)
  void clearCache() {
    _cachedData = null;
    _cacheTime = null;
    debugPrint('TransAlta: Cache cleared');
  }

  /// Get cache age in minutes (null if no cache)
  int? getCacheAgeMinutes() {
    if (_cacheTime == null) return null;
    return DateTime.now().difference(_cacheTime!).inMinutes;
  }

  /// Check if cache is valid
  bool get isCacheValid {
    if (_cachedData == null || _cacheTime == null) return false;
    final cacheAge = DateTime.now().difference(_cacheTime!);
    return cacheAge < _cacheDuration;
  }
}

/// Singleton instance for easy access
final transAltaService = TransAltaService();
