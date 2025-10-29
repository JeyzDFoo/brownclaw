import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/gauge_station.dart';
import '../models/weather_data.dart';
import '../services/weather_service.dart';

/// Provider for weather data
/// Manages fetching and caching of weather data from Open-Meteo API
/// Includes persistent storage across app sessions
class WeatherProvider extends ChangeNotifier {
  final WeatherService _weatherService = WeatherService();

  // Cache for current weather per station
  final Map<String, WeatherData?> _currentWeatherCache = {};
  final Map<String, DateTime> _currentWeatherCacheTime = {};

  // Cache for forecast data per station
  final Map<String, List<WeatherData>> _forecastCache = {};
  final Map<String, DateTime> _forecastCacheTime = {};

  // Loading states per station
  final Map<String, bool> _loadingStates = {};
  final Map<String, String?> _errors = {};

  // Initialization state
  bool _isInitialized = false;

  // Cache timeout
  static const Duration _cacheDuration = Duration(minutes: 30);

  // Persistent storage keys
  static const String _prefixCurrent = 'weather_current_';
  static const String _prefixCurrentTime = 'weather_current_time_';
  static const String _prefixForecast = 'weather_forecast_';
  static const String _prefixForecastTime = 'weather_forecast_time_';

  WeatherProvider() {
    _initializeCache();
  }

  /// Initialize cache by loading from persistent storage
  Future<void> _initializeCache() async {
    if (_isInitialized) return;

    try {
      if (kDebugMode) {
        print('🔄 Loading weather cache from storage...');
      }

      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      // Load current weather cache
      for (final key in keys) {
        if (key.startsWith(_prefixCurrent) && !key.contains('time_')) {
          final cacheKey = key.substring(_prefixCurrent.length);
          final value = prefs.getString(key);
          if (value != null) {
            try {
              final Map<String, dynamic> json = jsonDecode(value);
              _currentWeatherCache[cacheKey] = WeatherData.fromMap(json);
            } catch (e) {
              if (kDebugMode) {
                print('⚠️ Skipping invalid cache entry: $cacheKey');
              }
            }
          }
        } else if (key.startsWith(_prefixCurrentTime)) {
          final cacheKey = key.substring(_prefixCurrentTime.length);
          final value = prefs.getString(key);
          if (value != null) {
            try {
              _currentWeatherCacheTime[cacheKey] = DateTime.parse(value);
            } catch (e) {
              if (kDebugMode) {
                print('⚠️ Skipping invalid timestamp: $cacheKey');
              }
            }
          }
        } else if (key.startsWith(_prefixForecast) && !key.contains('time_')) {
          final cacheKey = key.substring(_prefixForecast.length);
          final value = prefs.getString(key);
          if (value != null) {
            try {
              final List<dynamic> jsonList = jsonDecode(value);
              _forecastCache[cacheKey] = jsonList
                  .map(
                    (json) => WeatherData.fromMap(json as Map<String, dynamic>),
                  )
                  .toList();
            } catch (e) {
              if (kDebugMode) {
                print('⚠️ Skipping invalid forecast: $cacheKey');
              }
            }
          }
        } else if (key.startsWith(_prefixForecastTime)) {
          final cacheKey = key.substring(_prefixForecastTime.length);
          final value = prefs.getString(key);
          if (value != null) {
            try {
              _forecastCacheTime[cacheKey] = DateTime.parse(value);
            } catch (e) {
              if (kDebugMode) {
                print('⚠️ Skipping invalid timestamp: $cacheKey');
              }
            }
          }
        }
      }

      if (kDebugMode) {
        print('✅ Loaded ${_currentWeatherCache.length} weather cache entries');
      }

      _isInitialized = true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing weather cache: $e');
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
        print('💾 WeatherProvider: Starting save to storage...');
      }

      final prefs = await SharedPreferences.getInstance();

      // Save current weather cache
      int currentCount = 0;
      for (final entry in _currentWeatherCache.entries) {
        if (entry.value != null) {
          final key = _prefixCurrent + entry.key;
          await prefs.setString(key, jsonEncode(entry.value!.toMap()));
          currentCount++;

          if (kDebugMode) {
            print('💾   Saved current weather: ${entry.key}');
          }
        }
      }

      // Save current weather timestamps
      for (final entry in _currentWeatherCacheTime.entries) {
        await prefs.setString(
          _prefixCurrentTime + entry.key,
          entry.value.toIso8601String(),
        );
      }

      // Save forecast cache
      int forecastCount = 0;
      for (final entry in _forecastCache.entries) {
        final key = _prefixForecast + entry.key;
        await prefs.setString(
          key,
          jsonEncode(entry.value.map((w) => w.toMap()).toList()),
        );
        forecastCount++;

        if (kDebugMode) {
          print(
            '💾   Saved forecast: ${entry.key} (${entry.value.length} days)',
          );
        }
      }

      // Save forecast timestamps
      for (final entry in _forecastCacheTime.entries) {
        await prefs.setString(
          _prefixForecastTime + entry.key,
          entry.value.toIso8601String(),
        );
      }

      if (kDebugMode) {
        print(
          '✅ WeatherProvider: Saved $currentCount current, $forecastCount forecast entries to storage',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error saving weather cache: $e');
      }
    }
  }

  /// Check if a station is currently loading
  bool isLoading(String stationId) => _loadingStates[stationId] ?? false;

  /// Get error for a station
  String? getError(String stationId) => _errors[stationId];

