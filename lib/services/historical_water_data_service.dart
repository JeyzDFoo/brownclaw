import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// HistoricalWaterDataService - Web-Only Implementation
///
/// This service fetches historical water data from the Government of Canada's
/// hydrometric API for web deployment only. The app is designed exclusively
/// for web platforms and does not support mobile or desktop platforms.
///
/// Features:
/// - Direct API calls to Government of Canada JSON endpoint for historical data
/// - Date range queries for flow and water level data
/// - Aggregated data processing (daily, weekly, monthly averages)
/// - Web-optimized with CORS-friendly endpoints
class HistoricalWaterDataService {
  // Government of Canada JSON API for historical data
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

  /// Fetch historical data for a specific station and date range (web-only)
  /// Returns daily mean discharge and water level data
  ///
  /// Parameters:
  /// - [stationId]: The station ID to fetch data for
  /// - [startDate]: Start date for data range (optional)
  /// - [endDate]: End date for data range (defaults to now)
  /// - [daysBack]: Number of days back from endDate (defaults to 30 if no startDate provided)
  static Future<List<Map<String, dynamic>>> fetchHistoricalData(
    String stationId, {
    DateTime? startDate,
    DateTime? endDate,
    int? daysBack,
  }) async {
    // Set default date range if not provided
    endDate ??= DateTime.now();
    startDate ??= daysBack != null
        ? endDate.subtract(Duration(days: daysBack))
        : endDate.subtract(const Duration(days: 30)); // Default to 30 days

    final cacheKey =
        '${stationId}_${startDate.millisecondsSinceEpoch}_${endDate.millisecondsSinceEpoch}';

    // Check for valid cached data first
    final cachedData = _historicalDataCache[cacheKey];
    final cacheTime = _cacheTimestamps[cacheKey];

    if (cachedData != null && cacheTime != null) {
      final cacheAge = DateTime.now().difference(cacheTime);
      if (cacheAge < _cacheTimeout) {
        return List<Map<String, dynamic>>.from(cachedData['data'] ?? []);
      }
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

      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final jsonData = response.body;
        final historicalData = _parseHistoricalResponse(jsonData, stationId);

        // Cache successful results
        if (historicalData.isNotEmpty) {
          _historicalDataCache[cacheKey] = {'data': historicalData};
          _cacheTimestamps[cacheKey] = DateTime.now();
        }

        return historicalData;
      }
    } catch (e) {
      // Silent error handling for production
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
  }) async {
    final historicalData = await fetchHistoricalData(
      stationId,
      startDate: startDate,
      endDate: endDate,
      daysBack: daysBack,
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
      'minimum': minimum,
      'maximum': maximum,
      'percentile25': dischargeValues[p25Index],
      'median': dischargeValues[p50Index],
      'percentile75': dischargeValues[p75Index],
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

  /// Get last week's data (7 days)
  static Future<List<Map<String, dynamic>>> getLastWeek(String stationId) {
    return fetchHistoricalData(stationId, daysBack: 7);
  }

  /// Get last month's data (30 days)
  static Future<List<Map<String, dynamic>>> getLastMonth(String stationId) {
    return fetchHistoricalData(stationId, daysBack: 30);
  }

  /// Get last season's data (90 days)
  static Future<List<Map<String, dynamic>>> getLastSeason(String stationId) {
    return fetchHistoricalData(stationId, daysBack: 90);
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
  static Future<Map<String, dynamic>> getWeeklyStats(String stationId) {
    return getFlowStatistics(stationId, daysBack: 7);
  }

  static Future<Map<String, dynamic>> getMonthlyStats(String stationId) {
    return getFlowStatistics(stationId, daysBack: 30);
  }

  static Future<Map<String, dynamic>> getSeasonalStats(String stationId) {
    return getFlowStatistics(stationId, daysBack: 90);
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
}
