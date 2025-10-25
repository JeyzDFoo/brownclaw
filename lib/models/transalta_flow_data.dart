/// Model for TransAlta Barrier Dam flow data
///
/// Represents flow information for the Barrier Dam and Pocaterra facilities
/// in Kananaskis, Alberta. Data includes hourly forecasts with water arrival
/// times calculated for downstream locations.
class TransAltaFlowData {
  final String name;
  final List<DayForecast> forecasts;
  final DateTime fetchedAt;

  const TransAltaFlowData({
    required this.name,
    required this.forecasts,
    required this.fetchedAt,
  });

  factory TransAltaFlowData.fromJson(Map<String, dynamic> json) {
    final elements = json['elements'] as List<dynamic>? ?? [];

    return TransAltaFlowData(
      name: json['name'] as String? ?? 'pv_hydro_river_flow_by_site',
      forecasts: elements
          .map((e) => DayForecast.fromJson(e as Map<String, dynamic>))
          .toList(),
      fetchedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'elements': forecasts.map((f) => f.toJson()).toList(),
    'fetchedAt': fetchedAt.toIso8601String(),
  };

  /// Get the current (most recent) flow data
  HourlyFlowEntry? get currentFlow {
    if (forecasts.isEmpty || forecasts[0].entries.isEmpty) return null;
    return forecasts[0].entries[0];
  }

  /// Get all high flow hours (above threshold) across all forecast days
  /// Groups consecutive hours into separate periods to handle on/off cycles
  List<HighFlowPeriod> getHighFlowHours({double threshold = 20.0}) {
    final List<HighFlowPeriod> periods = [];

    for (final forecast in forecasts) {
      final date = forecast.getDate();

      // Group consecutive high-flow hours into separate periods
      List<HourlyFlowEntry> currentPeriod = [];

      for (int i = 0; i < forecast.entries.length; i++) {
        final entry = forecast.entries[i];

        if (entry.barrierFlow >= threshold) {
          currentPeriod.add(entry);
        } else {
          // Flow dropped below threshold, save current period if any
          if (currentPeriod.isNotEmpty) {
            periods.add(
              HighFlowPeriod(
                date: date,
                dayNumber: forecast.day,
                entries: List.from(currentPeriod),
                threshold: threshold,
              ),
            );
            currentPeriod = [];
          }
        }
      }

      // Don't forget the last period if it ends at the day boundary
      if (currentPeriod.isNotEmpty) {
        periods.add(
          HighFlowPeriod(
            date: date,
            dayNumber: forecast.day,
            entries: List.from(currentPeriod),
            threshold: threshold,
          ),
        );
      }
    }

    return periods;
  }
}

/// Represents a day's forecast with hourly entries
class DayForecast {
  final int day; // 0 = today, 1 = tomorrow, etc.
  final List<HourlyFlowEntry> entries;

  const DayForecast({required this.day, required this.entries});