  /// Get current weather for a station
  WeatherData? getCurrentWeather(String stationId) =>
      _currentWeatherCache[stationId];

  /// Get forecast for a station
  List<WeatherData> getForecast(String stationId) =>
      _forecastCache[stationId] ?? [];

  /// Fetch current weather for a gauge station
  /// [station] - Station to fetch weather for
  /// [forceRefresh] - Bypass cache and fetch fresh data
  Future<WeatherData?> fetchWeatherForStation(
    GaugeStation station, {
    bool forceRefresh = false,
  }) async {
    // Ensure cache is loaded from storage
    await ensureInitialized();

    // Check cache
    if (!forceRefresh) {
      final cached = _currentWeatherCache[station.stationId];
      final cacheTime = _currentWeatherCacheTime[station.stationId];

      if (cached != null && cacheTime != null) {
        final age = DateTime.now().difference(cacheTime);
        if (age < _cacheDuration) {
          if (kDebugMode) {
            print(
              '💾 WeatherProvider: Cache hit for current weather ${station.stationId}',
            );
          }
          return cached;
        }
      }
    }

    try {
      if (kDebugMode) {
        print(
          '🌐 WeatherProvider: Fetching current weather for ${station.stationId}',
        );
      }

      final result = await _weatherService.getWeatherForStation(station);

      if (kDebugMode) {
        print(
          '✅ WeatherProvider: Got current weather, caching for ${station.stationId}',
        );
      }

      // Cache the result in memory
      _currentWeatherCache[station.stationId] = result;
      _currentWeatherCacheTime[station.stationId] = DateTime.now();

      // Save to persistent storage (AWAIT to ensure it completes)
      await _saveToStorage();

      return result;
    } catch (e) {
      if (kDebugMode) {
        print('❌ WeatherProvider: Error fetching current weather: $e');
      }

      rethrow;
    }
  }

  /// Fetch weather forecast for a gauge station
  /// [station] - Station to fetch forecast for
  /// [days] - Number of days to forecast (default: 3)
  /// [forceRefresh] - Bypass cache and fetch fresh data
  Future<List<WeatherData>> fetchForecastForStation(
    GaugeStation station, {
    int days = 3,
    bool forceRefresh = false,
  }) async {
    // Ensure cache is loaded from storage
    await ensureInitialized();

    final cacheKey = '${station.stationId}_forecast_$days';

    // Check cache
    if (!forceRefresh) {
      final cached = _forecastCache[cacheKey];
      final cacheTime = _forecastCacheTime[cacheKey];

      if (cached != null && cacheTime != null) {
        final age = DateTime.now().difference(cacheTime);
        if (age < _cacheDuration) {
          if (kDebugMode) {
            print('💾 WeatherProvider: Cache hit for forecast $cacheKey');
          }
          return cached;
        }
      }
    }

    try {
      if (kDebugMode) {
        print('🌐 WeatherProvider: Fetching forecast for ${station.stationId}');
      }

      final result = await _weatherService.getForecastForStation(
        station,
        days: days,
      );

      if (kDebugMode) {
        print(
          '✅ WeatherProvider: Got forecast (${result.length} days), caching for ${station.stationId}',
        );
      }

      // Cache the result in memory
      _forecastCache[cacheKey] = result;
      _forecastCacheTime[cacheKey] = DateTime.now();

      // Save to persistent storage (AWAIT to ensure it completes)
      await _saveToStorage();

      return result;
    } catch (e) {
      if (kDebugMode) {
        print('❌ WeatherProvider: Error fetching forecast: $e');
      }

      rethrow;
    }
  }

  /// Fetch both current weather and forecast in a single call
  /// Returns a map with 'current' and 'forecast' keys
  /// [station] - Station to fetch weather for
  /// [forecastDays] - Number of days to forecast (default: 5)
  /// [forceRefresh] - Bypass cache and fetch fresh data
  Future<Map<String, dynamic>> fetchAllWeather(
    GaugeStation station, {
    int forecastDays = 5,
    bool forceRefresh = false,
  }) async {
    try {
      final results = await Future.wait([
        fetchWeatherForStation(station, forceRefresh: forceRefresh),
        fetchForecastForStation(
          station,
          days: forecastDays,
          forceRefresh: forceRefresh,
        ),
      ]);

      return {'current': results[0], 'forecast': results[1]};
    } catch (e) {
      if (kDebugMode) {
        print('❌ WeatherProvider: Error fetching all weather: $e');
      }
      rethrow;
    }
  }

  /// Clear cache for a specific station or all stations
  void clearCache([String? stationId]) {
    if (stationId != null) {
      // Clear specific station cache
      _currentWeatherCache.remove(stationId);
      _currentWeatherCacheTime.remove(stationId);
      _forecastCache.removeWhere((key, _) => key.startsWith(stationId));
      _forecastCacheTime.removeWhere((key, _) => key.startsWith(stationId));
      _loadingStates.remove(stationId);
      _errors.remove(stationId);

      if (kDebugMode) {
        print('🗑️ WeatherProvider: Cleared cache for $stationId');
      }
    } else {
      // Clear all caches
      _currentWeatherCache.clear();
      _currentWeatherCacheTime.clear();
      _forecastCache.clear();
      _forecastCacheTime.clear();
      _loadingStates.clear();
      _errors.clear();

      if (kDebugMode) {
        print('🗑️ WeatherProvider: Cleared all caches');
      }
    }

    notifyListeners();
  }
}
