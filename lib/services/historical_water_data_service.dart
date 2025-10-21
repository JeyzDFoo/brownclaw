import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// HistoricalWaterDataService - Web-Only Implementation
///
/// This service fetches historical water data from the Government of Canada's
/// hydrometric API for web deployment only. The app is designed exclusively
/// for web platforms and does not support mobile or desktop platforms.
///
/// DATA AVAILABILITY NOTICE:
/// - Historical daily data: Available through December 31, 2024
/// - Current year gap: January 1, 2025 to September 15, 2025 (no data available)
/// - Real-time data: Available for last 30 days only (via separate service)
/// - This service focuses on historical analysis and trends using complete data
///
/// Features:
/// - Direct API calls to Government of Canada JSON endpoint for historical data
/// - Date range queries for flow and water level data
/// - Aggregated data processing (daily, weekly, monthly averages)
/// - Web-optimized with CORS-friendly endpoints
/// - Clear gap handling with user-friendly messaging
class HistoricalWaterDataService {
  // Government of Canada JSON API for historical daily mean data
  static const String jsonBaseUrl =
      'https://api.weather.gc.ca/collections/hydrometric-daily-mean/items';

  // Cache for historical data to reduce API calls
  static final Map<String, Map<String, dynamic>> _historicalDataCache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheTimeout = Duration(
    hours: 1,
  ); // Cache historical data for 1 hour

  /// Clear cache for a specific station or all stations
  static void clearCache([String? stationId]) {
    if (stationId != null) {
      _historicalDataCache.remove(stationId);
      _cacheTimestamps.remove(stationId);
    } else {
      _historicalDataCache.clear();
      _cacheTimestamps.clear();
    }
  }

  /// Get information about data availability and gaps
  /// Returns comprehensive information about what data is available and what gaps exist
  static Map<String, dynamic> getDataAvailabilityInfo() {
    final now = DateTime.now();
    final historicalEnd = DateTime(2024, 12, 31);
    final realtimeStart = now.subtract(const Duration(days: 30));
    final gapStart = DateTime(2025, 1, 1);
    final gapEnd = realtimeStart.subtract(const Duration(days: 1));

    final gapDays = gapEnd.difference(gapStart).inDays + 1;

    return {
      'historicalData': {
        'available': true,
        'startDate':
            '1912-01-01', // Historical data goes back to early 1900s for most stations
        'endDate': historicalEnd.toIso8601String().split('T')[0],
        'description':
            'Complete historical daily mean data from Government of Canada',
        'source': 'hydrometric-daily-mean API',
      },
      'currentYearGap': {
        'hasGap': true,
        'startDate': gapStart.toIso8601String().split('T')[0],
        'endDate': gapEnd.toIso8601String().split('T')[0],
        'gapDays': gapDays,
        'description': 'No daily mean data available for this period',
        'reason': 'Government daily-mean API has processing lag',
      },
      'realtimeData': {
        'available': true,
        'startDate': realtimeStart.toIso8601String().split('T')[0],
        'endDate': now.toIso8601String().split('T')[0],
        'description': 'Real-time data (5-minute intervals) for last 30 days',
        'source': 'hydrometric-realtime API (use LiveWaterDataService)',
      },
      'recommendations': [
        'Use historical data for long-term trends and seasonal analysis',
        'Use real-time data for current conditions (last 30 days)',
        'Consider historical patterns to estimate conditions during gap period',
        'Gap period represents normal government data processing delays',
      ],
    };
  }

