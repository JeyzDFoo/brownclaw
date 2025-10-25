/// Weather data model for displaying forecast information
/// alongside river flow data
class WeatherData {
  final double latitude;
  final double longitude;
  final double temperature;
  final String conditions;
  final double precipitation;
  final double? windSpeed;
  final int? humidity;
  final DateTime? forecastTime;
  final String? temperatureUnit;

  const WeatherData({
    required this.latitude,
    required this.longitude,
    required this.temperature,
    required this.conditions,
    required this.precipitation,
    this.windSpeed,
    this.humidity,
    this.forecastTime,
    this.temperatureUnit = 'C',
  });

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'temperature': temperature,
      'conditions': conditions,
      'precipitation': precipitation,
      'windSpeed': windSpeed,
      'humidity': humidity,
      'forecastTime': forecastTime?.toIso8601String(),
      'temperatureUnit': temperatureUnit,
    };
  }

  factory WeatherData.fromMap(Map<String, dynamic> map) {
    return WeatherData(
      latitude: map['latitude'] as double,
      longitude: map['longitude'] as double,
      temperature: map['temperature'] as double,
      conditions: map['conditions'] as String,
      precipitation: map['precipitation'] as double,
      windSpeed: map['windSpeed'] as double?,
      humidity: map['humidity'] as int?,
      forecastTime: map['forecastTime'] != null
          ? DateTime.parse(map['forecastTime'] as String)
          : null,
      temperatureUnit: map['temperatureUnit'] as String? ?? 'C',
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is WeatherData &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.temperature == temperature &&
        other.conditions == conditions &&
        other.precipitation == precipitation &&
        other.windSpeed == windSpeed &&
        other.humidity == humidity &&
        other.forecastTime == forecastTime &&
        other.temperatureUnit == temperatureUnit;
  }

  @override
  int get hashCode {
    return Object.hash(
      latitude,
      longitude,
      temperature,
      conditions,
      precipitation,
      windSpeed,
      humidity,
      forecastTime,
      temperatureUnit,
    );
  }
}
