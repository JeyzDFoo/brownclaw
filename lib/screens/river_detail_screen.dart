import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../services/live_water_data_service.dart';
import '../services/historical_water_data_service.dart';
import '../services/river_run_service.dart';
import '../services/river_service.dart';
import '../services/analytics_service.dart';
import '../services/gauge_station_service.dart';
import '../services/weather_service.dart';
import '../models/models.dart'; // Import LiveWaterData model
import '../providers/providers.dart';
import '../widgets/transalta_flow_widget.dart';
import '../widgets/user_runs_history_widget.dart';
import '../widgets/weather_forecast_widget.dart';
import 'edit_river_run_screen.dart';
import 'premium_purchase_screen.dart';
import 'logbook_entry_screen.dart';

class RiverDetailScreen extends StatefulWidget {
  final Map<String, dynamic> riverData;

  const RiverDetailScreen({super.key, required this.riverData});

  @override
  State<RiverDetailScreen> createState() => _RiverDetailScreenState();
}

class _RiverDetailScreenState extends State<RiverDetailScreen> {
  LiveWaterData? _liveData;
  List<FlSpot> _historicalData = [];
  Map<String, dynamic>? _flowStatistics;
  Map<String, dynamic>? _recentTrend;
  bool _isLoading = true;
  bool _isLoadingChart = true;
  bool _isLoadingStats = true;
  String? _error;
  String? _chartError;
  int _selectedDays = 3; // Default to 3 days of historical data
  int?
  _selectedYear; // null means current/combined data, otherwise specific year

  // Stream subscription for real-time river run updates
  StreamSubscription<RiverRun?>? _runSubscription;
  Map<String, dynamic> _currentRiverData = {};

  // Logbook stats
  int _totalRuns = 0;
  DateTime? _lastRanDate;

  // Weather data
  final WeatherService _weatherService = WeatherService();
  List<WeatherData> _weatherForecast = [];
  WeatherData? _currentWeather;
  bool _isLoadingWeather = false;
  String? _weatherError;

  @override
  void initState() {
    super.initState();
    _currentRiverData = Map<String, dynamic>.from(widget.riverData);
    _setupRunStream();
    _loadLogbookStats();
    _loadLiveData();
    _loadHistoricalData();
    _loadStatisticsData();
    _loadWeatherData();
  }

  @override
  void dispose() {
    _runSubscription?.cancel();
    super.dispose();
  }

  /// Set up Firestore stream to watch for river run changes
  void _setupRunStream() {
    final runId = widget.riverData['runId'] as String?;
    if (runId == null || runId.isEmpty) {
      if (kDebugMode) {
        print('No runId found in riverData, skipping stream setup');
      }
      return;
    }

    _runSubscription = RiverRunService.watchRunById(runId).listen((run) {
      if (run != null && mounted) {
        setState(() {
          // Update the difficulty and other run details in the current data
          _currentRiverData['difficulty'] = run.difficultyClass;
          _currentRiverData['section'] = {
            'name': run.name,
            'difficulty': run.difficultyClass,
          };
          _currentRiverData['minRunnable'] = run.minRecommendedFlow ?? 0.0;
          _currentRiverData['maxSafe'] = run.maxRecommendedFlow ?? 1000.0;
          _currentRiverData['location'] = run.putIn ?? 'Unknown Location';
        });
      }
    });
  }

  /// Check if this is a Kananaskis river (for TransAlta widget display)
  bool _isKananaskisRiver(String riverName) {
    final lower = riverName.toLowerCase();
    return lower.contains('kananaskis') ||
        lower.contains('kan') ||
        lower == 'upper kan';
  }

  /// Validates if the river has a valid station ID for data fetching
  String? _validateStationData() {
    final stationId = widget.riverData['stationId'] as String?;
    final hasValidStation =
        widget.riverData['hasValidStation'] as bool? ?? false;

    if (stationId == null || stationId.isEmpty) {
      return 'No gauge station linked to this river run';
    }

    // Allow TransAlta station IDs (contains underscores) and Gov of Canada IDs (alphanumeric only)
    if (!hasValidStation ||
        !RegExp(r'^[A-Z0-9_]+$').hasMatch(stationId.toUpperCase())) {
      return 'This river run is not connected to a real-time gauge station.\n\nStation ID: $stationId';
    }

    return null; // Valid station
  }

  @override
  void didUpdateWidget(RiverDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Check if the river data has changed
    if (oldWidget.riverData['stationId'] != widget.riverData['stationId']) {
      // Clear previous data and reload for new river
      setState(() {
        _liveData = null;
        _historicalData = [];
        _flowStatistics = null;
        _recentTrend = null;
        _isLoading = true;
        _isLoadingChart = true;
        _isLoadingStats = true;
        _error = null;
        _chartError = null;
        _currentWeather = null;
        _weatherForecast = [];
        _isLoadingWeather = true;
        _weatherError = null;
      });
      _loadLiveData();
      _loadHistoricalData();
      _loadStatisticsData();
      _loadWeatherData();
    }
  }