  /// Fetch historical data for a specific station and date range (web-only)
  /// Returns daily mean discharge and water level data from Government of Canada HYDAT database
  ///
  /// IMPORTANT: Historical daily data ends at December 31, 2024. For current conditions,
  /// use the LiveWaterDataService which provides real-time data for the last 30 days.
  /// There is a data gap from January 1, 2025 to mid-September 2025.
  ///
  /// Parameters:
  /// - [stationId]: The station ID to fetch data for
  /// - [startDate]: Start date for data range (optional)
  /// - [endDate]: End date for data range (defaults to December 31, 2024)
  /// - [daysBack]: Number of days back from endDate (defaults to 365)
  /// - [year]: Specific year to fetch data for (e.g., 2024) - fetches full calendar year
  static Future<List<Map<String, dynamic>>> fetchHistoricalData(
    String stationId, {
    DateTime? startDate,
    DateTime? endDate,
    int? daysBack,
    int? year,
  }) async {
    // If year is specified, fetch the full calendar year
    if (year != null) {
      startDate = DateTime(year, 1, 1);
      endDate = DateTime(year, 12, 31);
    } else {
      // Default to December 31, 2024 - the last date with available historical data
      // Note: Current year data (2025) is not available through this historical API
      final historicalDataEnd = DateTime(2024, 12, 31);

      endDate ??= historicalDataEnd;
      startDate ??= daysBack != null
          ? endDate.subtract(Duration(days: daysBack))
          : DateTime(endDate.year, 1, 1); // Default to full year
    }

    final cacheKey =
        '${stationId}_${startDate.millisecondsSinceEpoch}_${endDate.millisecondsSinceEpoch}';

    debugPrint('   🔑 Cache key: $cacheKey');

    // Check for valid cached data first
    final cachedData = _historicalDataCache[cacheKey];
    final cacheTime = _cacheTimestamps[cacheKey];

    if (cachedData != null && cacheTime != null) {
      final cacheAge = DateTime.now().difference(cacheTime);
      if (cacheAge < _cacheTimeout) {
        debugPrint(
          '   ♻️ Using cached data (age: ${cacheAge.inMinutes} minutes)',
        );
        return List<Map<String, dynamic>>.from(cachedData['data'] ?? []);
      } else {
        debugPrint('   🗑️ Cache expired (age: ${cacheAge.inMinutes} minutes)');
      }
    } else {
      debugPrint('   📭 No cache found');
    }

    try {
      // Format dates for API call (ISO format)
      final startDateStr = startDate.toIso8601String().split('T')[0];
      final endDateStr = endDate.toIso8601String().split('T')[0];

      final url =
          '$jsonBaseUrl?'
          'STATION_NUMBER=$stationId&'
          'datetime=$startDateStr/$endDateStr&'
          'limit=1000&'
          'sortby=DATE&'
          'f=json';

      debugPrint('📊 Fetching historical data: $url');
      debugPrint('   Date range: $startDateStr to $endDateStr');

      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 30));

      debugPrint('   Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = response.body;
        final historicalData = _parseHistoricalResponse(jsonData, stationId);

        debugPrint('   ✅ Parsed ${historicalData.length} data points');

        // Cache successful results
        if (historicalData.isNotEmpty) {
          _historicalDataCache[cacheKey] = {'data': historicalData};
          _cacheTimestamps[cacheKey] = DateTime.now();
        }

        return historicalData;
      } else {
        debugPrint('   ❌ Non-200 status code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('   ❌ Error fetching historical data: $e');
    }

    return [];
  }

  /// Parse historical data from JSON API response
  static List<Map<String, dynamic>> _parseHistoricalResponse(
    String jsonData,
    String stationId,
  ) {
    try {
      final data = json.decode(jsonData);
      final features = data['features'] as List? ?? [];

      debugPrint('   🔍 Parser: Found ${features.length} features in response');

      final historicalData = <Map<String, dynamic>>[];

      for (final feature in features) {
        final props = feature['properties'];
        if (props != null) {
          final date = props['DATE'];
          final discharge = props['DISCHARGE'];
          final level = props['LEVEL'];

          if (date != null) {
            final dataPoint = {
              'date': date,
              'discharge': discharge != null
                  ? double.tryParse(discharge.toString())
                  : null,
              'level': level != null ? double.tryParse(level.toString()) : null,
              'stationId': stationId,
            };

            // Only include data points with at least one valid measurement
            if (dataPoint['discharge'] != null || dataPoint['level'] != null) {
              historicalData.add(dataPoint);
            }
          }
        }
      }

      debugPrint(
        '   ✅ Parser: Created ${historicalData.length} data points from ${features.length} features',
      );

      if (features.isNotEmpty && historicalData.isEmpty) {
        debugPrint('   ⚠️ Parser: Had features but created no data points');
        debugPrint(
          '   First feature properties: ${features.first['properties']}',
        );
      }

      // Sort by date (oldest first for historical data)
      historicalData.sort(
        (a, b) => (a['date'] as String).compareTo(b['date'] as String),
      );

      return historicalData;
    } catch (e) {
      // Silent error handling for production
    }
    return [];
  }

