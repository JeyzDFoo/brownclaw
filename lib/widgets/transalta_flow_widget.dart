import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/transalta_flow_data.dart';
import '../models/gauge_station.dart';
import '../models/weather_data.dart';
import '../providers/transalta_provider.dart';
import '../providers/premium_provider.dart';
import '../services/weather_service.dart';
import '../screens/premium_purchase_screen.dart';

/// Widget showing TransAlta Barrier Dam flow information
///
/// Uses TransAltaProvider for centralized state management
/// Days beyond tomorrow require premium subscription
class TransAltaFlowWidget extends StatefulWidget {
  final double threshold;

  const TransAltaFlowWidget({super.key, this.threshold = 20.0});

  @override
  State<TransAltaFlowWidget> createState() => _TransAltaFlowWidgetState();
}

class _TransAltaFlowWidgetState extends State<TransAltaFlowWidget> {
  bool _hasInitialized = false;
  final WeatherService _weatherService = WeatherService();
  WeatherData? _currentWeather;
  List<WeatherData> _weatherForecast = [];
  bool _isLoadingWeather = false;

  // Kananaskis / Barrier Dam approximate coordinates
  static const double _kananaskisLat = 51.1;
  static const double _kananaskisLon = -115.0;

  @override
  void initState() {
    super.initState();
    _fetchWeather();
  }