  factory DayForecast.fromJson(Map<String, dynamic> json) {
    final entryList = json['entry'] as List<dynamic>? ?? [];

    return DayForecast(
      day: json['day'] as int? ?? 0,
      entries: entryList
          .map((e) => HourlyFlowEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'day': day,
    'entry': entries.map((e) => e.toJson()).toList(),
  };

  /// Get the date for this forecast day (extracted from first entry)
  DateTime getDate() {
    if (entries.isEmpty) return DateTime.now().add(Duration(days: day));
    return entries[0].dateTime;
  }

  /// Get a human-readable date string
  String getDateString() {
    final date = getDate();
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

/// Represents an hourly flow entry
class HourlyFlowEntry {
  final String period; // e.g., "2025-10-17 17"
  final double barrierFlow; // Flow at Barrier Dam in m³/s
  final double pocaterraFlow; // Flow at Pocaterra in m³/s

  const HourlyFlowEntry({
    required this.period,
    required this.barrierFlow,
    required this.pocaterraFlow,
  });

  factory HourlyFlowEntry.fromJson(Map<String, dynamic> json) {
    return HourlyFlowEntry(
      period: json['period'] as String? ?? '',
      barrierFlow: (json['barrier'] as num?)?.toDouble() ?? 0.0,
      pocaterraFlow: (json['pocaterra'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'period': period,
    'barrier': barrierFlow,
    'pocaterra': pocaterraFlow,
  };

  /// Get the hour ending (HE) number from the period
  /// e.g., "2025-10-17 17" -> 17
  int get hourEnding {
    final parts = period.split(' ');
    if (parts.length >= 2) {
      return int.tryParse(parts[1]) ?? 0;
    }
    return 0;
  }

  /// Get the DateTime for this entry
  /// HE17 means flow ends at 17:00 (started at 16:00:01)
  DateTime get dateTime {
    try {
      final parts = period.split(' ');
      if (parts.length >= 2) {
        final datePart = parts[0];
        final hourPart = int.parse(parts[1]);

        // HE hour means flow ENDS at that hour, so we use the start hour
        final startHour = hourPart == 0 ? 0 : hourPart - 1;

        final dateTimeParts = datePart.split('-');
        return DateTime(
          int.parse(dateTimeParts[0]), // year
          int.parse(dateTimeParts[1]), // month
          int.parse(dateTimeParts[2]), // day
          startHour,
        );
      }
    } catch (e) {
      // Fallback to current time
    }
    return DateTime.now();
  }

  /// Get the time when water arrives downstream (add travel time)
  /// Default travel time: 45 minutes from Barrier Dam to Canoe Meadows
  DateTime getWaterArrivalTime({int travelTimeMinutes = 45}) {
    return dateTime.add(Duration(minutes: travelTimeMinutes));
  }

  /// Get a human-readable arrival time string
  /// e.g., "4:45pm"
  String getArrivalTimeString({int travelTimeMinutes = 45}) {
    final arrivalTime = getWaterArrivalTime(
      travelTimeMinutes: travelTimeMinutes,
    );
    final hour = arrivalTime.hour;
    final minute = arrivalTime.minute;

    final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final period = hour < 12 ? 'am' : 'pm';
    final minuteStr = minute.toString().padLeft(2, '0');

    return '$hour12:$minuteStr$period';
  }

  /// Get hour ending formatted string (e.g., "HE17")
  String get hourEndingString => 'HE${hourEnding.toString().padLeft(2, '0')}';

  /// Get flow status based on flow rate
  FlowStatus get flowStatus {
    if (barrierFlow == 0) return FlowStatus.offline;
    if (barrierFlow < 10) return FlowStatus.tooLow;
    if (barrierFlow < 20) return FlowStatus.low;
    if (barrierFlow < 30) return FlowStatus.moderate;
    return FlowStatus.high;
  }
}

/// Represents a period of high flow for a specific day
class HighFlowPeriod {
  final DateTime date;
  final int dayNumber;
  final List<HourlyFlowEntry> entries;
  final double threshold;

  const HighFlowPeriod({
    required this.date,
    required this.dayNumber,
    required this.entries,
    required this.threshold,
  });

  /// Get the first arrival time
  String get firstArrivalTime {
    if (entries.isEmpty) return 'N/A';
    return entries.first.getArrivalTimeString();
  }

  /// Get the last arrival time
  String get lastArrivalTime {
    if (entries.isEmpty) return 'N/A';
    return entries.last.getArrivalTimeString();
  }

  /// Get arrival time range as a string
  String get arrivalTimeRange => '$firstArrivalTime - $lastArrivalTime';

  /// Get the first arrival time with custom travel time
  String getFirstArrivalTime({int travelTimeMinutes = 45}) {
    if (entries.isEmpty) return 'N/A';
    return entries.first.getArrivalTimeString(
      travelTimeMinutes: travelTimeMinutes,
    );
  }

  /// Get the last arrival time with custom travel time
  String getLastArrivalTime({int travelTimeMinutes = 45}) {
    if (entries.isEmpty) return 'N/A';
    return entries.last.getArrivalTimeString(
      travelTimeMinutes: travelTimeMinutes,
    );
  }

  /// Get arrival time range as a string with custom travel time
  String getArrivalTimeRange({int travelTimeMinutes = 45}) {
    return '${getFirstArrivalTime(travelTimeMinutes: travelTimeMinutes)} - ${getLastArrivalTime(travelTimeMinutes: travelTimeMinutes)}';
  }

  /// Get date as string (YYYY-MM-DD)
  String get dateString {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Get friendly day name (Today, Tomorrow, or day of week)
  String get dayName {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final forecastDate = DateTime(date.year, date.month, date.day);

    if (forecastDate == today) {
      return 'Today';
    } else if (forecastDate == tomorrow) {
      return 'Tomorrow';
    } else {
      // Return day of week
      const days = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      return days[forecastDate.weekday - 1];
    }
  }

  /// Get total hours of high flow
  int get totalHours => entries.length;

  /// Get minimum flow in this period
  double get minFlow {
    if (entries.isEmpty) return 0;
    return entries.map((e) => e.barrierFlow).reduce((a, b) => a < b ? a : b);
  }

  /// Get maximum flow in this period
  double get maxFlow {
    if (entries.isEmpty) return 0;
    return entries.map((e) => e.barrierFlow).reduce((a, b) => a > b ? a : b);
  }

  /// Get average flow in this period
  double get avgFlow {
    if (entries.isEmpty) return 0;
    final sum = entries.map((e) => e.barrierFlow).reduce((a, b) => a + b);
    return sum / entries.length;
  }

  /// Get flow range as a string (e.g., "20-25 m³/s" or "22 m³/s" if constant)
  String get flowRangeString {
    if (entries.isEmpty) return 'N/A';
    final min = minFlow;
    final max = maxFlow;

    if (min == max) {
      return '${min.toStringAsFixed(0)} m³/s';
    } else {
      return '${min.toStringAsFixed(0)}-${max.toStringAsFixed(0)} m³/s';
    }
  }
}

/// Flow status levels based on flow rate
enum FlowStatus {
  offline, // 0 m³/s - plant offline
  tooLow, // < 10 m³/s
  low, // 10-20 m³/s
  moderate, // 20-30 m³/s
  high, // 30+ m³/s
}

extension FlowStatusExtension on FlowStatus {
  String get displayName {
    switch (this) {
      case FlowStatus.offline:
        return 'Offline';
      case FlowStatus.tooLow:
        return 'Too Low';
      case FlowStatus.low:
        return 'Low';
      case FlowStatus.moderate:
        return 'Moderate';
      case FlowStatus.high:
        return 'High';
    }
  }

  String get description {
    switch (this) {
      case FlowStatus.offline:
        return 'Plant offline or not generating';
      case FlowStatus.tooLow:
        return 'Flow too low for most activities';
      case FlowStatus.low:
        return 'Low flow, suitable for beginners';
      case FlowStatus.moderate:
        return 'Good flow for intermediate paddlers';
      case FlowStatus.high:
        return 'High flow, advanced paddlers only';
    }
  }

  String get emoji {
    switch (this) {
      case FlowStatus.offline:
        return '⚠️';
      case FlowStatus.tooLow:
        return '💧';
      case FlowStatus.low:
        return '💧';
      case FlowStatus.moderate:
        return '🌊';
      case FlowStatus.high:
        return '🌊🌊';
    }
  }
}