  /// Get flow statistics for a station over a date range
  static Future<Map<String, dynamic>> getFlowStatistics(
    String stationId, {
    DateTime? startDate,
    DateTime? endDate,
    int? daysBack,
    int? year,
  }) async {
    final historicalData = await fetchHistoricalData(
      stationId,
      startDate: startDate,
      endDate: endDate,
      daysBack: daysBack,
      year: year,
    );

    if (historicalData.isEmpty) {
      return {'error': 'No data available', 'count': 0};
    }

    final dischargeValues = historicalData
        .where((data) => data['discharge'] != null)
        .map<double>((data) => data['discharge'] as double)
        .toList();

    if (dischargeValues.isEmpty) {
      return {'error': 'No discharge data available', 'count': 0};
    }

    dischargeValues.sort();

    final count = dischargeValues.length;
    final sum = dischargeValues.reduce((a, b) => a + b);
    final average = sum / count;
    final minimum = dischargeValues.first;
    final maximum = dischargeValues.last;

    // Calculate percentiles
    final p25Index = (count * 0.25).floor();
    final p50Index = (count * 0.50).floor();
    final p75Index = (count * 0.75).floor();

    return {
      'count': count,
      'average': double.parse(average.toStringAsFixed(2)),
      'minimum': double.parse(minimum.toStringAsFixed(2)),
      'maximum': double.parse(maximum.toStringAsFixed(2)),
      'percentile25': double.parse(
        dischargeValues[p25Index].toStringAsFixed(2),
      ),
      'median': double.parse(dischargeValues[p50Index].toStringAsFixed(2)),
      'percentile75': double.parse(
        dischargeValues[p75Index].toStringAsFixed(2),
      ),
      'dateRange': {
        'start': historicalData.first['date'],
        'end': historicalData.last['date'],
      },
    };
  }

  /// Get recent trend for a station (comparing current period to historical average)
  ///
  /// Parameters:
  /// - [stationId]: The station ID to analyze
  /// - [recentDays]: Number of recent days to analyze (default: 7)
  /// - [historicalDays]: Number of historical days for comparison (default: 30)
  ///
  /// Returns trend analysis including percent change and trend direction
  static Future<Map<String, dynamic>> getRecentTrend(
    String stationId, {
    int recentDays = 7,
    int historicalDays = 30,
  }) async {
    // Get recent data
    final recentData = await fetchHistoricalData(
      stationId,
      daysBack: recentDays,
    );

    // Get historical comparison data
    final historicalData = await fetchHistoricalData(
      stationId,
      daysBack: historicalDays,
    );

    if (recentData.isEmpty || historicalData.isEmpty) {
      return {'error': 'Insufficient data for trend analysis'};
    }

    final recentDischarge = recentData
        .where((data) => data['discharge'] != null)
        .map<double>((data) => data['discharge'] as double)
        .toList();

    final historicalDischarge = historicalData
        .where((data) => data['discharge'] != null)
        .map<double>((data) => data['discharge'] as double)
        .toList();

    if (recentDischarge.isEmpty || historicalDischarge.isEmpty) {
      return {'error': 'Insufficient discharge data for trend analysis'};
    }

    final recentAverage =
        recentDischarge.reduce((a, b) => a + b) / recentDischarge.length;
    final historicalAverage =
        historicalDischarge.reduce((a, b) => a + b) /
        historicalDischarge.length;

    final percentChange =
        ((recentAverage - historicalAverage) / historicalAverage) * 100;

    String trend;
    Color trendColor;

    if (percentChange > 10) {
      trend = 'Rising';
      trendColor = Colors.blue;
    } else if (percentChange < -10) {
      trend = 'Falling';
      trendColor = Colors.orange;
    } else {
      trend = 'Stable';
      trendColor = Colors.green;
    }

    return {
      'recentAverage': double.parse(recentAverage.toStringAsFixed(2)),
      'historicalAverage': double.parse(historicalAverage.toStringAsFixed(2)),
      'percentChange': double.parse(percentChange.toStringAsFixed(1)),
      'trend': trend,
      'trendColor': trendColor,
      'recentDays': recentDays,
      'historicalDays': historicalDays,
    };
  }

