import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/live_water_data_service.dart';
import '../services/historical_water_data_service.dart';
import '../models/models.dart'; // Import LiveWaterData model

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
  int _selectedDays = 365; // Default to 1 year of historical data

  @override
  void initState() {
    super.initState();
    _loadLiveData();
    _loadHistoricalData();
    _loadStatisticsData();
  }

  /// Validates if the river has a valid station ID for data fetching
  String? _validateStationData() {
    final stationId = widget.riverData['stationId'] as String?;
    final hasValidStation =
        widget.riverData['hasValidStation'] as bool? ?? false;

    if (stationId == null || stationId.isEmpty) {
      return 'No gauge station linked to this river run';
    }

    if (!hasValidStation ||
        !RegExp(r'^[A-Z0-9]+$').hasMatch(stationId.toUpperCase())) {
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
      });
      _loadLiveData();
      _loadHistoricalData();
      _loadStatisticsData();
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

      if (mounted) {
        setState(() {
          _historicalData = historicalData;
          _isLoadingChart = false;
        });
      }
    } catch (e) {
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
          '🔍 Fetching historical data for station: $stationId, days: $_selectedDays',
        );
      }

      // Use the new HistoricalWaterDataService for web-compatible data fetching
      final historicalData =
          await HistoricalWaterDataService.fetchHistoricalData(
            stationId,
            daysBack: _selectedDays,
          );

      if (kDebugMode) {
        print('📊 Received ${historicalData.length} historical data points');
        if (historicalData.isNotEmpty) {
          print('   First data point: ${historicalData.first}');
          print('   Last data point: ${historicalData.last}');
        }
      }

      final spots = <FlSpot>[];

      for (final dataPoint in historicalData) {
        final dateStr = dataPoint['date'] as String?;
        final discharge = dataPoint['discharge'] as double?;

        if (dateStr != null && discharge != null) {
          final date = DateTime.parse(dateStr);
          final timestamp = date.millisecondsSinceEpoch.toDouble();
          spots.add(FlSpot(timestamp, discharge));
        }
      }

      // Sort by timestamp
      spots.sort((a, b) => a.x.compareTo(b.x));

      if (kDebugMode) {
        print('✅ Created ${spots.length} chart data points');
      }

      return spots;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching historical data: $e');
      }
      rethrow;
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

      // Load flow statistics and recent trend in parallel
      final futures = await Future.wait([
        HistoricalWaterDataService.getFlowStatistics(
          stationId,
          daysBack: _selectedDays,
        ),
        HistoricalWaterDataService.getRecentTrend(stationId),
      ]);

      if (mounted) {
        setState(() {
          _flowStatistics = futures[0];
          _recentTrend = futures[1];
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

  Future<void> _refreshAllData() async {
    await Future.wait([
      _loadLiveData(),
      _loadHistoricalData(),
      _loadStatisticsData(),
    ]);
  }

  Future<void> _changeDaysRange(int newDays) async {
    if (newDays == _selectedDays) return;

    setState(() {
      _selectedDays = newDays;
      _isLoadingChart = true;
      _isLoadingStats = true;
    });

    await Future.wait([_loadHistoricalData(), _loadStatisticsData()]);
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
      riverName = widget.riverData['riverName'] as String? ?? 'Unknown River';
      stationId = widget.riverData['stationId'] as String? ?? 'Unknown';
      location = widget.riverData['location'] as String? ?? 'Unknown Location';

      // Handle section data (could be Map or String for backward compatibility)
      final sectionData = widget.riverData['section'];
      section = sectionData is Map<String, dynamic>
          ? (sectionData['name'] as String? ?? '')
          : (sectionData as String? ?? '');
      sectionClass = sectionData is Map<String, dynamic>
          ? (sectionData['difficulty'] as String? ?? 'Unknown')
          : (widget.riverData['difficulty'] as String? ?? 'Unknown');

      difficulty = widget.riverData['difficulty'] as String? ?? 'Unknown';
      status = widget.riverData['status'] as String? ?? 'Unknown';

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
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
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
                                Text(
                                  riverName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                if (section.isNotEmpty)
                                  Text(
                                    '$section ($sectionClass)',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(color: Colors.grey[600]),
                                  ),
                                if (section.isEmpty &&
                                    sectionClass != 'Unknown')
                                  Text(
                                    sectionClass,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(color: Colors.grey[600]),
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(
                                status,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _getStatusColor(
                                  status,
                                ).withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                color: _getStatusColor(status),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
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
                      // Show station ID only if it's a valid gauge station
                      if (widget.riverData['hasValidStation'] == true)
                        Row(
                          children: [
                            Icon(
                              Icons.water,
                              color: Colors.grey[600],
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Station ID: $stationId',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.orange[600],
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'No real-time gauge station data available',
                                style: TextStyle(
                                  color: Colors.orange[600],
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
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
                      if (widget.riverData['minRunnable'] != null &&
                          widget.riverData['maxSafe'] != null &&
                          widget.riverData['minRunnable'] > 0)
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
                                  'Recommended flow: ${widget.riverData['minRunnable']}-${widget.riverData['maxSafe']} m³/s',
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

              // Data Availability Info Card
              _buildDataAvailabilityCard(),

              const SizedBox(height: 16),

              // Current Conditions Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Conditions',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
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
                            // _buildDataRow(
                            //   icon: Icons.thermostat,
                            //   label: 'Temperature',
                            //   value:
                            //       '${_liveData!.temperature?.toStringAsFixed(1) ?? 'N/A'}°C',
                            //   color: Colors.orange,
                            // ),
                            // const SizedBox(height: 12),
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

              const SizedBox(height: 16),

              // Historical Discharge Chart Card
              Card(
                key: ValueKey('chart_card_${widget.riverData['stationId']}'),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Real-time Discharge History',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
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
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40.0),
                            child: Text(
                              'No historical data available',
                              style: TextStyle(color: Colors.grey),
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

              const SizedBox(height: 32),
            ],
          ),
        ),
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
              children: [7, 14, 30, 60, 90].map((days) {
                final isSelected = days == _selectedDays;
                return FilterChip(
                  label: Text('${days}d'),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      _changeDaysRange(days);
                    }
                  },
                  selectedColor: Colors.teal.withOpacity(0.3),
                  backgroundColor: Colors.grey.withOpacity(0.1),
                );
              }).toList(),
            ),
          ],
        ),
      ),
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
              'Flow Statistics (Last $_selectedDays days)',
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

  /// Build data availability information card
  Widget _buildDataAvailabilityCard() {
    final availabilityInfo =
        HistoricalWaterDataService.getDataAvailabilityInfo();
    final currentGap =
        availabilityInfo['currentYearGap'] as Map<String, dynamic>;
    final historical =
        availabilityInfo['historicalData'] as Map<String, dynamic>;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[600], size: 24),
                const SizedBox(width: 8),
                Text(
                  'Data Availability',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Historical Data Info
            _buildDataSourceRow(
              Icons.history,
              'Historical Data',
              '${historical['startDate']} to ${historical['endDate']}',
              Colors.green,
              'Complete daily records for long-term analysis',
            ),
            const SizedBox(height: 8),

            // Current Year Gap Info
            _buildDataSourceRow(
              Icons.warning_amber_outlined,
              'Current Year Gap',
              '${currentGap['startDate']} to ${currentGap['endDate']} (${currentGap['gapDays']} days)',
              Colors.orange,
              'Government processing delay - no daily data available',
            ),
            const SizedBox(height: 8),

            // Real-time Data Info
            _buildDataSourceRow(
              Icons.access_time,
              'Real-time Data',
              'Last 30 days (5-minute intervals)',
              Colors.teal,
              'Current conditions for immediate planning',
            ),
            const SizedBox(height: 12),

            // Recommendations
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        size: 16,
                        color: Colors.blue[700],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Tip:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Use historical trends to estimate likely conditions during the current year gap. '
                    'Check real-time data for the most recent 30 days.',
                    style: TextStyle(fontSize: 13, color: Colors.blue[700]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build a row showing data source information
  Widget _buildDataSourceRow(
    IconData icon,
    String title,
    String period,
    Color color,
    String description,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Text(
                period,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                description,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