  Future<void> _loadLiveData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final validationError = _validateStationData();
      if (validationError != null) {
        setState(() {
          _error = validationError;
          _isLoading = false;
        });
        return;
      }

      final stationId = widget.riverData['stationId'] as String;
      final liveData = await LiveWaterDataService.fetchStationData(stationId);

      if (mounted) {
        setState(() {
          _liveData = liveData;
          _isLoading = false;
          if (liveData == null) {
            _error = 'No real-time data available for station $stationId';
          }
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading live data: $e');
      }
      if (mounted) {
        setState(() {
          _error = 'Failed to load real-time data: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadHistoricalData() async {
    setState(() {
      _isLoadingChart = true;
      _chartError = null;
    });

    try {
      final validationError = _validateStationData();
      if (validationError != null) {
        setState(() {
          _chartError = validationError;
          _isLoadingChart = false;
        });
        return;
      }

      final stationId = widget.riverData['stationId'] as String;
      final historicalData = await _fetchHistoricalData(stationId);

      if (kDebugMode) {
        print(
          '✅ _loadHistoricalData completed: ${historicalData.length} data points',
        );
      }

      if (mounted) {
        setState(() {
          _historicalData = historicalData;
          _isLoadingChart = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ _loadHistoricalData error: $e');
      }
      if (mounted) {
        setState(() {
          _chartError = e.toString();
          _isLoadingChart = false;
        });
      }
    }
  }

  Future<List<FlSpot>> _fetchHistoricalData(String stationId) async {
    try {
      if (kDebugMode) {
        print(
          '🔍 Fetching data for station: $stationId, days: $_selectedDays, year: $_selectedYear',
        );
      }

      List<Map<String, dynamic>> dataPoints = [];

      // For very short ranges (14 days or less), use high-resolution real-time data
      if (_selectedDays <= 14) {
        if (kDebugMode) {
          print(
            '📊 Using high-resolution real-time data for $_selectedDays days',
          );
        }

        dataPoints = await _fetchHighResolutionData(stationId, _selectedDays);
      }
      // For medium ranges (8-30 days), use combined timeline with daily averages
      else if (_selectedDays <= 30) {
        if (kDebugMode) {
          print('📊 Using combined timeline for $_selectedDays days');
        }

        final combinedResult =
            await HistoricalWaterDataService.getCombinedTimeline(
              stationId,
              includeRealtimeData: true,
            );

        final combined =
            combinedResult['combined'] as List<Map<String, dynamic>>;

        // Take only the last N days from the combined data
        if (combined.isNotEmpty) {
          // Sort by date (most recent first)
          combined.sort(
            (a, b) => (b['date'] as String).compareTo(a['date'] as String),
          );

          // Take the requested number of days
          dataPoints = combined.take(_selectedDays).toList();

          // Reverse back to chronological order for charting
          dataPoints = dataPoints.reversed.toList();
        }
      } else {
        if (kDebugMode) {
          print(
            '📊 Fetching data for $_selectedDays days, year: $_selectedYear (null means current/2024)',
          );
        }

        // Check if viewing a specific historical year
        if (_selectedYear != null) {
          if (kDebugMode) {
            print('📅 Fetching historical year data for $_selectedYear');
          }
          // Fetch specific year from historical API
          dataPoints = await HistoricalWaterDataService.fetchHistoricalData(
            stationId,
            year: _selectedYear,
          );

          if (kDebugMode) {
            print(
              '📅 Got ${dataPoints.length} data points for year $_selectedYear',
            );
          }
        } else {
          if (kDebugMode) {
            print('📅 Fetching combined timeline for current data');
          }
          // Default: use combined timeline for current data
          final combinedResult =
              await HistoricalWaterDataService.getCombinedTimeline(
                stationId,
                includeRealtimeData: true,
              );

          final combined =
              combinedResult['combined'] as List<Map<String, dynamic>>;

          if (combined.isNotEmpty) {
            // Sort by date (most recent first)
            combined.sort(
              (a, b) => (b['date'] as String).compareTo(a['date'] as String),
            );

            // Take only the last N days
            dataPoints = combined.take(_selectedDays).toList();

            // Reverse for charting (oldest first)
            dataPoints = dataPoints.reversed.toList();
          }
        }
      }

      if (kDebugMode) {
        print('📊 Received ${dataPoints.length} data points');
        if (dataPoints.isNotEmpty) {
          print('   First data point: ${dataPoints.first}');
          print('   Last data point: ${dataPoints.last}');

          // Show source information for debugging
          final sources = dataPoints
              .map((d) => d['source'] ?? 'historical')
              .toSet();
          print('   Data sources: ${sources.join(', ')}');
        }
      }

      final spots = <FlSpot>[];

      for (final dataPoint in dataPoints) {
        // Handle both high-resolution (datetime) and daily (date) data
        final dateStr =
            dataPoint['datetime'] as String? ?? dataPoint['date'] as String?;
        final discharge = dataPoint['discharge'] as double?;

        if (dateStr != null && discharge != null) {
          final date = DateTime.parse(dateStr);
          final timestamp = date.millisecondsSinceEpoch.toDouble();
          spots.add(FlSpot(timestamp, discharge));
        } else if (kDebugMode && dataPoints.length < 10) {
          // Debug: show why data points are being skipped (only for small datasets)
          print(
            '⚠️ Skipping data point: dateStr=$dateStr, discharge=$discharge',
          );
        }
      }

      // Sort by timestamp
      spots.sort((a, b) => a.x.compareTo(b.x));

      if (kDebugMode) {
        print(
          '✅ Created ${spots.length} chart data points from ${dataPoints.length} raw data points',
        );
        if (spots.isEmpty && dataPoints.isNotEmpty) {
          print('⚠️ WARNING: Had data points but created 0 chart spots!');
          print('   First data point keys: ${dataPoints.first.keys.toList()}');
          print('   First data point: ${dataPoints.first}');
        }
      }

      return spots;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching historical data: $e');
      }
      rethrow;
    }
  }

  /// Fetch high-resolution real-time data (5-minute intervals) for short time periods
  Future<List<Map<String, dynamic>>> _fetchHighResolutionData(
    String stationId,
    int days,
  ) async {
    try {
      if (kDebugMode) {
        print('🔍 Fetching high-resolution data for $days days');
      }

      // Fetch raw real-time data (not daily averages)
      final url =
          'https://api.weather.gc.ca/collections/hydrometric-realtime/items?'
          'STATION_NUMBER=$stationId&'
          'limit=${days * 288}&' // 288 records per day (5-minute intervals)
          'sortby=-DATETIME&' // Sort descending (newest first) to get most recent data
          'f=json';

      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List? ?? [];

        final highResData = <Map<String, dynamic>>[];

        for (final feature in features) {
          final props = feature['properties'];
          if (props != null) {
            final datetime = props['DATETIME'] as String?;
            final discharge = props['DISCHARGE'];
            final level = props['LEVEL'];

            if (datetime != null && discharge != null) {
              highResData.add({
                'datetime': datetime,
                'discharge': discharge is num
                    ? discharge.toDouble()
                    : double.tryParse(discharge.toString()),
                'level': level is num
                    ? level.toDouble()
                    : (level != null
                          ? double.tryParse(level.toString())
                          : null),
                'stationId': stationId,
                'source': 'realtime-highres',
              });
            }
          }
        }

        // Filter to exactly the requested number of days from most recent
        if (highResData.isNotEmpty) {
          // Sort by datetime (most recent first)
          highResData.sort(
            (a, b) =>
                (b['datetime'] as String).compareTo(a['datetime'] as String),
          );

          // Calculate cutoff datetime for requested days
          final mostRecent = DateTime.parse(
            highResData.first['datetime'] as String,
          );
          final cutoffTime = mostRecent.subtract(Duration(days: days));

          // Filter to only include data within the requested time window
          final filteredData = highResData.where((d) {
            final dt = DateTime.parse(d['datetime'] as String);
            return dt.isAfter(cutoffTime);
          }).toList();

          // Reverse to chronological order for charting
          filteredData.sort(
            (a, b) =>
                (a['datetime'] as String).compareTo(b['datetime'] as String),
          );

          if (kDebugMode) {
            print('✅ Got ${filteredData.length} high-resolution data points');
            if (filteredData.isNotEmpty) {
              print(
                '   Time range: ${filteredData.first['datetime']} to ${filteredData.last['datetime']}',
              );
            }
          }

          return filteredData;
        }
      }

      if (kDebugMode) {
        print(
          '⚠️ No high-resolution data available, falling back to daily averages',
        );
      }

      return [];
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching high-resolution data: $e');
      }
      return [];
    }
  }

  Future<void> _loadStatisticsData() async {
    setState(() {
      _isLoadingStats = true;
    });

    try {
      final validationError = _validateStationData();
      if (validationError != null) {
        setState(() {
          _isLoadingStats = false;
        });
        return;
      }

      final stationId = widget.riverData['stationId'] as String;

      // Use different data resolution based on time range
      Map<String, dynamic> flowStats;

      if (_selectedDays <= 14) {
        // For very short ranges, use high-resolution data for better statistics
        final highResData = await _fetchHighResolutionData(
          stationId,
          _selectedDays,
        );

        if (highResData.isNotEmpty) {
          flowStats = _calculateStatsFromData(highResData);
        } else {
          // Fallback to combined timeline if high-res fails
          final combinedResult =
              await HistoricalWaterDataService.getCombinedTimeline(
                stationId,
                includeRealtimeData: true,
              );
          final combined =
              combinedResult['combined'] as List<Map<String, dynamic>>;

          if (combined.isNotEmpty) {
            combined.sort(
              (a, b) => (b['date'] as String).compareTo(a['date'] as String),
            );
            final recentData = combined.take(_selectedDays).toList();
            flowStats = _calculateStatsFromData(recentData);
          } else {
            flowStats = {'error': 'No data available', 'count': 0};
          }
        }
      } else if (_selectedDays <= 30) {
        // For medium ranges, use combined timeline with daily averages
        final combinedResult =
            await HistoricalWaterDataService.getCombinedTimeline(
              stationId,
              includeRealtimeData: true,
            );
        final combined =
            combinedResult['combined'] as List<Map<String, dynamic>>;

        if (combined.isNotEmpty) {
          // Take last N days and calculate statistics
          combined.sort(
            (a, b) => (b['date'] as String).compareTo(a['date'] as String),
          );
          final recentData = combined.take(_selectedDays).toList();

          flowStats = _calculateStatsFromData(recentData);
        } else {
          flowStats = {'error': 'No data available', 'count': 0};
        }
      } else {
        // Check if viewing a specific historical year
        if (_selectedYear != null) {
          // Use historical API for specific year
          flowStats = await HistoricalWaterDataService.getFlowStatistics(
            stationId,
            year: _selectedYear,
          );
        } else {
          // Default: use combined timeline
          final combinedResult =
              await HistoricalWaterDataService.getCombinedTimeline(
                stationId,
                includeRealtimeData: true,
              );
          final combined =
              combinedResult['combined'] as List<Map<String, dynamic>>;

          if (combined.isNotEmpty) {
            // Take last N days
            combined.sort(
              (a, b) => (b['date'] as String).compareTo(a['date'] as String),
            );
            final recentData = combined.take(_selectedDays).toList();

            flowStats = _calculateStatsFromData(recentData);
          } else {
            flowStats = {'error': 'No data available', 'count': 0};
          }
        }
      }

      // Load recent trend (always use historical service for this)
      final recentTrend = await HistoricalWaterDataService.getRecentTrend(
        stationId,
      );

      if (mounted) {
        setState(() {
          _flowStatistics = flowStats;
          _recentTrend = recentTrend;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
        });
      }
    }
  }

  Future<void> _loadLogbookStats() async {
    final user = context.read<UserProvider>().user;
    if (user == null) {
      if (kDebugMode) {
        print('🚫 _loadLogbookStats: No user authenticated');
      }
      return;
    }

    final runId = widget.riverData['runId'] as String?;
    if (runId == null || runId.isEmpty) {
      if (kDebugMode) {
        print('🚫 _loadLogbookStats: No runId found');
      }
      return;
    }

    try {
      if (kDebugMode) {
        print(
          '🔍 Loading logbook stats for runId: $runId, userId: ${user.uid}',
        );
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('river_descents')
          .where('userId', isEqualTo: user.uid)
          .where('riverRunId', isEqualTo: runId)
          .orderBy('timestamp', descending: true)
          .get();

      if (mounted) {
        setState(() {
          _totalRuns = snapshot.docs.length;
          if (snapshot.docs.isNotEmpty) {
            final mostRecent = RiverDescent.fromMap(
              snapshot.docs.first.data(),
              docId: snapshot.docs.first.id,
            );
            _lastRanDate = mostRecent.timestamp;
          }
        });

        if (kDebugMode) {
          print(
            '✅ Logbook stats loaded: $_totalRuns runs, last ran: $_lastRanDate',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading logbook stats: $e');
      }
    }
  }

  Future<void> _loadWeatherData() async {
    setState(() {
      _isLoadingWeather = true;
      _weatherError = null;
    });

    try {
      // Get the station ID from river data
      final stationId = widget.riverData['stationId'] as String?;
      if (stationId == null || stationId.isEmpty) {
        setState(() {
          _weatherError = 'No station linked';
          _isLoadingWeather = false;
        });
        return;
      }

      // Fetch the gauge station to get GPS coordinates
      final station = await GaugeStationService.getStationById(stationId);
      if (station == null) {
        setState(() {
          _weatherError = 'Station not found';
          _isLoadingWeather = false;
        });
        return;
      }

      if (kDebugMode) {
        print(
          '🌤️ Loading weather for station ${station.name} at ${station.latitude}, ${station.longitude}',
        );
      }

      // Fetch current weather and 5-day forecast in parallel
      final results = await Future.wait([
        _weatherService.getWeatherForStation(station),
        _weatherService.getForecastForStation(station, days: 5),
      ]);

      final currentWeather = results[0] as WeatherData?;
      final forecast = results[1] as List<WeatherData>;

      if (mounted) {
        setState(() {
          _currentWeather = currentWeather;
          _weatherForecast = forecast;
          _isLoadingWeather = false;
          if (forecast.isEmpty && currentWeather == null) {
            _weatherError = 'Weather data unavailable';
          }
        });

        if (kDebugMode) {
          print(
            '✅ Weather loaded: current=${currentWeather != null}, ${forecast.length} days forecast',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading weather: $e');
      }
      if (mounted) {
        setState(() {
          _weatherError = 'Failed to load weather';
          _isLoadingWeather = false;
        });
      }
    }
  }

  Future<void> _refreshAllData() async {
    await Future.wait([
      _loadLiveData(),
      _loadHistoricalData(),
      _loadStatisticsData(),
      _loadWeatherData(),
    ]);
  }

  Future<void> _changeDaysRange(int newDays) async {
    if (newDays == _selectedDays) return;

    // Log chart time range change
    final runId = widget.riverData['runId'] as String? ?? 'unknown';
    await AnalyticsService.logChartTimeRangeChanged(newDays, runId);

    setState(() {
      _selectedDays = newDays;
      _isLoadingChart = true;
      _isLoadingStats = true;
    });

    await Future.wait([_loadHistoricalData(), _loadStatisticsData()]);
  }

  Future<void> _changeYear(int? newYear) async {
    if (newYear == _selectedYear) return;

    setState(() {
      _selectedYear = newYear;
      _isLoadingChart = true;
      _isLoadingStats = true;
    });

    await Future.wait([_loadHistoricalData(), _loadStatisticsData()]);
  }

  void _showPremiumDialog(BuildContext context) {
    // Log premium paywall view
    AnalyticsService.logPremiumPaywallViewed(
      'historical_data_${_selectedDays}_days',
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.workspace_premium, color: Colors.amber),
              SizedBox(width: 8),
              Text('Premium Feature'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Unlock extended historical data views with Premium!',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text('Premium features include:'),
              const SizedBox(height: 8),
              _buildFeatureItem('📊 14-day historical view'),
              _buildFeatureItem('📈 30-day historical view'),
              _buildFeatureItem('📉 Full year (365-day) view'),
              _buildFeatureItem('🎯 Advanced analytics'),
              const SizedBox(height: 16),
              const Text(
                'Free users get 3-day historical data.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Maybe Later'),
            ),
            ElevatedButton(
              onPressed: () {
                // Log premium purchase initiated from paywall
                AnalyticsService.logPurchaseInitiated('monthly_premium', 2.29);

                Navigator.of(context).pop();
                // Navigate to premium purchase page
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const PremiumPurchaseScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
              ),
              child: const Text('Upgrade to Premium'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 4),
      child: Text(text, style: const TextStyle(fontSize: 14)),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'runnable':
      case 'good':
        return Colors.green;
      case 'too low':
      case 'low':
        return Colors.orange;
      case 'too high':
      case 'high':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'runnable':
      case 'good':
        return Icons.check_circle;
      case 'too low':
      case 'low':
        return Icons.trending_down;
      case 'too high':
      case 'high':
        return Icons.trending_up;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Safely extract data with null checks and error handling
    String riverName;
    String stationId;
    String location;
    String section;
    String sectionClass;
    String difficulty;
    String status;

    try {
      riverName = _currentRiverData['riverName'] as String? ?? 'Unknown River';
      stationId = _currentRiverData['stationId'] as String? ?? 'Unknown';
      location = _currentRiverData['location'] as String? ?? 'Unknown Location';

      // Handle section data (could be Map or String for backward compatibility)
      final sectionData = _currentRiverData['section'];
      section = sectionData is Map<String, dynamic>
          ? (sectionData['name'] as String? ?? '')
          : (sectionData as String? ?? '');
      sectionClass = sectionData is Map<String, dynamic>
          ? (sectionData['difficulty'] as String? ?? 'Unknown')
          : (_currentRiverData['difficulty'] as String? ?? 'Unknown');

      difficulty = _currentRiverData['difficulty'] as String? ?? 'Unknown';
      status = _currentRiverData['status'] as String? ?? 'Unknown';

      if (kDebugMode) {
        print(
          'Successfully parsed river data: riverName=$riverName, stationId=$stationId',
        );
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Error parsing river data: $e');
        print('Stack trace: $stackTrace');
      }

      // Return an error screen if data parsing fails
      return Scaffold(
        appBar: AppBar(
          title: const Text('Data Error'),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Error loading river data',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('Error: $e'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(riverName),
        actions: [
          // Edit button - only visible to admins
          Consumer<UserProvider>(
            builder: (context, userProvider, child) {
              if (!userProvider.isAdmin) return const SizedBox.shrink();

              return IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Edit Run Details',
                onPressed: () async {
                  // Log river run edit action
                  final runId =
                      widget.riverData['runId'] as String? ?? 'unknown';
                  await AnalyticsService.logRiverRunEdited(runId);

                  final result = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (context) =>
                          EditRiverRunScreen(riverData: widget.riverData),
                    ),
                  );

                  // Refresh data if changes were made
                  if (result == true && mounted) {
                    _refreshAllData();
                  }
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshAllData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAllData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card with Status
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            _getStatusIcon(status),
                            color: _getStatusColor(status),
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (section.isNotEmpty)
                                  Text(
                                    '$section ($sectionClass)',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                if (section.isEmpty &&
                                    sectionClass != 'Unknown')
                                  Text(
                                    sectionClass,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                              ],
                            ),
                          ),
                          // Logbook stats - top right
                          if (_totalRuns > 0)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.event,
                                      size: 14,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _lastRanDate != null
                                          ? _formatDate(_lastRanDate!)
                                          : 'Never',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.format_list_numbered,
                                      size: 14,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$_totalRuns ${_totalRuns == 1 ? 'run' : 'runs'}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            color: Colors.grey[600],
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              location,
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (difficulty != 'Unknown')
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              Icon(
                                Icons.trending_up,
                                color: Colors.grey[600],
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Difficulty: $difficulty',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      // Show flow recommendations if available
                      if (_currentRiverData['minRunnable'] != null &&
                          _currentRiverData['maxSafe'] != null &&
                          _currentRiverData['minRunnable'] > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              Icon(
                                Icons.water_drop,
                                color: Colors.blue[600],
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Recommended flow: ${_currentRiverData['minRunnable']}-${_currentRiverData['maxSafe']} m³/s',
                                  style: TextStyle(
                                    color: Colors.blue[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Current Conditions Card - Hidden for Kananaskis (uses TransAlta widget instead)
              if (!_isKananaskisRiver(riverName))
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Conditions',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),

                        if (_isLoading)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20.0),
                              child: CircularProgressIndicator(
                                color: Colors.teal,
                              ),
                            ),
                          )
                        else if (_error != null)
                          Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Colors.red[300],
                                  size: 48,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Error loading live data',
                                  style: TextStyle(color: Colors.red[600]),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _error!,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        else if (_liveData != null)
                          Column(
                            children: [
                              _buildDataRow(
                                icon: Icons.water_drop,
                                label: 'Flow Rate',
                                value: _liveData!.formattedFlowRate,
                                color: Colors.blue,
                              ),
                              const SizedBox(height: 12),
                              // Show current weather if available
                              if (_currentWeather != null) ...[
                                _buildDataRow(
                                  icon: Icons.thermostat,
                                  label: 'Temperature',
                                  value:
                                      '${_currentWeather!.temperature.toStringAsFixed(1)}°${_currentWeather!.temperatureUnit}',
                                  color: Colors.orange,
                                ),
                                const SizedBox(height: 12),
                                _buildDataRow(
                                  icon: Icons.wb_cloudy_outlined,
                                  label: 'Conditions',
                                  value: _currentWeather!.conditions,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 12),
                                if (_currentWeather!.windSpeed != null)
                                  _buildDataRow(
                                    icon: Icons.air,
                                    label: 'Wind',
                                    value:
                                        '${_currentWeather!.windSpeed!.toStringAsFixed(0)} km/h',
                                    color: Colors.teal,
                                  ),
                                if (_currentWeather!.windSpeed != null)
                                  const SizedBox(height: 12),
                              ],
                              _buildDataRow(
                                icon: Icons.schedule,
                                label: 'Last Updated',
                                value: _formatDateTime(
                                  _liveData!.timestamp.toIso8601String(),
                                ),
                                color: Colors.grey,
                              ),
                            ],
                          )
                        else
                          const Center(
                            child: Text(
                              'No live data available',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

              if (!_isKananaskisRiver(riverName)) const SizedBox(height: 16),

              // Weather Forecast Widget - Hidden for Kananaskis (uses TransAlta widget)
              if (!_isKananaskisRiver(riverName))
                WeatherForecastWidget(
                  forecast: _weatherForecast,
                  isLoading: _isLoadingWeather,
                  error: _weatherError,
                ),

              if (!_isKananaskisRiver(riverName)) const SizedBox(height: 16),

              // TransAlta Flow Widget - Special case for Kananaskis River
              if (_isKananaskisRiver(riverName))
                const TransAltaFlowWidget(threshold: 20.0),

              if (_isKananaskisRiver(riverName)) const SizedBox(height: 16),

              // Historical Discharge Chart Card - Hidden for Kananaskis (uses TransAlta widget instead)
              if (!_isKananaskisRiver(riverName))
                Card(
                  key: ValueKey('chart_card_${widget.riverData['stationId']}'),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedYear != null
                              ? 'Discharge History - $_selectedYear'
                              : 'Real-time Discharge History',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),

                        if (_isLoadingChart)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(40.0),
                              child: CircularProgressIndicator(
                                color: Colors.teal,
                              ),
                            ),
                          )
                        else if (_chartError != null)
                          Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Colors.red[300],
                                  size: 48,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Real historical data unavailable',
                                  style: TextStyle(color: Colors.red[600]),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Unable to fetch government historical data for this station',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        else if (_historicalData.isNotEmpty)
                          SizedBox(
                            height: 200,
                            child: LineChart(
                              key: ValueKey(
                                'chart_${widget.riverData['stationId']}',
                              ),
                              LineChartData(
                                gridData: FlGridData(
                                  show: true,
                                  drawHorizontalLine: true,
                                  drawVerticalLine: false,
                                  horizontalInterval: _historicalData.isNotEmpty
                                      ? (_historicalData
                                                    .map((e) => e.y)
                                                    .reduce(
                                                      (a, b) => a > b ? a : b,
                                                    ) /
                                                6)
                                            .clamp(2.0, 20.0)
                                      : 10,
                                  getDrawingHorizontalLine: (value) {
                                    return FlLine(
                                      color: Colors.grey.withOpacity(0.3),
                                      strokeWidth: 1,
                                    );
                                  },
                                ),
                                titlesData: FlTitlesData(
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 50,
                                      getTitlesWidget: (value, meta) {
                                        return Text(
                                          '${value.toInt()}',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 50,
                                      interval: _historicalData.isNotEmpty
                                          ? (_historicalData.last.x -
                                                    _historicalData.first.x) /
                                                4
                                          : null,
                                      getTitlesWidget: (value, meta) {
                                        final dateTime =
                                            DateTime.fromMillisecondsSinceEpoch(
                                              value.toInt(),
                                            );

                                        // Show actual date in MM/DD format
                                        final dateStr =
                                            '${dateTime.month.toString().padLeft(2, '0')}/${dateTime.day.toString().padLeft(2, '0')}';

                                        return Transform.rotate(
                                          angle:
                                              -0.5, // Slight angle to fit better
                                          child: Text(
                                            dateStr,
                                            style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 10,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  topTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  rightTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                ),
                                borderData: FlBorderData(
                                  show: true,
                                  border: Border.all(
                                    color: Colors.grey.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                lineTouchData: LineTouchData(
                                  enabled: true,
                                  touchTooltipData: LineTouchTooltipData(
                                    getTooltipItems: (touchedSpots) {
                                      return touchedSpots.map((touchedSpot) {
                                        final dateTime =
                                            DateTime.fromMillisecondsSinceEpoch(
                                              touchedSpot.x.toInt(),
                                            );
                                        final flow = touchedSpot.y;

                                        // Format date as "Oct 15, 2025"
                                        final months = [
                                          'Jan',
                                          'Feb',
                                          'Mar',
                                          'Apr',
                                          'May',
                                          'Jun',
                                          'Jul',
                                          'Aug',
                                          'Sep',
                                          'Oct',
                                          'Nov',
                                          'Dec',
                                        ];
                                        final formattedDate =
                                            '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';

                                        return LineTooltipItem(
                                          '$formattedDate\n${flow.toStringAsFixed(1)} cms',
                                          const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        );
                                      }).toList();
                                    },
                                  ),
                                  touchCallback:
                                      (
                                        FlTouchEvent event,
                                        LineTouchResponse? touchResponse,
                                      ) {
                                        // Optional: Add haptic feedback on touch
                                        // HapticFeedback.lightImpact();
                                      },
                                  handleBuiltInTouches: true,
                                ),
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: _historicalData,
                                    isCurved: true,
                                    color: Colors.teal,
                                    barWidth: 3,
                                    isStrokeCapRound: true,
                                    belowBarData: BarAreaData(
                                      show: true,
                                      color: Colors.teal.withOpacity(0.1),
                                    ),
                                    dotData: FlDotData(
                                      show: false,
                                      getDotPainter:
                                          (spot, percent, barData, index) {
                                            return FlDotCirclePainter(
                                              radius: 4,
                                              color: Colors.white,
                                              strokeWidth: 2,
                                              strokeColor: Colors.teal,
                                            );
                                          },
                                    ),
                                  ),
                                ],
                                minY: _historicalData.isNotEmpty
                                    ? (_historicalData
                                                  .map((e) => e.y)
                                                  .reduce(
                                                    (a, b) => a < b ? a : b,
                                                  ) *
                                              0.8)
                                          .clamp(0, double.infinity)
                                    : 0,
                                maxY: _historicalData.isNotEmpty
                                    ? _historicalData
                                              .map((e) => e.y)
                                              .reduce((a, b) => a > b ? a : b) *
                                          1.3
                                    : 80,
                              ),
                            ),
                          )
                        else
                          Center(
                            child: Padding(
                              padding: EdgeInsets.all(40.0),
                              child: Column(
                                children: [
                                  Text(
                                    _selectedYear != null
                                        ? 'No historical data available for $_selectedYear'
                                        : 'No historical data available',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                  if (_selectedYear != null) ...[
                                    SizedBox(height: 8),
                                    Text(
                                      'This station may only have real-time data',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),

                        if (_historicalData.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Discharge in cms',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Day range selector
                        const SizedBox(height: 16),
                        _buildDayRangeSelector(),

                        // Flow statistics section
                        const SizedBox(height: 16),
                        _buildFlowStatistics(),

                        // Recent trend section
                        const SizedBox(height: 16),
                        _buildRecentTrend(),
                      ],
                    ),
                  ),
                ),

              // User's historical runs on this river
              if (_currentRiverData['runId'] != null &&
                  _currentRiverData['runId'].toString().isNotEmpty)
                UserRunsHistoryWidget(
                  riverRunId: _currentRiverData['runId'] as String,
                  riverName: riverName,
                ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // Create RiverRunWithStations object to prefill the logbook entry
          final runId = widget.riverData['runId'] as String?;

          if (runId == null || runId.isEmpty) {
            // Show error if no run ID
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cannot log descent: No run ID found'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }

          // Fetch the full run details
          final run = await RiverRunService.getRunById(runId);
          if (run == null) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cannot log descent: Run details not found'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }

          // Fetch the river details
          River? river;
          try {
            river = await RiverService.getRiverById(run.riverId);
          } catch (e) {
            // River might not exist, but we can still proceed
          }

          // Create the prefilled run object
          final prefilledRun = RiverRunWithStations(
            run: run,
            river: river,
            stations: [], // Stations not needed for prefill
          );

          // Log analytics event
          final riverName =
              _currentRiverData['riverName'] as String? ?? 'Unknown River';
          await AnalyticsService.logRiverRunViewed(runId, riverName);

          // Navigate to logbook entry screen
          if (mounted) {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) =>
                    LogbookEntryScreen(prefilledRun: prefilledRun),
              ),
            );

            // Refresh logbook stats after returning
            _loadLogbookStats();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Log Descent'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildDataRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  String _formatDateTime(String? dateTimeString) {
    if (dateTimeString == null) return 'Unknown';

    try {
      final dateTime = DateTime.parse(dateTimeString);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 60) {
        return '${difference.inMinutes} min ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours} hr ago';
      } else {
        return '${difference.inDays} days ago';
      }
    } catch (e) {
      return dateTimeString;
    }
  }

  Widget _buildDayRangeSelector() {
    return Consumer<PremiumProvider>(
      builder: (context, premiumProvider, child) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Historical Data Range',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8.0,
                  children: [3, 14, 30, 365].map((days) {
                    final isSelected = days == _selectedDays;
                    final label = days == 365 ? 'Year' : '${days}d';
                    final isLocked = days != 3 && !premiumProvider.isPremium;

                    return FilterChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(label),
                          if (isLocked) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.lock, size: 14),
                          ],
                        ],
                      ),
                      selected: isSelected,
                      onSelected: isLocked
                          ? (selected) {
                              if (selected) {
                                _showPremiumDialog(context);
                              }
                            }
                          : (selected) {
                              if (selected) {
                                _changeDaysRange(days);
                              }
                            },
                      selectedColor: Colors.teal.withOpacity(0.3),
                      backgroundColor: isLocked
                          ? Colors.grey.withOpacity(0.2)
                          : Colors.grey.withOpacity(0.1),
                    );
                  }).toList(),
                ),
                if (!premiumProvider.isPremium)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      '🔒 Unlock 14, 30, and yearly views with Premium',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),

                // Year selector (only shown when 365 days is selected and user is premium)
                if (_selectedDays == 365 && premiumProvider.isPremium) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  Text(
                    'Select Year',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8.0,
                    children:
                        [
                          null,
                          DateTime.now().year - 1,
                          DateTime.now().year - 2,
                          DateTime.now().year - 3,
                          DateTime.now().year - 4,
                        ].map((year) {
                          final isSelected = year == _selectedYear;
                          final label = year == null ? 'Year' : year.toString();

                          return FilterChip(
                            label: Text(label),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                _changeYear(year);
                              }
                            },
                            selectedColor: Colors.blue.withOpacity(0.3),
                            backgroundColor: Colors.grey.withOpacity(0.1),
                          );
                        }).toList(),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'ℹ️ View historical data from previous years',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFlowStatistics() {
    if (_isLoadingStats) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(child: CircularProgressIndicator(color: Colors.teal)),
        ),
      );
    }

    if (_flowStatistics == null || _flowStatistics!.containsKey('error')) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Flow statistics unavailable',
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final stats = _flowStatistics!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _selectedYear != null
                  ? 'Flow Statistics - $_selectedYear'
                  : 'Flow Statistics (Last ${_selectedDays == 365 ? '2024' : '$_selectedDays days'})',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            _buildStatRow('Average:', '${stats['average']} m³/s'),
            _buildStatRow('Minimum:', '${stats['minimum']} m³/s'),
            _buildStatRow('Maximum:', '${stats['maximum']} m³/s'),
            _buildStatRow('Median:', '${stats['median']} m³/s'),
            _buildStatRow('Data Points:', '${stats['count']}'),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTrend() {
    if (_isLoadingStats) {
      return const SizedBox.shrink();
    }

    if (_recentTrend == null || _recentTrend!.containsKey('error')) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Trend analysis unavailable',
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final trend = _recentTrend!;
    final trendColor = trend['trendColor'] as Color;
    final percentChange = trend['percentChange'] as double;
    final trendText = trend['trend'] as String;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Trend',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(_getTrendIcon(trendText), color: trendColor, size: 24),
                const SizedBox(width: 8),
                Text(
                  trendText,
                  style: TextStyle(
                    color: trendColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                Text(
                  '${percentChange >= 0 ? '+' : ''}${percentChange.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: trendColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Last ${trend['recentDays']} days vs ${trend['historicalDays']} day average',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return months == 1 ? '1 month ago' : '$months months ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return years == 1 ? '1 year ago' : '$years years ago';
    }
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  IconData _getTrendIcon(String trend) {
    switch (trend.toLowerCase()) {
      case 'rising':
        return Icons.trending_up;
      case 'falling':
        return Icons.trending_down;
      case 'stable':
      default:
        return Icons.trending_flat;
    }
  }

  /// Calculate flow statistics from combined data (historical + real-time)
  Map<String, dynamic> _calculateStatsFromData(
    List<Map<String, dynamic>> data,
  ) {
    if (data.isEmpty) {
      return {'error': 'No data available', 'count': 0};
    }

    final dischargeValues = data
        .where((d) => d['discharge'] != null)
        .map<double>((d) => d['discharge'] as double)
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
        'start':
            data.last['datetime'] ??
            data.last['date'], // data is reversed (newest first)
        'end': data.first['datetime'] ?? data.first['date'],
      },
    };
  }
}