  /// Get seasonal comparison data for a station
  static Future<Map<String, dynamic>> getSeasonalComparison(
    String stationId, {
    int year = 0, // 0 = current year
  }) async {
    final targetYear = year == 0 ? DateTime.now().year : year;
    final startOfYear = DateTime(targetYear, 1, 1);
    final endOfYear = DateTime(targetYear, 12, 31);

    final yearData = await fetchHistoricalData(
      stationId,
      startDate: startOfYear,
      endDate: endOfYear,
    );

    if (yearData.isEmpty) {
      return {'error': 'No data available for year $targetYear'};
    }

    // Group data by season
    final seasons = <String, List<double>>{
      'Spring': [], // Mar, Apr, May
      'Summer': [], // Jun, Jul, Aug
      'Fall': [], // Sep, Oct, Nov
      'Winter': [], // Dec, Jan, Feb
    };

    for (final data in yearData) {
      final discharge = data['discharge'] as double?;
      if (discharge != null) {
        final date = DateTime.parse(data['date'] as String);
        final month = date.month;

        if (month >= 3 && month <= 5) {
          seasons['Spring']!.add(discharge);
        } else if (month >= 6 && month <= 8) {
          seasons['Summer']!.add(discharge);
        } else if (month >= 9 && month <= 11) {
          seasons['Fall']!.add(discharge);
        } else {
          seasons['Winter']!.add(discharge);
        }
      }
    }

    // Calculate seasonal averages
    final seasonalAverages = <String, double>{};
    for (final season in seasons.keys) {
      final values = seasons[season]!;
      if (values.isNotEmpty) {
        seasonalAverages[season] =
            values.reduce((a, b) => a + b) / values.length;
      }
    }

    return {
      'year': targetYear,
      'seasonalAverages': seasonalAverages.map(
        (season, avg) => MapEntry(season, double.parse(avg.toStringAsFixed(2))),
      ),
      'dataPointsPerSeason': seasons.map(
        (season, values) => MapEntry(season, values.length),
      ),
    };
  }

  // Convenience methods with common time periods

  /// Get last 3 days of data
  static Future<List<Map<String, dynamic>>> getLast3Days(String stationId) {
    return fetchHistoricalData(stationId, daysBack: 3);
  }

  /// Get last week's data (7 days)
  static Future<List<Map<String, dynamic>>> getLastWeek(String stationId) {
    return fetchHistoricalData(stationId, daysBack: 7);
  }

  /// Get last month's data (30 days)
  static Future<List<Map<String, dynamic>>> getLastMonth(String stationId) {
    return fetchHistoricalData(stationId, daysBack: 30);
  }

  /// Get last year's data (365 days)
  static Future<List<Map<String, dynamic>>> getLastYear(String stationId) {
    return fetchHistoricalData(stationId, daysBack: 365);
  }

  /// Get custom period trend analysis
  /// Compare recent N days to historical M days
  static Future<Map<String, dynamic>> getCustomTrend(
    String stationId, {
    required int recentDays,
    required int historicalDays,
  }) {
    return getRecentTrend(
      stationId,
      recentDays: recentDays,
      historicalDays: historicalDays,
    );
  }

  /// Get flow statistics for common time periods
  static Future<Map<String, dynamic>> get3DayStats(String stationId) {
    return getFlowStatistics(stationId, daysBack: 3);
  }

  static Future<Map<String, dynamic>> getWeeklyStats(String stationId) {
    return getFlowStatistics(stationId, daysBack: 7);
  }

