import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/models.dart';
import '../../widgets/weather_forecast_widget.dart';

/// River detail section for Environment Canada rivers
///
/// Environment Canada rivers display:
/// - Current conditions (live flow data from Gov of Canada)
/// - Weather forecast
/// - Historical discharge chart with time range selector
/// - Flow statistics and recent trends
class EnvCanadaRiverSection extends StatelessWidget {
  // Live data state
  final LiveWaterData? liveData;
  final bool isLoadingLiveData;
  final String? liveDataError;

  // Weather state
  final WeatherData? currentWeather;
  final List<WeatherData> weatherForecast;
  final bool isLoadingWeather;
  final String? weatherError;

  // Chart state
  final List<FlSpot> historicalData;
  final bool isLoadingChart;
  final String? chartError;
  final int selectedDays;
  final int? selectedYear;

  // Statistics state
  final Map<String, dynamic>? flowStatistics;
  final Map<String, dynamic>? recentTrend;
  final bool isLoadingStats;

  // Callbacks
  final Function(int days) onDaysChanged;
  final Function(int? year) onYearChanged;
  final String Function(String) formatDateTime;

  const EnvCanadaRiverSection({
    super.key,
    required this.liveData,
    required this.isLoadingLiveData,
    required this.liveDataError,
    required this.currentWeather,
    required this.weatherForecast,
    required this.isLoadingWeather,
    required this.weatherError,
    required this.historicalData,
    required this.isLoadingChart,
    required this.chartError,
    required this.selectedDays,
    required this.selectedYear,
    required this.flowStatistics,
    required this.recentTrend,
    required this.isLoadingStats,
    required this.onDaysChanged,
    required this.onYearChanged,
    required this.formatDateTime,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Current Conditions Card
        _buildCurrentConditionsCard(context),
        const SizedBox(height: 16),

        // Weather Forecast Widget
        WeatherForecastWidget(
          forecast: weatherForecast,
          isLoading: isLoadingWeather,
          error: weatherError,
        ),
        const SizedBox(height: 16),

        // Historical Discharge Chart Card
        _buildHistoricalChartCard(context),
      ],
    );
  }

  Widget _buildCurrentConditionsCard(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Conditions',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            if (isLoadingLiveData)
              _buildLoadingState('Loading current conditions...')
            else if (liveDataError != null)
              _buildErrorState(
                context,
                'Error loading live data',
                liveDataError!,
              )
            else if (liveData != null)
              _buildLiveDataContent(context)
            else
              _buildEmptyState('No live data available'),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveDataContent(BuildContext context) {
    return Column(
      children: [
        _buildDataRow(
          context: context,
          icon: Icons.water_drop,
          label: 'Flow Rate',
          value: liveData!.formattedFlowRate,
          color: Colors.blue,
        ),
        const SizedBox(height: 12),

        // Show current weather if available
        if (currentWeather != null) ...[
          _buildDataRow(
            context: context,
            icon: Icons.thermostat,
            label: 'Temperature',
            value:
                '${currentWeather!.temperature.toStringAsFixed(1)}°${currentWeather!.temperatureUnit}',
            color: Colors.orange,
          ),
          const SizedBox(height: 12),
          _buildDataRow(
            context: context,
            icon: Icons.wb_cloudy_outlined,
            label: 'Conditions',
            value: currentWeather!.conditions,
            color: Colors.grey,
          ),
          const SizedBox(height: 12),
          if (currentWeather!.windSpeed != null) ...[
            _buildDataRow(
              context: context,
              icon: Icons.air,
              label: 'Wind',
              value: '${currentWeather!.windSpeed!.toStringAsFixed(0)} km/h',
              color: Colors.teal,
            ),
            const SizedBox(height: 12),
          ],
        ],

        _buildDataRow(
          context: context,
          icon: Icons.schedule,
          label: 'Last Updated',
          value: formatDateTime(liveData!.timestamp.toIso8601String()),
          color: Colors.grey,
        ),
      ],
    );
  }

  Widget _buildHistoricalChartCard(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              selectedYear != null
                  ? 'Discharge History - $selectedYear'
                  : 'Real-time Discharge History',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            if (isLoadingChart)
              _buildLoadingState('Loading chart data...')
            else if (chartError != null)
              _buildChartError(context)
            else if (historicalData.isNotEmpty)
              _buildChart(context)
            else
              _buildNoChartData(context),

            if (historicalData.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      'Discharge in cms',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),

            // Day range selector
            const SizedBox(height: 16),
            _buildDayRangeSelector(context),

            // Flow statistics section
            const SizedBox(height: 16),
            _buildFlowStatistics(context),

            // Recent trend section
            const SizedBox(height: 16),
            _buildRecentTrend(context),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(BuildContext context) {
    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawHorizontalLine: true,
            drawVerticalLine: false,
            horizontalInterval: historicalData.isNotEmpty
                ? (historicalData
                              .map((e) => e.y)
                              .reduce((a, b) => a > b ? a : b) /
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
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                interval: historicalData.isNotEmpty
                    ? (historicalData.last.x - historicalData.first.x) / 4
                    : null,
                getTitlesWidget: (value, meta) {
                  final dateTime = DateTime.fromMillisecondsSinceEpoch(
                    value.toInt(),
                  );
                  final dateStr =
                      '${dateTime.month.toString().padLeft(2, '0')}/${dateTime.day.toString().padLeft(2, '0')}';

                  return Transform.rotate(
                    angle: -0.5,
                    child: Text(
                      dateStr,
                      style: const TextStyle(color: Colors.grey, fontSize: 10),
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
            border: Border.all(color: Colors.grey.withOpacity(0.3), width: 1),
          ),
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((touchedSpot) {
                  final dateTime = DateTime.fromMillisecondsSinceEpoch(
                    touchedSpot.x.toInt(),
                  );
                  final flow = touchedSpot.y;

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
            handleBuiltInTouches: true,
          ),
          lineBarsData: [
            LineChartBarData(
              spots: historicalData,
              isCurved: true,
              color: Colors.teal,
              barWidth: 3,
              isStrokeCapRound: true,
              belowBarData: BarAreaData(
                show: true,
                color: Colors.teal.withOpacity(0.1),
              ),
              dotData: const FlDotData(show: false),
            ),
          ],
          minY: historicalData.isNotEmpty
              ? (historicalData
                            .map((e) => e.y)
                            .reduce((a, b) => a < b ? a : b) *
                        0.8)
                    .clamp(0, double.infinity)
              : 0,
          maxY: historicalData.isNotEmpty
              ? historicalData.map((e) => e.y).reduce((a, b) => a > b ? a : b) *
                    1.3
              : 80,
        ),
      ),
    );
  }

  Widget _buildDayRangeSelector(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Time Range',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildTimeRangeChip(context, 3, '3 Days'),
                _buildTimeRangeChip(context, 14, '2 Weeks'),
                _buildTimeRangeChip(context, 30, '30 Days'),
                _buildTimeRangeChip(context, 90, '90 Days'),
                _buildTimeRangeChip(context, 365, '1 Year'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeRangeChip(BuildContext context, int days, String label) {
    final isSelected = selectedDays == days && selectedYear == null;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          onDaysChanged(days);
          onYearChanged(null);
        }
      },
      selectedColor: Colors.teal.withOpacity(0.3),
      checkmarkColor: Colors.teal,
    );
  }

  Widget _buildFlowStatistics(BuildContext context) {
    if (isLoadingStats) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _buildLoadingState('Loading statistics...'),
        ),
      );
    }

    if (flowStatistics == null || flowStatistics!.containsKey('error')) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Flow Statistics',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildStatRow('Average', '${flowStatistics!['average']} cms'),
            _buildStatRow('Median', '${flowStatistics!['median']} cms'),
            _buildStatRow('Minimum', '${flowStatistics!['minimum']} cms'),
            _buildStatRow('Maximum', '${flowStatistics!['maximum']} cms'),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTrend(BuildContext context) {
    if (isLoadingStats) {
      return const SizedBox.shrink();
    }

    if (recentTrend == null) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getTrendIcon(recentTrend!['trend'] as String? ?? 'stable'),
                  size: 20,
                  color: Colors.teal,
                ),
                const SizedBox(width: 8),
                Text(
                  'Recent Trend',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              recentTrend!['description'] as String? ??
                  'No trend data available',
              style: Theme.of(context).textTheme.bodyMedium,
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

  Widget _buildDataRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState(String message) {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.teal,
              ),
            ),
            const SizedBox(height: 12),
            Text(message, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String title, String message) {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red[300], size: 48),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(color: Colors.red[600])),
            const SizedBox(height: 4),
            Text(
              message,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return SizedBox(
      height: 200,
      child: Center(
        child: Text(message, style: const TextStyle(color: Colors.grey)),
      ),
    );
  }

  Widget _buildChartError(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red[300], size: 48),
            const SizedBox(height: 8),
            Text(
              'Real historical data unavailable',
              style: TextStyle(color: Colors.red[600]),
            ),
            const SizedBox(height: 4),
            Text(
              'Unable to fetch government historical data for this station',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoChartData(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                selectedYear != null
                    ? 'No historical data available for $selectedYear'
                    : 'No historical data available',
                style: const TextStyle(color: Colors.grey),
              ),
              if (selectedYear != null) ...[
                const SizedBox(height: 8),
                const Text(
                  'This station may only have real-time data',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
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
}
