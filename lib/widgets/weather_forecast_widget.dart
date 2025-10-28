import 'package:flutter/material.dart';
import '../models/weather_data.dart';

/// Widget to display weather forecast for a river location
class WeatherForecastWidget extends StatelessWidget {
  final List<WeatherData> forecast;
  final bool isLoading;
  final String? error;

  const WeatherForecastWidget({
    super.key,
    required this.forecast,
    this.isLoading = false,
    this.error,
  });

  IconData _getWeatherIcon(String conditions) {
    final lower = conditions.toLowerCase();
    if (lower.contains('clear')) return Icons.wb_sunny;
    if (lower.contains('cloud')) return Icons.wb_cloudy;
    if (lower.contains('rain') || lower.contains('drizzle')) {
      return Icons.water_drop;
    }
    if (lower.contains('snow')) return Icons.ac_unit;
    if (lower.contains('thunder')) return Icons.flash_on;
    if (lower.contains('fog')) return Icons.cloud;
    return Icons.cloud_outlined;
  }

  Color _getWeatherColor(String conditions) {
    final lower = conditions.toLowerCase();
    if (lower.contains('clear')) return Colors.orange;
    if (lower.contains('cloud')) return Colors.grey;
    if (lower.contains('rain') || lower.contains('drizzle')) {
      return Colors.blue;
    }
    if (lower.contains('snow')) return Colors.lightBlue;
    if (lower.contains('thunder')) return Colors.deepPurple;
    if (lower.contains('fog')) return Colors.blueGrey;
    return Colors.grey;
  }

  String _formatDay(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final checkDate = DateTime(date.year, date.month, date.day);

    if (checkDate == today) return 'Today';
    if (checkDate == tomorrow) return 'Tomorrow';

    // Return day of week
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.wb_sunny_outlined, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Weather Forecast',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (isLoading)
              const SizedBox(
                height: 150, // Match the forecast height
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.teal,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Loading weather forecast...',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )
            else if (error != null)
              SizedBox(
                height: 150, // Match the forecast height
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Colors.red[300],
                        size: 48,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Weather data unavailable',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
              )
            else if (forecast.isEmpty)
              SizedBox(
                height: 150, // Match the forecast height
                child: Center(
                  child: Text(
                    'No forecast available',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              )
            else
              // Horizontal scrollable forecast
              SizedBox(
                height: 150,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: forecast.length,
                  itemBuilder: (context, index) {
                    final day = forecast[index];
                    final date = day.forecastTime ?? DateTime.now();

                    return Container(
                      width: 100,
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[800]
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Day label
                          Text(
                            _formatDay(date),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),

                          // Weather icon
                          Icon(
                            _getWeatherIcon(day.conditions),
                            color: _getWeatherColor(day.conditions),
                            size: 32,
                          ),
                          const SizedBox(height: 6),

                          // Temperature
                          Text(
                            '${day.temperature.toStringAsFixed(0)}°${day.temperatureUnit}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 3),

                          // Conditions
                          Text(
                            day.conditions,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),

                          // Precipitation if any
                          if (day.precipitation > 0)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.water_drop,
                                  size: 10,
                                  color: Colors.blue[400],
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '${day.precipitation.toStringAsFixed(0)}mm',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.blue[600],
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