  static Future<Map<String, dynamic>> getMonthlyStats(String stationId) {
    return getFlowStatistics(stationId, daysBack: 30);
  }

  static Future<Map<String, dynamic>> getYearlyStats(String stationId) {
    return getFlowStatistics(stationId, daysBack: 365);
  }

  /// Get flow statistics for a custom number of days
  static Future<Map<String, dynamic>> getCustomStats(
    String stationId,
    int days,
  ) {
    return getFlowStatistics(stationId, daysBack: days);
  }

  // REAL-TIME DATA INTEGRATION
  // These methods fetch real-time data and convert it to the same format as historical data

  /// Fetch real-time data and convert to historical data format
  /// This allows seamless integration of the last 30 days of real-time data
  /// with historical data for a complete timeline (where available)
  static Future<List<Map<String, dynamic>>> fetchRealtimeAsHistorical(
    String stationId, {
    int? limitDays,
  }) async {
    try {
      // Real-time API endpoint (same as LiveWaterDataService but we parse it differently)
      final url =
          'https://api.weather.gc.ca/collections/hydrometric-realtime/items?'
          'STATION_NUMBER=$stationId&'
          'limit=${limitDays != null ? limitDays * 288 : 8640}&' // 288 records per day (5-min intervals)
          'sortby=-DATETIME&' // Sort descending (newest first) to get most recent data
          'f=json';

      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return _parseRealtimeResponse(response.body, stationId);
      }
    } catch (e) {
      // Silent error handling for production
    }
    return [];
  }

  /// Parse real-time API response into historical data format
  /// Converts 5-minute interval data to daily averages to match historical format
  static List<Map<String, dynamic>> _parseRealtimeResponse(
    String jsonData,
    String stationId,
  ) {
    try {
      final data = json.decode(jsonData);
      final features = data['features'] as List? ?? [];

      if (features.isEmpty) return [];

      // Group by date and calculate daily averages
      final dailyData = <String, List<Map<String, dynamic>>>{};

      for (final feature in features) {
        final props = feature['properties'];
        if (props != null) {
          final datetime = props['DATETIME'] as String?;
          final discharge = props['DISCHARGE'];
          final level = props['LEVEL'];

          if (datetime != null) {
            // Extract date (YYYY-MM-DD) from datetime
            final date = datetime.split('T')[0];

            if (!dailyData.containsKey(date)) {
              dailyData[date] = [];
            }

            // Store individual measurements for daily averaging
            dailyData[date]!.add({
              'discharge': discharge != null
                  ? double.tryParse(discharge.toString())
                  : null,
              'level': level != null ? double.tryParse(level.toString()) : null,
            });
          }
        }
      }

      // Convert to daily averages in historical format
      final historicalFormat = <Map<String, dynamic>>[];

      for (final date in dailyData.keys) {
        final dayMeasurements = dailyData[date]!;

        // Calculate daily average discharge
        final dischargeValues = dayMeasurements
            .where((m) => m['discharge'] != null)
            .map<double>((m) => m['discharge'] as double)
            .toList();

        // Calculate daily average level
        final levelValues = dayMeasurements
            .where((m) => m['level'] != null)
            .map<double>((m) => m['level'] as double)
            .toList();

        final dailyAvgDischarge = dischargeValues.isNotEmpty
            ? dischargeValues.reduce((a, b) => a + b) / dischargeValues.length
            : null;

        final dailyAvgLevel = levelValues.isNotEmpty
            ? levelValues.reduce((a, b) => a + b) / levelValues.length
            : null;

        // Only include days with at least one valid measurement
        if (dailyAvgDischarge != null || dailyAvgLevel != null) {
          historicalFormat.add({
            'date': date,
            'discharge': dailyAvgDischarge,
            'level': dailyAvgLevel,
            'stationId': stationId,
            'source': 'realtime', // Mark as real-time sourced
            'measurementCount':
                dayMeasurements.length, // How many measurements averaged
          });
        }
      }

      // Sort by date (oldest first to match historical data)
      historicalFormat.sort(
        (a, b) => (a['date'] as String).compareTo(b['date'] as String),
      );

      return historicalFormat;
    } catch (e) {
      // Silent error handling for production
    }
    return [];
  }

  /// Get combined historical and real-time data with gap information
  /// This method provides a complete timeline where possible, clearly marking data sources
  static Future<Map<String, dynamic>> getCombinedTimeline(
    String stationId, {
    DateTime? startDate,
    DateTime? endDate,
    bool includeRealtimeData = true,
  }) async {
    final results = <String, dynamic>{
      'historical': <Map<String, dynamic>>[],
      'realtime': <Map<String, dynamic>>[],
      'gap': <String, dynamic>{},
      'combined': <Map<String, dynamic>>[],
      'availability': getDataAvailabilityInfo(),
    };

    // Get historical data (up to 2024-12-31)
    final historicalData = await fetchHistoricalData(
      stationId,
      startDate: startDate,
      endDate: endDate,
    );
    results['historical'] = historicalData;

    // Get real-time data (last 30 days) if requested
    if (includeRealtimeData) {
      debugPrint('📡 Fetching realtime data...');
      final realtimeData = await fetchRealtimeAsHistorical(stationId);
      debugPrint('   ✅ Got ${realtimeData.length} realtime data points');
      results['realtime'] = realtimeData;

      // Create combined timeline
      final combined = <Map<String, dynamic>>[];
      combined.addAll(historicalData);
      combined.addAll(realtimeData);

      debugPrint(
        '   📊 Combined total: ${combined.length} data points (${historicalData.length} historical + ${realtimeData.length} realtime)',
      );

      // Sort combined data by date
      combined.sort(
        (a, b) => (a['date'] as String).compareTo(b['date'] as String),
      );

      results['combined'] = combined;
    } else {
      results['combined'] = historicalData;
    }

    // Calculate gap information
    if (historicalData.isNotEmpty) {
      final lastHistorical = historicalData.last['date'] as String;
      final firstRealtime = results['realtime'].isNotEmpty
          ? (results['realtime'] as List).first['date'] as String
          : null;

      if (firstRealtime != null) {
        final lastHistoricalDate = DateTime.parse(lastHistorical);
        final firstRealtimeDate = DateTime.parse(firstRealtime);
        final gapDays =
            firstRealtimeDate.difference(lastHistoricalDate).inDays - 1;

        if (gapDays > 0) {
          results['gap'] = {
            'exists': true,
            'startDate': DateTime(
              lastHistoricalDate.year,
              lastHistoricalDate.month,
              lastHistoricalDate.day + 1,
            ).toIso8601String().split('T')[0],
            'endDate': DateTime(
              firstRealtimeDate.year,
              firstRealtimeDate.month,
              firstRealtimeDate.day - 1,
            ).toIso8601String().split('T')[0],
            'days': gapDays,
            'description':
                'Government data processing gap - no daily mean data available',
          };
        } else {
          results['gap'] = {'exists': false};
        }
      } else {
        // No real-time data available
        final now = DateTime.now();
        final lastHistoricalDate = DateTime.parse(lastHistorical);
        final gapDays = now.difference(lastHistoricalDate).inDays;

        results['gap'] = {
          'exists': true,
          'startDate': DateTime(
            lastHistoricalDate.year,
            lastHistoricalDate.month,
            lastHistoricalDate.day + 1,
          ).toIso8601String().split('T')[0],
          'endDate': now.toIso8601String().split('T')[0],
          'days': gapDays,
          'description':
              'Government data processing gap - no current data available',
        };
      }
    }

    return results;
  }

  /// Get recent real-time data as daily averages (convenience method)
  static Future<List<Map<String, dynamic>>> getRecentRealtime(
    String stationId, {
    int days = 30,
  }) {
    return fetchRealtimeAsHistorical(stationId, limitDays: days);
  }

  /// Check if real-time data is available for a station
  static Future<bool> hasRealtimeData(String stationId) async {
    final realtimeData = await fetchRealtimeAsHistorical(
      stationId,
      limitDays: 1,
    );
    return realtimeData.isNotEmpty;
  }
}