  Future<void> _fetchWeather() async {
    setState(() {
      _isLoadingWeather = true;
    });

    try {
      // Create a temporary gauge station with Kananaskis coordinates
      final kananaskisStation = GaugeStation(
        stationId: 'kananaskis',
        name: 'Kananaskis River',
        latitude: _kananaskisLat,
        longitude: _kananaskisLon,
        isActive: true,
        parameters: const [],
      );

      // Fetch current weather and 3-day forecast
      final weather = await _weatherService.getWeatherForStation(
        kananaskisStation,
      );
      final forecast = await _weatherService.getForecastForStation(
        kananaskisStation,
        days: 3,
      );

      if (mounted) {
        setState(() {
          _currentWeather = weather;
          _weatherForecast = forecast;
          _isLoadingWeather = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingWeather = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<TransAltaProvider, PremiumProvider>(
      builder: (context, transAltaProvider, premiumProvider, child) {
        // Fetch data once on first build if not already loaded
        if (!_hasInitialized &&
            !transAltaProvider.hasData &&
            !transAltaProvider.isLoading &&
            transAltaProvider.error == null) {
          _hasInitialized = true;
          Future.microtask(() => transAltaProvider.fetchFlowData());
        }

        return Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '🌊 Kananaskis River Flow',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: transAltaProvider.isLoading
                          ? null
                          : () => transAltaProvider.fetchFlowData(
                              forceRefresh: true,
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Barrier Dam (≥${widget.threshold.toStringAsFixed(0)} m³/s)',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const Divider(height: 24),

                if (transAltaProvider.isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (transAltaProvider.error != null)
                  Center(
                    child: Column(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          transAltaProvider.error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => transAltaProvider.fetchFlowData(
                            forceRefresh: true,
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                else if (transAltaProvider.hasData)
                  _buildContent(transAltaProvider, premiumProvider),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(
    TransAltaProvider provider,
    PremiumProvider premiumProvider,
  ) {
    final flowData = provider.flowData;
    if (flowData == null) return const SizedBox();

    final highFlowPeriods = provider.getAllFlowPeriods(
      threshold: widget.threshold,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Current Flow with Weather
        _buildCurrentFlow(flowData.currentFlow, highFlowPeriods),

        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 16),

        // High Flow Schedule
        _buildHighFlowSchedule(highFlowPeriods, premiumProvider),
      ],
    );
  }

  Widget _buildCurrentFlow(
    HourlyFlowEntry? current,
    List<HighFlowPeriod> flowPeriods,
  ) {
    if (current == null) {
      return const Text('No current flow data available');
    }

    // Group flow periods by day for easy lookup
    final Map<int, List<HighFlowPeriod>> periodsByDay = {};
    for (final period in flowPeriods) {
      periodsByDay.putIfAbsent(period.dayNumber, () => []).add(period);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getFlowStatusColor(current.flowStatus).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _getFlowStatusColor(current.flowStatus).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                current.flowStatus.emoji,
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 8),
              const Text(
                'Current Flow',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${current.barrierFlow} m³/s',
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),
          Text(
            current.flowStatus.description,
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),
          const SizedBox(height: 8),

          // Weather forecast section
          if (_currentWeather != null || _isLoadingWeather)
            Builder(
              builder: (context) {
                final theme = Theme.of(context);
                final isDark = theme.brightness == Brightness.dark;

                return Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [
                              Colors.blue.shade900.withOpacity(0.3),
                              Colors.teal.shade900.withOpacity(0.3),
                            ]
                          : [
                              Colors.blue.shade50.withOpacity(0.8),
                              Colors.teal.shade50.withOpacity(0.8),
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark
                          ? Colors.blue.shade700.withOpacity(0.4)
                          : Colors.blue.shade200.withOpacity(0.6),
                      width: 1.5,
                    ),
                  ),
                  child: _isLoadingWeather
                      ? Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Loading weather...',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                            ),
                          ],
                        )
                      : _currentWeather != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? Colors.white.withOpacity(0.1)
                                              : Colors.white.withOpacity(0.7),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          _getWeatherEmoji(
                                            _currentWeather!.conditions,
                                          ),
                                          style: const TextStyle(fontSize: 24),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Weather Forecast',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: isDark
                                                    ? Colors.blue.shade200
                                                    : Colors.blue.shade900,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              _currentWeather!.conditions,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: theme
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.color
                                                    ?.withOpacity(0.8),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.blue.shade800.withOpacity(0.4)
                                        : Colors.blue.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${_currentWeather!.temperature.toStringAsFixed(0)}°C',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.blue.shade100
                                          : Colors.blue.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_weatherForecast.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Divider(
                                height: 1,
                                color: isDark
                                    ? Colors.white.withOpacity(0.2)
                                    : Colors.grey.withOpacity(0.3),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: _weatherForecast.take(3).map((day) {
                                  final dayName = _getDayName(day.forecastTime);

                                  // Get the day number (0=today, 1=tomorrow, 2=day after)
                                  final now = DateTime.now();
                                  final today = DateTime(
                                    now.year,
                                    now.month,
                                    now.day,
                                  );
                                  final forecastDate = day.forecastTime != null
                                      ? DateTime(
                                          day.forecastTime!.year,
                                          day.forecastTime!.month,
                                          day.forecastTime!.day,
                                        )
                                      : today;
                                  final dayNumber = forecastDate
                                      .difference(today)
                                      .inDays;

                                  // Get flow periods for this day
                                  final dayFlowPeriods =
                                      periodsByDay[dayNumber] ?? [];
                                  final hasFlow = dayFlowPeriods.isNotEmpty;

                                  String flowInfo = 'No release';
                                  if (hasFlow) {
                                    final totalPeriods = dayFlowPeriods.length;
                                    if (totalPeriods == 1) {
                                      final period = dayFlowPeriods.first;
                                      // Get arrival times with 15min travel time
                                      final firstEntry = period.entries.first;
                                      final lastEntry = period.entries.last;
                                      final startTime = firstEntry
                                          .getArrivalTimeString(
                                            travelTimeMinutes: 15,
                                          );
                                      final endTime = lastEntry
                                          .getArrivalTimeString(
                                            travelTimeMinutes: 15,
                                          );
                                      flowInfo = '$startTime-$endTime';
                                    } else {
                                      // Multiple separate periods in one day
                                      // Show each period on a separate line
                                      final periodTimes = dayFlowPeriods
                                          .map((period) {
                                            final start = period.entries.first
                                                .getArrivalTimeString(
                                                  travelTimeMinutes: 15,
                                                );
                                            final end = period.entries.last
                                                .getArrivalTimeString(
                                                  travelTimeMinutes: 15,
                                                );
                                            return '$start-$end';
                                          })
                                          .join('\n');
                                      flowInfo = periodTimes;
                                    }
                                  }

                                  return Expanded(
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.white.withOpacity(0.05)
                                            : Colors.white.withOpacity(0.5),
                                        borderRadius: BorderRadius.circular(8),
                                        border: hasFlow
                                            ? Border.all(
                                                color: isDark
                                                    ? Colors.blue.shade400
                                                          .withOpacity(0.5)
                                                    : Colors.blue.shade300
                                                          .withOpacity(0.7),
                                                width: 1.5,
                                              )
                                            : null,
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            dayName,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: isDark
                                                  ? Colors.teal.shade200
                                                  : Colors.teal.shade900,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            _getWeatherEmoji(day.conditions),
                                            style: const TextStyle(
                                              fontSize: 20,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${day.temperature.toStringAsFixed(0)}°',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: theme
                                                  .textTheme
                                                  .bodyLarge
                                                  ?.color,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: hasFlow
                                                  ? (isDark
                                                        ? Colors.blue.shade800
                                                              .withOpacity(0.4)
                                                        : Colors.blue.shade100
                                                              .withOpacity(0.8))
                                                  : (isDark
                                                        ? Colors.grey.shade800
                                                              .withOpacity(0.3)
                                                        : Colors.grey.shade200
                                                              .withOpacity(
                                                                0.6,
                                                              )),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Column(
                                              children: [
                                                Text(
                                                  'Dam Release',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                    color: hasFlow
                                                        ? (isDark
                                                              ? Colors
                                                                    .blue
                                                                    .shade200
                                                              : Colors
                                                                    .blue
                                                                    .shade900)
                                                        : (isDark
                                                              ? Colors
                                                                    .grey
                                                                    .shade400
                                                              : Colors
                                                                    .grey
                                                                    .shade700),
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  flowInfo,
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    color: hasFlow
                                                        ? (isDark
                                                              ? Colors
                                                                    .blue
                                                                    .shade100
                                                              : Colors
                                                                    .blue
                                                                    .shade800)
                                                        : (isDark
                                                              ? Colors
                                                                    .grey
                                                                    .shade500
                                                              : Colors
                                                                    .grey
                                                                    .shade600),
                                                  ),
                                                  textAlign: TextAlign.center,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        )
                      : const SizedBox.shrink(),
                );
              },
            ),
        ],
      ),
    );
  }

  String _getWeatherEmoji(String conditions) {
    final lower = conditions.toLowerCase();
    if (lower.contains('clear') || lower.contains('sunny')) return '☀️';
    if (lower.contains('partly') || lower.contains('cloud')) return '⛅';
    if (lower.contains('rain') || lower.contains('drizzle')) return '🌧️';
    if (lower.contains('snow')) return '❄️';
    if (lower.contains('thunder') || lower.contains('storm')) return '⛈️';
    if (lower.contains('fog')) return '🌫️';
    return '🌤️';
  }

  String _getDayName(DateTime? dateTime) {
    if (dateTime == null) return '';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dateTime.year, dateTime.month, dateTime.day);

    final difference = date.difference(today).inDays;

    if (difference == 0) return 'Today';
    if (difference == 1) return 'Tmrw';
    if (difference == 2) return 'Day 3';

    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return weekdays[dateTime.weekday - 1];
  }

  Widget _buildHighFlowSchedule(
    List<HighFlowPeriod> highFlowPeriods,
    PremiumProvider premiumProvider,
  ) {
    if (highFlowPeriods.isEmpty) {
      return Column(
        children: [
          const Text(
            'Flow Schedule',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'No flow periods ≥${widget.threshold.toStringAsFixed(0)} m³/s in the forecast',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      );
    } // Group periods by day
    final Map<int, List<HighFlowPeriod>> periodsByDay = {};
    for (final period in highFlowPeriods) {
      periodsByDay.putIfAbsent(period.dayNumber, () => []).add(period);
    }

    // Sort days
    final sortedDays = periodsByDay.keys.toList()..sort();

    final isPremium = premiumProvider.isPremium;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Flow Schedule (≥${widget.threshold.toStringAsFixed(0)} m³/s)',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Includes 15min travel time to widowmaker',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 12),

        // Show Today and Tomorrow for everyone
        ...sortedDays
            .where((day) => day <= 1) // 0 = today, 1 = tomorrow
            .map((day) => _buildDayCard(day, periodsByDay[day]!)),

        // Show remaining days only for premium users, or paywall
        if (sortedDays.any((day) => day > 1))
          if (isPremium)
            ...sortedDays
                .where((day) => day > 1)
                .map((day) => _buildDayCard(day, periodsByDay[day]!))
          else
            _buildPaywallCard(sortedDays.where((day) => day > 1).length),
      ],
    );
  }

  Widget _buildPaywallCard(int lockedDaysCount) {
    return Builder(
      builder: (context) {
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 1,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue.withOpacity(0.1),
                  Colors.purple.withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.lock, size: 32, color: Colors.blue[700]),
                  const SizedBox(height: 8),
                  Text(
                    'Unlock ${lockedDaysCount > 1 ? "$lockedDaysCount More Days" : "1 More Day"}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[900],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'See the full 4-day forecast with Premium',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const PremiumPurchaseScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.star),
                    label: const Text('Upgrade to Premium'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDayCard(int dayNumber, List<HighFlowPeriod> periods) {
    final firstPeriod = periods.first;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  firstPeriod.dayName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    firstPeriod.dateString,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Show each period
            ...periods.asMap().entries.map((entry) {
              final index = entry.key;
              final period = entry.value;

              return Padding(
                padding: EdgeInsets.only(
                  bottom: index < periods.length - 1 ? 8.0 : 0.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (periods.length > 1)
                      Text(
                        'Period ${index + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                    if (periods.length > 1) const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              size: 16,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              period.arrivalTimeRange,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const Icon(
                              Icons.water_drop,
                              size: 16,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              period.flowRangeString,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '(${period.totalHours}h)',
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
              );
            }),
          ],
        ),
      ),
    );
  }

  Color _getFlowStatusColor(FlowStatus status) {
    switch (status) {
      case FlowStatus.offline:
        return Colors.grey;
      case FlowStatus.tooLow:
        return Colors.orange;
      case FlowStatus.low:
        return Colors.amber;
      case FlowStatus.moderate:
        return Colors.green;
      case FlowStatus.high:
        return Colors.blue;
    }
  }
}
