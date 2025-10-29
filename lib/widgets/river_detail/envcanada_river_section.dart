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

            // Year selector for historical data
            const SizedBox(height: 16),
            _buildYearSelector(context),

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
          minY: _calculateMinY(),
          maxY: _calculateMaxY(),
        ),
      ),
    );
  }

  /// Calculate stable minimum Y value for chart
  double _calculateMinY() {
    // Always start at 0 for flow data to provide consistent baseline
    return 0;
  }

  /// Calculate stable maximum Y value for chart
  double _calculateMaxY() {
    if (historicalData.isEmpty) return 100;

    final maxValue = historicalData
        .map((e) => e.y)
        .reduce((a, b) => a > b ? a : b);

    // Use adaptive scaling that handles both normal and flood conditions
    // Add 20% padding above max value for better visibility
    final targetMax = maxValue * 1.2;

    // Round up to nice numbers based on the scale
    if (targetMax <= 10) {
      return 10.0;
    } else if (targetMax <= 20) {
      return 20.0;
    } else if (targetMax <= 50) {
      return 50.0;
    } else if (targetMax <= 100) {
      return 100.0;
    } else if (targetMax <= 200) {
      return 200.0;
    } else if (targetMax <= 300) {
      return 300.0;
    } else if (targetMax <= 500) {
      return 500.0;
    } else if (targetMax <= 1000) {
      return 1000.0;
    } else if (targetMax <= 2000) {
      return 2000.0;
    } else {
      // For very large values, round up to nearest 500
      return (targetMax / 500).ceil() * 500.0;
    }
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

  Widget _buildYearSelector(BuildContext context) {
    // Historical data available through Dec 31, 2024 via Gov of Canada API
    // Data goes back to early 1900s for most stations
    const lastAvailableYear = 2024;
    const firstAvailableYear = 2005; // 20 years of historical data

    // Generate years from 2005 to 2024 (20 years of historical data)
    final years = List.generate(
      lastAvailableYear - firstAvailableYear + 1,
      (index) => lastAvailableYear - index,
    );

    return Card(
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today, size: 18, color: Colors.teal),
                const SizedBox(width: 8),
                Text(
                  'Historical Years',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 60,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: years.length,
                itemBuilder: (context, index) {
                  final year = years[index];
                  final isSelected = selectedYear == year;

                  return Padding(
                    padding: EdgeInsets.only(
                      right: index < years.length - 1 ? 12.0 : 0,
                    ),
                    child: _buildYearCard(context, year, isSelected),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYearCard(BuildContext context, int year, bool isSelected) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (isSelected) {
            // Deselect year and return to current data
            onYearChanged(null);
            onDaysChanged(3); // Reset to default 3 days
          } else {
            onYearChanged(year);
            // When selecting a year, default to viewing the full year
            onDaysChanged(365);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 80,
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.teal
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.teal : Colors.grey.withOpacity(0.3),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.teal.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.event,
                size: 20,
                color: isSelected ? Colors.white : Colors.teal,
              ),
              const SizedBox(height: 4),
              Text(
                year.toString(),
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.teal,
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
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
