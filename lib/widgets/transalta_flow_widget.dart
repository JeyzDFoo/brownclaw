import 'dart:math' as math;
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
  List<WeatherData> _hourlyWeather = [];
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

      // Fetch current weather (today), 4-day forecast, and hourly forecast
      // We want 4 total days: today + next 3 days
      final weather = await _weatherService.getWeatherForStation(
        kananaskisStation,
      );
      final forecast = await _weatherService.getForecastForStation(
        kananaskisStation,
        days: 4, // Request 4 days to ensure we get enough data
      );
      final hourly = await _weatherService.getHourlyForecast(
        kananaskisStation,
        days: 4,
      );

      if (mounted) {
        setState(() {
          // Combine current weather (today) with forecast (tomorrow onwards)
          // This ensures we always have today's data as the first entry
          final combinedForecast = <WeatherData>[];

          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);

          if (weather != null) {
            // Add current weather as today
            final weatherWithDate = WeatherData(
              latitude: weather.latitude,
              longitude: weather.longitude,
              temperature: weather.temperature,
              conditions: weather.conditions,
              precipitation: weather.precipitation,
              forecastTime: today,
              temperatureUnit: weather.temperatureUnit,
            );
            combinedForecast.add(weatherWithDate);
          }

          // Add forecast days, but skip if first forecast day is also today
          for (final forecastDay in forecast) {
            if (forecastDay.forecastTime != null) {
              final forecastDate = DateTime(
                forecastDay.forecastTime!.year,
                forecastDay.forecastTime!.month,
                forecastDay.forecastTime!.day,
              );
              // Only add if it's not today (we already added current weather for today)
              if (!forecastDate.isAtSameMomentAs(today)) {
                combinedForecast.add(forecastDay);
              }
            } else {
              combinedForecast.add(forecastDay);
            }
          }

          _currentWeather = weather;
          _weatherForecast = combinedForecast;
          _hourlyWeather = hourly;
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
          margin: EdgeInsets.zero,
          elevation: 6,
          shadowColor: isDark
              ? Colors.brown.withOpacity(0.4)
              : Colors.brown.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        Colors.grey.shade900,
                        Colors.grey.shade800.withOpacity(0.95),
                      ]
                    : [Colors.white, Colors.brown.shade50.withOpacity(0.4)],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Section
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

    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        // All 4 days in a horizontal scrollable row
        if (_weatherForecast.isEmpty) {
          return const SizedBox();
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: _weatherForecast.take(4).map((day) {
              final dayName = _getDayName(day.forecastTime);

              // Get the day number (0=today, 1=tomorrow, 2=day after)
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              final forecastDate = day.forecastTime != null
                  ? DateTime(
                      day.forecastTime!.year,
                      day.forecastTime!.month,
                      day.forecastTime!.day,
                    )
                  : today;
              final dayNumber = forecastDate.difference(today).inDays;

              // Get flow periods for this day
              final dayFlowPeriods = periodsByDay[dayNumber] ?? [];
              final hasFlow = dayFlowPeriods.isNotEmpty;

              String flowInfo = 'No release';
              if (hasFlow) {
                final totalPeriods = dayFlowPeriods.length;
                if (totalPeriods == 1) {
                  final period = dayFlowPeriods.first;
                  // Get arrival times with 15min travel time
                  final firstEntry = period.entries.first;
                  final lastEntry = period.entries.last;
                  final startTime = firstEntry.getArrivalTimeString(
                    travelTimeMinutes: 15,
                  );

                  // Cap end time at civil twilight if it extends past
                  final rawEndTime = lastEntry.getWaterArrivalTime(
                    travelTimeMinutes: 15,
                  );
                  final twilight = _getCivilTwilight(rawEndTime);
                  final cappedEndTime = rawEndTime.isAfter(twilight)
                      ? twilight
                      : rawEndTime;

                  final hour12 = cappedEndTime.hour == 0
                      ? 12
                      : (cappedEndTime.hour > 12
                            ? cappedEndTime.hour - 12
                            : cappedEndTime.hour);
                  final period2 = cappedEndTime.hour < 12 ? 'am' : 'pm';
                  final minuteStr = cappedEndTime.minute.toString().padLeft(
                    2,
                    '0',
                  );
                  final endTime = '$hour12:$minuteStr$period2';

                  // Get weather for this period
                  final weather = _getWeatherForPeriod(period.entries);

                  flowInfo = weather.isNotEmpty
                      ? '$startTime - $endTime\n$weather'
                      : '$startTime - $endTime';
                } else {
                  // Multiple separate periods in one day
                  // Show each period on a separate line with weather
                  final periodTimes = dayFlowPeriods
                      .map((period) {
                        final start = period.entries.first.getArrivalTimeString(
                          travelTimeMinutes: 15,
                        );

                        // Cap end time at civil twilight if it extends past
                        final rawEndTime = period.entries.last
                            .getWaterArrivalTime(travelTimeMinutes: 15);
                        final twilight = _getCivilTwilight(rawEndTime);
                        final cappedEndTime = rawEndTime.isAfter(twilight)
                            ? twilight
                            : rawEndTime;

                        final hour12 = cappedEndTime.hour == 0
                            ? 12
                            : (cappedEndTime.hour > 12
                                  ? cappedEndTime.hour - 12
                                  : cappedEndTime.hour);
                        final period2 = cappedEndTime.hour < 12 ? 'am' : 'pm';
                        final minuteStr = cappedEndTime.minute
                            .toString()
                            .padLeft(2, '0');
                        final end = '$hour12:$minuteStr$period2';

                        final weather = _getWeatherForPeriod(period.entries);
                        return weather.isNotEmpty
                            ? '$start - $end $weather'
                            : '$start - $end';
                      })
                      .join('\n');
                  flowInfo = periodTimes;
                }
              }

              return Container(
                width: 130,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.white.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: hasFlow
                      ? Border.all(
                          color: isDark
                              ? Colors.brown.shade400.withOpacity(0.5)
                              : Colors.brown.shade300.withOpacity(0.7),
                          width: 2,
                        )
                      : null,
                ),
                child: Column(
                  children: [
                    Text(
                      dayName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? Colors.brown.shade200
                            : Colors.brown.shade900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _getWeatherEmoji(day.conditions),
                          style: const TextStyle(fontSize: 36),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${day.temperature.toStringAsFixed(0)}°',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: hasFlow
                            ? (isDark
                                  ? Colors.blue.shade800.withOpacity(0.4)
                                  : Colors.blue.shade100.withOpacity(0.8))
                            : (isDark
                                  ? Colors.grey.shade800.withOpacity(0.3)
                                  : Colors.grey.shade200.withOpacity(0.6)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Dam Release',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: hasFlow
                                  ? (isDark
                                        ? Colors.blue.shade200
                                        : Colors.blue.shade900)
                                  : (isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade700),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            flowInfo,
                            style: TextStyle(
                              fontSize: 11,
                              color: hasFlow
                                  ? (isDark
                                        ? Colors.blue.shade100
                                        : Colors.blue.shade800)
                                  : (isDark
                                        ? Colors.grey.shade500
                                        : Colors.grey.shade600),
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
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
    if (difference == 1) return 'Tomorrow';

    // For all other days, show the actual day of the week
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
                  Colors.brown.withOpacity(0.1),
                  Colors.brown.shade300.withOpacity(0.1),
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
                  Icon(Icons.lock, size: 32, color: Colors.brown[700]),
                  const SizedBox(height: 8),
                  Text(
                    'Unlock ${lockedDaysCount > 1 ? "$lockedDaysCount More Days" : "1 More Day"}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.brown[900],
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
                      backgroundColor: Colors.brown[700],
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
                    color: Colors.brown.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    firstPeriod.dateString,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.brown,
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

              // Get weather for this period
              final weather = _getWeatherForPeriod(period.entries);
              final pastTwilight = _extendsPastTwilight(period.entries);

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
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(
                                Icons.access_time,
                                size: 16,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  period.getArrivalTimeRange(
                                    travelTimeMinutes: 15,
                                  ),
                                  style: const TextStyle(fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (weather.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.brown.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    weather,
                                    style: const TextStyle(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.blue.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.water_drop,
                                size: 14,
                                color: Colors.blue,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                period.flowRangeString,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (pastTwilight) ...[
                      const SizedBox(height: 6),
                      Builder(
                        builder: (context) {
                          // Calculate twilight time for display
                          final lastEntry = period.entries.last;
                          final endTime = lastEntry.getWaterArrivalTime(
                            travelTimeMinutes: 15,
                          );
                          final twilight = _getCivilTwilight(endTime);
                          final twilightStr =
                              '${twilight.hour > 12 ? twilight.hour - 12 : twilight.hour}:${twilight.minute.toString().padLeft(2, '0')}${twilight.hour >= 12 ? 'pm' : 'am'}';

                          return Row(
                            children: [
                              Icon(
                                Icons.nightlight,
                                size: 14,
                                color: Colors.deepPurple[400],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Ends past civil twilight ($twilightStr)',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.deepPurple[400],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
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
        return Colors.brown.shade300;
      case FlowStatus.low:
        return Colors.brown.shade400;
      case FlowStatus.moderate:
        return Colors.green;
      case FlowStatus.high:
        return Colors.brown.shade600;
    }
  }

  /// Get weather conditions for a specific release window
  /// Returns emoji and temperature for the start of the release period
  String _getWeatherForPeriod(List<HourlyFlowEntry> entries) {
    if (_hourlyWeather.isEmpty || entries.isEmpty) return '';

    // Get the arrival time for the first entry (start of release window)
    final firstEntry = entries.first;
    final arrivalTime = firstEntry.getWaterArrivalTime(travelTimeMinutes: 15);

    // Find closest hourly weather forecast
    WeatherData? closestWeather;
    Duration? closestDiff;

    for (final weather in _hourlyWeather) {
      if (weather.forecastTime == null) continue;

      final diff = weather.forecastTime!.difference(arrivalTime).abs();
      if (closestDiff == null || diff < closestDiff) {
        closestDiff = diff;
        closestWeather = weather;
      }

      // If we found a match within 30 minutes, that's good enough
      if (diff.inMinutes < 30) break;
    }

    if (closestWeather != null) {
      final emoji = _getWeatherEmoji(closestWeather.conditions);
      final temp = closestWeather.temperature.toStringAsFixed(0);
      return '$emoji $temp°';
    }

    return '';
  }

  /// Calculate approximate civil twilight (sunset) time for Kananaskis
  /// Civil twilight is when sun is 6° below horizon (safe paddling limit)
  /// Returns approximate sunset time for the given date
  DateTime _getCivilTwilight(DateTime date) {
    // Kananaskis is at 51.1°N, 115.0°W
    // Approximate sunset times for this latitude (Mountain Time)
    // These are rough estimates - civil twilight is ~30min after sunset

    final dayOfYear = DateTime(
      date.year,
      date.month,
      date.day,
    ).difference(DateTime(date.year, 1, 1)).inDays;

    // Simplified sunset calculation for 51°N latitude
    // Summer solstice (June 21, day 172): ~9:30 PM civil twilight
    // Winter solstice (Dec 21, day 355): ~4:30 PM civil twilight
    // Spring/Fall equinox (Mar 20/Sep 22): ~7:00 PM civil twilight

    // Peak to trough amplitude is about 2.5 hours (150 minutes)
    // Centered around 6:30 PM (18.5 hours)
    final baseHour = 18.5; // 6:30 PM
    final amplitude = 2.5; // hours

    // Sine wave with peak around day 172 (summer solstice)
    final angle = 2 * math.pi * (dayOfYear - 172) / 365;
    final offsetHours = amplitude * (-1) * math.cos(angle);

    final twilightHours = baseHour + offsetHours;
    final hour = twilightHours.floor();
    final minute = ((twilightHours - hour) * 60).round();
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  /// Check if a release period extends past civil twilight
  bool _extendsPastTwilight(List<HourlyFlowEntry> entries) {
    if (entries.isEmpty) return false;

    final lastEntry = entries.last;
    final endTime = lastEntry.getWaterArrivalTime(travelTimeMinutes: 15);
    final twilight = _getCivilTwilight(endTime);

    return endTime.isAfter(twilight);
  }
}
