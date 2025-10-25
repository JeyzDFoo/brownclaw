import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/gauge_station.dart';
import '../models/weather_data.dart';

/// Service for fetching weather data from Open-Meteo API
/// Uses station GPS coordinates to get local weather forecasts
/// Uses CORS proxy for web compatibility
class WeatherService {
  // Using Open-Meteo API - free, no API key required
  static const String _baseUrl = 'https://api.open-meteo.com/v1/forecast';

  // Multiple CORS proxies as fallbacks (same as TransAlta service)
  static const List<String> _corsProxies = [
    'https://api.allorigins.win/raw?url=',
    'https://corsproxy.io/?',
    'https://api.codetabs.com/v1/proxy?quest=',
  ];

  int _currentProxyIndex = 0;

  // Cache for weather data
  final Map<String, WeatherData> _cache = {};
  final Map<String, DateTime> _cacheTime = {};
  static const Duration _cacheDuration = Duration(minutes: 30);

  /// Fetch current weather for a gauge station using its coordinates
  Future<WeatherData?> getWeatherForStation(GaugeStation station) async {
    // Check cache first
    final cacheKey = '${station.stationId}_current';
    if (_cache.containsKey(cacheKey) && _cacheTime.containsKey(cacheKey)) {
      final age = DateTime.now().difference(_cacheTime[cacheKey]!);
      if (age < _cacheDuration) {
        debugPrint('Weather: Using cached data (${age.inMinutes}m old)');
        return _cache[cacheKey];
      }
    }

    // Try each CORS proxy until one works
    for (int i = 0; i < _corsProxies.length; i++) {
      final proxyIndex = (_currentProxyIndex + i) % _corsProxies.length;
      final proxy = _corsProxies[proxyIndex];

      try {
        final url = Uri.parse(_baseUrl).replace(
          queryParameters: {
            'latitude': station.latitude.toString(),
            'longitude': station.longitude.toString(),
            'current':
                'temperature_2m,weather_code,precipitation,wind_speed_10m,relative_humidity_2m',
            'temperature_unit': 'celsius',
            'wind_speed_unit': 'kmh',
            'precipitation_unit': 'mm',
          },
        );

        final proxiedUrl = '$proxy${Uri.encodeComponent(url.toString())}';
        debugPrint(
          'Weather: Trying proxy ${proxyIndex + 1}/${_corsProxies.length}...',
        );

        final response = await http
            .get(Uri.parse(proxiedUrl))
            .timeout(const Duration(seconds: 10));

        if (response.statusCode != 200) {
          debugPrint(
            'Weather: Proxy ${proxyIndex + 1} failed with status ${response.statusCode}',
          );
          continue;
        }

        final data = json.decode(response.body) as Map<String, dynamic>;
        final current = data['current'] as Map<String, dynamic>;

        final weatherData = WeatherData(
          latitude: station.latitude,
          longitude: station.longitude,
          temperature: (current['temperature_2m'] as num).toDouble(),
          conditions: _weatherCodeToConditions(current['weather_code'] as int),
          precipitation: (current['precipitation'] as num?)?.toDouble() ?? 0.0,
          windSpeed: (current['wind_speed_10m'] as num?)?.toDouble(),
          humidity: current['relative_humidity_2m'] as int?,
          forecastTime: DateTime.parse(current['time'] as String),
          temperatureUnit: 'C',
        );

        // Update cache and remember working proxy
        _cache[cacheKey] = weatherData;
        _cacheTime[cacheKey] = DateTime.now();
        _currentProxyIndex = proxyIndex;

        debugPrint('Weather: ✅ Success via proxy ${proxyIndex + 1}');
        return weatherData;
      } catch (e) {
        debugPrint('Weather: Proxy ${proxyIndex + 1} error: $e');
        continue;
      }
    }

    // All proxies failed
    debugPrint('Weather: ❌ All CORS proxies failed');
    return null;
  }

  /// Convert WMO weather code to human-readable condition
  /// Based on https://open-meteo.com/en/docs
  String _weatherCodeToConditions(int code) {
    if (code == 0) return 'Clear';
    if (code >= 1 && code <= 3) return 'Partly Cloudy';
    if (code >= 45 && code <= 48) return 'Foggy';
    if (code >= 51 && code <= 57) return 'Drizzle';
    if (code >= 61 && code <= 67) return 'Rain';
    if (code >= 71 && code <= 77) return 'Snow';
    if (code >= 80 && code <= 82) return 'Rain Showers';
    if (code >= 85 && code <= 86) return 'Snow Showers';
    if (code >= 95 && code <= 99) return 'Thunderstorm';
    return 'Unknown';
  }

  /// Fetch multi-day forecast for a station
  Future<List<WeatherData>> getForecastForStation(
    GaugeStation station, {
    int days = 3,
  }) async {
    // Try each CORS proxy until one works
    for (int i = 0; i < _corsProxies.length; i++) {
      final proxyIndex = (_currentProxyIndex + i) % _corsProxies.length;
      final proxy = _corsProxies[proxyIndex];

      try {
        final url = Uri.parse(_baseUrl).replace(
          queryParameters: {
            'latitude': station.latitude.toString(),
            'longitude': station.longitude.toString(),
            'daily': 'temperature_2m_max,weather_code,precipitation_sum',
            'temperature_unit': 'celsius',
            'precipitation_unit': 'mm',
            'forecast_days': days.toString(),
          },
        );

        final proxiedUrl = '$proxy${Uri.encodeComponent(url.toString())}';

        final response = await http
            .get(Uri.parse(proxiedUrl))
            .timeout(const Duration(seconds: 10));

        if (response.statusCode != 200) {
          continue;
        }

        final data = json.decode(response.body) as Map<String, dynamic>;
        final daily = data['daily'] as Map<String, dynamic>;
        final times = (daily['time'] as List).cast<String>();
        final temps = (daily['temperature_2m_max'] as List).cast<num>();
        final codes = (daily['weather_code'] as List).cast<int>();
        final precip = (daily['precipitation_sum'] as List).cast<num>();

        final forecasts = <WeatherData>[];
        for (var i = 0; i < times.length; i++) {
          forecasts.add(
            WeatherData(
              latitude: station.latitude,
              longitude: station.longitude,
              temperature: temps[i].toDouble(),
              conditions: _weatherCodeToConditions(codes[i]),
              precipitation: precip[i].toDouble(),
              forecastTime: DateTime.parse(times[i]),
              temperatureUnit: 'C',
            ),
          );
        }

        // Remember working proxy
        _currentProxyIndex = proxyIndex;
        debugPrint('Weather Forecast: ✅ Success via proxy ${proxyIndex + 1}');
        return forecasts;
      } catch (e) {
        continue;
      }
    }

    debugPrint('Weather Forecast: ❌ All CORS proxies failed');
    return [];
  }
}
