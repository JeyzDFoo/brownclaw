import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service for fetching sunrise, sunset, and civil twilight times
/// Uses the free sunrise-sunset.org API
class SunTimesService {
  // Kananaskis coordinates (51.1°N, 115.0°W)
  static const double _kananaskisLat = 51.1;
  static const double _kananaskisLng = -115.0;

  // Cache for civil twilight times (date string -> DateTime)
  static final Map<String, DateTime> _civilTwilightCache = {};
  static final Map<String, DateTime> _cacheTimestamp = {};
  static const Duration _cacheExpiry = Duration(hours: 12);

  /// Get civil twilight end time for a specific date at Kananaskis location
  /// Returns the time when the sun is 6° below the horizon (end of civil twilight)
  /// Caches results to minimize API calls
  static Future<DateTime> getCivilTwilightEnd(DateTime date) async {
    final dateKey = '${date.year}-${date.month}-${date.day}';

    // Check cache first
    if (_civilTwilightCache.containsKey(dateKey)) {
      final cacheTime = _cacheTimestamp[dateKey];
      if (cacheTime != null &&
          DateTime.now().difference(cacheTime) < _cacheExpiry) {
        return _civilTwilightCache[dateKey]!;
      }
    }

    try {
      // Fetch from API
      final response = await http
          .get(
            Uri.parse(
              'https://api.sunrise-sunset.org/json?lat=$_kananaskisLat&lng=$_kananaskisLng&date=${date.year}-${date.month}-${date.day}&formatted=0',
            ),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final civilTwilightEndStr = data['results']['civil_twilight_end'];
          final civilTwilightEnd = DateTime.parse(civilTwilightEndStr);

          // Convert from UTC to Mountain Time (UTC-7 in summer, UTC-6 in winter)
          final localTime = civilTwilightEnd.toLocal();

          // Cache the result
          _civilTwilightCache[dateKey] = localTime;
          _cacheTimestamp[dateKey] = DateTime.now();

          return localTime;
        }
      }
    } catch (e) {
      // If API fails, fall back to lookup table
      return _fallbackCivilTwilight(date);
    }

    // Fallback if API response is not OK
    return _fallbackCivilTwilight(date);
  }

  /// Fallback civil twilight calculation using lookup table
  /// Used when API is unavailable
  static DateTime _fallbackCivilTwilight(DateTime date) {
    // Monthly civil twilight end times (mid-month values, Mountain Time)
    final monthlyTwilightHours = [
      17.33, // Jan 15: ~5:20 PM
      18.17, // Feb 15: ~6:10 PM
      19.00, // Mar 15: ~7:00 PM (DST starts)
      20.83, // Apr 15: ~8:50 PM
      21.50, // May 15: ~9:30 PM
      22.08, // Jun 15: ~10:05 PM (longest day)
      22.00, // Jul 15: ~10:00 PM
      21.25, // Aug 15: ~9:15 PM
      20.17, // Sep 15: ~8:10 PM
      19.00, // Oct 15: ~7:00 PM
      17.70, // Nov 15: ~5:42 PM (DST ends)
      17.00, // Dec 15: ~5:00 PM (shortest day)
    ];

    final month = date.month;
    final day = date.day;

    final currentMonthIndex = month - 1;
    final nextMonthIndex = month % 12;

    final currentTwilight = monthlyTwilightHours[currentMonthIndex];
    final nextTwilight = monthlyTwilightHours[nextMonthIndex];

    final daysInMonth = DateTime(date.year, month + 1, 0).day;
    final interpolationFactor = (day - 15) / daysInMonth;
    final twilightHours =
        currentTwilight +
        (nextTwilight - currentTwilight) * interpolationFactor;

    final hour = twilightHours.floor();
    final minute = ((twilightHours - hour) * 60).round();
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  /// Clear the cache (useful for testing or manual refresh)
  static void clearCache() {
    _civilTwilightCache.clear();
    _cacheTimestamp.clear();
    print('SunTimesService: Cache cleared');
  }
}
