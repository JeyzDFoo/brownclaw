import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import '../services/live_water_data_service.dart';

class RiverDetailScreen extends StatefulWidget {
  final Map<String, dynamic> riverData;

  const RiverDetailScreen({super.key, required this.riverData});

  @override
  State<RiverDetailScreen> createState() => _RiverDetailScreenState();
}

class _RiverDetailScreenState extends State<RiverDetailScreen> {
  Map<String, dynamic>? _liveData;
  List<FlSpot> _historicalData = [];
  bool _isLoading = true;
  bool _isLoadingChart = true;
  String? _error;
  String? _chartError;

  @override
  void initState() {
    super.initState();
    _loadLiveData();
    _loadHistoricalData();
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
        _isLoading = true;
        _isLoadingChart = true;
        _error = null;
        _chartError = null;
      });
      _loadLiveData();
      _loadHistoricalData();
    }
  }

  Future<void> _loadLiveData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final stationId = widget.riverData['stationId'] as String;
      final liveData = await LiveWaterDataService.fetchStationData(stationId);

      setState(() {
        _liveData = liveData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadHistoricalData() async {
    setState(() {
      _isLoadingChart = true;
      _chartError = null;
    });

    try {
      final stationId = widget.riverData['stationId'] as String;
      final historicalData = await _fetchHistoricalData(stationId);

      setState(() {
        _historicalData = historicalData;
        _isLoadingChart = false;
      });
    } catch (e) {
      setState(() {
        _chartError = e.toString();
        _isLoadingChart = false;
      });
    }
  }

  Future<List<FlSpot>> _fetchHistoricalData(String stationId) async {
    print('🔍 Fetching real-time data for station: $stationId');

    try {
      final spots = <FlSpot>[];

      print('📅 Fetching all available real-time data');

      // Determine province from station ID (same logic as live data service)
      String province = 'BC'; // Default to BC
      if (stationId.startsWith('02')) {
        province = 'ON'; // Ontario/Quebec
      } else if (stationId.startsWith('05')) {
        province = 'AB'; // Alberta
      } else if (stationId.startsWith('08') || stationId.startsWith('09')) {
        province = 'BC'; // British Columbia
      }

      // Environment Canada Real-time Data API
      // Use hourly data for detailed recent history
      final csvUrl =
          'https://dd.weather.gc.ca/hydrometric/csv/$province/hourly/${province}_${stationId}_hourly_hydrometric.csv';

      // Use CORS proxy for web platform (same as live data service)
      final url = kIsWeb ? 'https://corsproxy.io/?$csvUrl' : csvUrl;

      print('🌐 Fetching hourly real-time data');
      print('🌐 Attempting to fetch from: $url');

      final response = await http
          .get(
            Uri.parse(url),
            headers: kIsWeb ? {'X-Requested-With': 'XMLHttpRequest'} : null,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        print('❌ HTTP Error ${response.statusCode} for station $stationId');
        print('🔗 URL attempted: $url');
        throw Exception(
          'Failed to fetch historical data: ${response.statusCode} - Station file may not exist',
        );
      }

      // Parse CSV data
      final lines = response.body.split('\n');
      print('📄 Received ${lines.length} lines of CSV data');

      // Skip header and process data lines
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        final columns = line.split(',');
        if (columns.length < 5) continue;

        try {
          // CSV format: ID,Date,Water Level,Grade,Symbol,QA/QC,Discharge,Grade,Symbol,QA/QC
          if (columns.length < 7) continue;

          final dateTimeStr =
              columns[1]; // ISO format: 2025-10-13T00:00:00-08:00
          final dischargeStr = columns[6]; // Discharge column

          if (dischargeStr.isEmpty ||
              dischargeStr == 'null' ||
              dischargeStr.trim().isEmpty)
            continue;

          // Parse ISO 8601 date format
          final dataDate = DateTime.parse(dateTimeStr);

          final discharge = double.parse(dischargeStr.trim());
          final timestamp = dataDate.millisecondsSinceEpoch.toDouble();

          spots.add(FlSpot(timestamp, discharge));
        } catch (e) {
          // Skip invalid lines
          continue;
        }
      }

      // Sort by timestamp
      spots.sort((a, b) => a.x.compareTo(b.x));

      print(
        '✅ Successfully parsed ${spots.length} real historical data points',
      );

      if (spots.isNotEmpty) {
        print(
          '📊 Data range: ${spots.first.y.toStringAsFixed(1)} to ${spots.last.y.toStringAsFixed(1)} cms',
        );
        print(
          '📅 Time range: ${DateTime.fromMillisecondsSinceEpoch(spots.first.x.toInt())} to ${DateTime.fromMillisecondsSinceEpoch(spots.last.x.toInt())}',
        );
      }

      return spots;
    } catch (e) {
      print('💥 Error fetching real historical data: $e');
      // No fallback - rethrow the error to show proper error message
      rethrow;
    }
  }

  Future<void> _refreshAllData() async {
    await Future.wait([_loadLiveData(), _loadHistoricalData()]);
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
    final riverName =
        widget.riverData['riverName'] as String? ?? 'Unknown River';
    final stationId = widget.riverData['stationId'] as String? ?? 'Unknown';
    final location =
        widget.riverData['location'] as String? ?? 'Unknown Location';

    // Handle section data (could be Map or String for backward compatibility)
    final sectionData = widget.riverData['section'];
    final section = sectionData is Map<String, dynamic>
        ? (sectionData['name'] as String? ?? '')
        : (sectionData as String? ?? '');
    final sectionClass = sectionData is Map<String, dynamic>
        ? (sectionData['class'] as String? ?? 'Unknown')
        : (widget.riverData['difficulty'] as String? ?? 'Unknown');

    final difficulty = widget.riverData['difficulty'] as String? ?? 'Unknown';
    final status = widget.riverData['status'] as String? ?? 'Unknown';

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
                              color: _getStatusColor(status).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _getStatusColor(status).withOpacity(0.3),
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
                      Row(
                        children: [
                          Icon(Icons.water, color: Colors.grey[600], size: 16),
                          const SizedBox(width: 4),
                          Text(
                            'Station ID: $stationId',
                            style: TextStyle(color: Colors.grey[600]),
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
                    ],
                  ),
                ),
              ),

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
                              value:
                                  '${(_liveData!['flowRate'] as double?)?.toStringAsFixed(2) ?? 'N/A'} cms',
                              color: Colors.blue,
                            ),
                            const SizedBox(height: 12),
                            _buildDataRow(
                              icon: Icons.thermostat,
                              label: 'Temperature',
                              value:
                                  '${(_liveData!['temperature'] as double?)?.toStringAsFixed(1) ?? 'N/A'}°C',
                              color: Colors.orange,
                            ),
                            const SizedBox(height: 12),
                            _buildDataRow(
                              icon: Icons.schedule,
                              label: 'Last Updated',
                              value: _formatDateTime(
                                _liveData!['lastUpdated'] as String?,
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
}
