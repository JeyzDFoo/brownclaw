import 'dart:async';
import 'package:brownclaw/widgets/river_detail/run_header_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../services/river_service.dart';
import '../services/analytics_service.dart';
import '../services/gauge_station_service.dart';
import '../models/models.dart'; // Import LiveWaterData model
import '../providers/providers.dart';
import '../widgets/user_runs_history_widget.dart';
import '../widgets/river_detail/kananaskis_river_section.dart';
import '../widgets/river_detail/envcanada_river_section.dart';
import 'edit_river_run_screen.dart';
import 'logbook_entry_screen.dart';

class RiverDetailScreen extends StatefulWidget {
  final Map<String, dynamic> riverData;

  const RiverDetailScreen({super.key, required this.riverData});

  @override
  State<RiverDetailScreen> createState() => _RiverDetailScreenState();
}

class _RiverDetailScreenState extends State<RiverDetailScreen> {
  List<FlSpot> _historicalData = [];
  Map<String, dynamic>? _flowStatistics;
  Map<String, dynamic>? _recentTrend;
  bool _isLoadingChart = true;
  bool _isLoadingStats = true;
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
  List<WeatherData> _weatherForecast = [];
  WeatherData? _currentWeather;
  bool _isLoadingWeather = false;
  String? _weatherError;

  // Unified initial loading state - true until critical data loaded
  bool _isInitialLoad = true;

  @override
  void initState() {
    super.initState();
    _currentRiverData = Map<String, dynamic>.from(widget.riverData);
    _setupRunStream();
    _loadLogbookStats();
    _loadInitialData();
  }

  /// Load critical data first, then secondary data
  Future<void> _loadInitialData() async {
    // Trigger background data fetch (provider handles caching)
    final stationId = widget.riverData['stationId'] as String?;
    if (stationId != null) {
      // Fire and forget - provider will notify listeners when done
      context.read<LiveWaterDataProvider>().fetchStationData(stationId);
    }

    // Load historical chart data
    await _loadHistoricalData();

    // Mark initial load complete
    if (mounted) {
      setState(() {
        _isInitialLoad = false;
      });
    }

    // Load secondary data (statistics + weather) in background
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

    _runSubscription = context
        .read<RiverRunProvider>()
        .watchRunById(runId)
        .listen((run) {
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

  /// Get the river type (Kananaskis vs Standard)
  RiverType get _riverType => RiverTypeHelper.fromRiverData(_currentRiverData);

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
        _historicalData = [];
        _flowStatistics = null;
        _recentTrend = null;
        _isLoadingChart = true;
        _isLoadingStats = true;
        _chartError = null;
        _currentWeather = null;
        _weatherForecast = [];
        _isLoadingWeather = true;
        _weatherError = null;
        _isInitialLoad = true; // Reset initial load state
      });
      _loadInitialData();
    }
  }

  Future<void> _loadHistoricalData() async {
    // 🚀 Only show loading if we don't already have data
    final showLoading = _historicalData.isEmpty;

    if (showLoading) {
      setState(() {
        _isLoadingChart = true;
        _chartError = null;
      });
    }

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

      // For short to medium ranges (30 days or less), use provider's combined timeline
      // Provider handles caching internally with persistent storage
      if (_selectedDays <= 30 && _selectedYear == null) {
        if (kDebugMode) {
          print(
            '🌐 Fetching combined timeline from provider (cached if available)',
          );
        }

        final combinedResult = await context
            .read<HistoricalWaterDataProvider>()
            .getCombinedTimeline(stationId, includeRealtimeData: true);

        final combined =
            combinedResult['combined'] as List<Map<String, dynamic>>;

        dataPoints = combined;

        if (kDebugMode) {
          print('✅ Got ${combined.length} days of combined data');
        }

        // Filter to requested number of days (client-side)
        if (dataPoints.isNotEmpty) {
          // Yield to UI thread before heavy processing
          await Future.delayed(Duration.zero);

          // Sort by date (most recent first)
          dataPoints.sort(
            (a, b) => (b['date'] as String).compareTo(a['date'] as String),
          );

          // Take the requested number of days
          dataPoints = dataPoints.take(_selectedDays).toList();

          // Reverse back to chronological order for charting
          dataPoints = dataPoints.reversed.toList();
        }
      } else {
        // For longer ranges (>30 days) or historical years, use cached historical data
        if (kDebugMode) {
          print(
            '📊 Fetching data for $_selectedDays days, year: $_selectedYear',
          );
        }

        // Provider handles caching - just call it directly
        // Check if viewing a specific historical year
        if (_selectedYear != null) {
          if (kDebugMode) {
            print(
              '🌐 Fetching historical year data for $_selectedYear from provider',
            );
          }
          // Fetch specific year from historical API (provider caches it)
          dataPoints = await context
              .read<HistoricalWaterDataProvider>()
              .fetchHistoricalData(stationId, year: _selectedYear);

          if (kDebugMode) {
            print(
              '📅 Got ${dataPoints.length} data points for year $_selectedYear',
            );
          }
        } else {
          if (kDebugMode) {
            print('🌐 Fetching combined timeline from provider');
          }
          // Default: use combined timeline for current data (provider caches it)
          final combinedResult = await context
              .read<HistoricalWaterDataProvider>()
              .getCombinedTimeline(stationId, includeRealtimeData: true);

          dataPoints = combinedResult['combined'] as List<Map<String, dynamic>>;

          if (kDebugMode) {
            print(
              '📅 Got ${dataPoints.length} data points from combined timeline',
            );
          }
        }

        // Filter to requested number of days (client-side)
        if (dataPoints.isNotEmpty) {
          // Sort by date (most recent first)
          dataPoints.sort(
            (a, b) => (b['date'] as String).compareTo(a['date'] as String),
          );

          // Take only the last N days
          dataPoints = dataPoints.take(_selectedDays).toList();

          // Reverse for charting (oldest first)
          dataPoints = dataPoints.reversed.toList();
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
  Future<void> _loadStatisticsData() async {
    // 🚀 Only show loading if we don't already have stats
    final showLoading = _flowStatistics == null;

    if (showLoading) {
      setState(() {
        _isLoadingStats = true;
      });
    }

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

      if (_selectedDays <= 30 && _selectedYear == null) {
        // For short to medium ranges, use provider's combined timeline
        if (kDebugMode) {
          print('🌐 Fetching combined timeline for statistics from provider');
        }

        final combinedResult = await context
            .read<HistoricalWaterDataProvider>()
            .getCombinedTimeline(stationId, includeRealtimeData: true);
        final dataPoints =
            combinedResult['combined'] as List<Map<String, dynamic>>;

        if (dataPoints.isNotEmpty) {
          // Take last N days and calculate statistics
          final sortedData = List<Map<String, dynamic>>.from(dataPoints);
          sortedData.sort(
            (a, b) => (b['date'] as String).compareTo(a['date'] as String),
          );
          final recentData = sortedData.take(_selectedDays).toList();

          flowStats = _calculateStatsFromData(recentData);
        } else {
          flowStats = {'error': 'No data available', 'count': 0};
        }
      } else {
        // For longer ranges (>30 days) or historical years, use provider's historical data
        List<Map<String, dynamic>> dataPoints;

        // Check if viewing a specific historical year
        if (_selectedYear != null) {
          if (kDebugMode) {
            print(
              '🌐 Fetching historical data for statistics (year: $_selectedYear) from provider',
            );
          }
          // Fetch specific year from provider (it handles caching)
          dataPoints = await context
              .read<HistoricalWaterDataProvider>()
              .fetchHistoricalData(stationId, year: _selectedYear);
        } else {
          if (kDebugMode) {
            print('🌐 Fetching combined timeline for statistics from provider');
          }
          // Default: use combined timeline (provider handles caching)
          final combinedResult = await context
              .read<HistoricalWaterDataProvider>()
              .getCombinedTimeline(stationId, includeRealtimeData: true);
          dataPoints = combinedResult['combined'] as List<Map<String, dynamic>>;
        }

        if (dataPoints.isNotEmpty) {
          // Take last N days and calculate statistics
          final sortedData = List<Map<String, dynamic>>.from(dataPoints);
          sortedData.sort(
            (a, b) => (b['date'] as String).compareTo(a['date'] as String),
          );
          final recentData = sortedData.take(_selectedDays).toList();

          flowStats = _calculateStatsFromData(recentData);
        } else {
          flowStats = {'error': 'No data available', 'count': 0};
        }
      }

      // Load recent trend (always use historical service for this)
      final recentTrend = await context
          .read<HistoricalWaterDataProvider>()
          .getRecentTrend(stationId);

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
    // 🚀 Only show loading if we don't already have weather data
    final showLoading = _weatherForecast.isEmpty;

    if (showLoading) {
      setState(() {
        _isLoadingWeather = true;
        _weatherError = null;
      });
    }

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

      // Fetch current weather and 5-day forecast using provider
      final weatherProvider = context.read<WeatherProvider>();
      final results = await weatherProvider.fetchAllWeather(
        station,
        forecastDays: 5,
      );

      final currentWeather = results['current'] as WeatherData?;
      final forecast = results['forecast'] as List<WeatherData>;

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
    // Providers handle their own caching - just refresh the data
    // Refresh live data via provider (handles its own caching)
    final stationId = widget.riverData['stationId'] as String?;
    if (stationId != null) {
      context.read<LiveWaterDataProvider>().fetchStationData(stationId);
    }

    await Future.wait([
      _loadHistoricalData(),
      _loadStatisticsData(),
      _loadWeatherData(),
    ]);
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
      body: _isInitialLoad
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : RefreshIndicator(
              onRefresh: _refreshAllData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Card with Status
                    RunHeaderCard(
                      section: section,
                      sectionClass: sectionClass,
                      status: status,
                      location: location,
                      difficulty: difficulty,
                      minRunnable: _currentRiverData['minRunnable'] as double?,
                      maxSafe: _currentRiverData['maxSafe'] as double?,
                      totalRuns: _totalRuns,
                      lastRanDate: _lastRanDate,
                    ),

                    const SizedBox(height: 16),

                    // River-type-specific content
                    if (_riverType.isKananaskis)
                      const KananaskisRiverSection(flowThreshold: 20.0)
                    else
                      // 🚀 Use Consumer to reactively display live data from provider
                      Consumer<LiveWaterDataProvider>(
                        builder: (context, liveDataProvider, child) {
                          final stationId =
                              widget.riverData['stationId'] as String?;
                          final liveData = stationId != null
                              ? liveDataProvider.getLiveData(stationId)
                              : null;
                          final isLoadingLiveData = stationId != null
                              ? liveDataProvider.isUpdating(stationId)
                              : false;
                          final liveDataError = stationId != null
                              ? liveDataProvider.getError(stationId)
                              : _validateStationData();

                          return EnvCanadaRiverSection(
                            liveData: liveData,
                            isLoadingLiveData: isLoadingLiveData,
                            liveDataError: liveDataError,
                            currentWeather: _currentWeather,
                            weatherForecast: _weatherForecast,
                            isLoadingWeather: _isLoadingWeather,
                            weatherError: _weatherError,
                            historicalData: _historicalData,
                            isLoadingChart: _isLoadingChart,
                            chartError: _chartError,
                            selectedDays: _selectedDays,
                            selectedYear: _selectedYear,
                            flowStatistics: _flowStatistics,
                            recentTrend: _recentTrend,
                            isLoadingStats: _isLoadingStats,
                            onDaysChanged: (days) {
                              setState(() {
                                _selectedDays = days;
                              });
                              _loadHistoricalData();
                            },
                            onYearChanged: (year) {
                              setState(() {
                                _selectedYear = year;
                              });
                              _loadHistoricalData();
                            },
                            formatDateTime: _formatDateTime,
                          );
                        },
                      ),

                    const SizedBox(height: 16),

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
        heroTag: 'river_detail_fab',
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
          final run = await context.read<RiverRunProvider>().getRunById(runId);
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
