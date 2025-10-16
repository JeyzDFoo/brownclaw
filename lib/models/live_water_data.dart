import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents live water data from a gauge station
/// #todo: Replace all Map<String, dynamic> live data usage with this typed model
class LiveWaterData {
  final String stationId;
  final String stationName;
  final double? flowRate; // Discharge in m³/s
  final double? waterLevel; // Water level in meters
  final double? temperature; // Water temperature in °C
  final DateTime timestamp;
  final String dataSource; // 'csv', 'json', 'cache'
  final LiveDataStatus status;
  final String? unit; // Flow rate unit (m³/s, cfs, etc.)

  const LiveWaterData({
    required this.stationId,
    required this.stationName,
    this.flowRate,
    this.waterLevel,
    this.temperature,
    required this.timestamp,
    required this.dataSource,
    required this.status,
    this.unit,
  });

  /// Create from raw API response data
  /// #todo: Replace LiveWaterDataService._fetchFromCsvDataMart return type
  factory LiveWaterData.fromApiResponse(
    String stationId,
    Map<String, dynamic> rawData,
    String dataSource,
  ) {
    return LiveWaterData(
      stationId: stationId,
      stationName: rawData['stationName'] as String? ?? 'Unknown Station',
      flowRate: _safeToDouble(rawData['flowRate']),
      waterLevel: _safeToDouble(rawData['level']),
      temperature: _safeToDouble(rawData['temperature']),
      timestamp: _parseTimestamp(rawData['lastUpdate']) ?? DateTime.now(),
      dataSource: dataSource,
      status: _parseStatus(rawData['status']),
      unit: rawData['unit'] as String? ?? 'm³/s',
    );
  }

  /// Create from cached data
  /// #todo: Replace _liveDataCache Map<String, dynamic> usage
  factory LiveWaterData.fromCache(Map<String, dynamic> cachedData) {
    return LiveWaterData(
      stationId: cachedData['stationId'] as String,
      stationName: cachedData['stationName'] as String,
      flowRate: _safeToDouble(cachedData['flowRate']),
      waterLevel: _safeToDouble(cachedData['waterLevel']),
      temperature: _safeToDouble(cachedData['temperature']),
      timestamp: DateTime.parse(cachedData['timestamp'] as String),
      dataSource: cachedData['dataSource'] as String,
      status: LiveDataStatus.values.firstWhere(
        (s) => s.name == cachedData['status'],
        orElse: () => LiveDataStatus.unavailable,
      ),
      unit: cachedData['unit'] as String?,
    );
  }

  /// Convert to Map for caching
  /// #todo: Replace cache storage with this typed approach
  Map<String, dynamic> toMap() {
    return {
      'stationId': stationId,
      'stationName': stationName,
      'flowRate': flowRate,
      'waterLevel': waterLevel,
      'temperature': temperature,
      'timestamp': timestamp.toIso8601String(),
      'dataSource': dataSource,
      'status': status.name,
      'unit': unit,
    };
  }

  /// Check if data is fresh (within acceptable age limit)
  bool get isFresh {
    final age = DateTime.now().difference(timestamp);
    return age.inMinutes <= 10; // Consider data fresh for 10 minutes
  }

  /// Check if data has flow information
  bool get hasFlowData => flowRate != null && flowRate! > 0;

  /// Check if data has level information
  bool get hasLevelData => waterLevel != null;

  /// Get human-readable status
  String get statusText {
    switch (status) {
      case LiveDataStatus.live:
        return 'Live';
      case LiveDataStatus.delayed:
        return 'Delayed';
      case LiveDataStatus.cached:
        return 'Cached';
      case LiveDataStatus.unavailable:
        return 'Unavailable';
    }
  }

  /// Get formatted flow rate with units
  String get formattedFlowRate {
    if (flowRate == null) return 'N/A';
    return '${flowRate!.toStringAsFixed(2)} ${unit ?? 'm³/s'}';
  }

  /// Get formatted water level
  String get formattedWaterLevel {
    if (waterLevel == null) return 'N/A';
    return '${waterLevel!.toStringAsFixed(2)} m';
  }

  /// Get age of data in human readable format
  String get dataAge {
    final age = DateTime.now().difference(timestamp);
    if (age.inMinutes < 60) {
      return '${age.inMinutes}m ago';
    } else if (age.inHours < 24) {
      return '${age.inHours}h ago';
    } else {
      return '${age.inDays}d ago';
    }
  }

  @override
  String toString() => 'LiveWaterData($stationId: ${formattedFlowRate})';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LiveWaterData &&
        other.stationId == stationId &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode => Object.hash(stationId, timestamp);

  // Helper methods
  static double? _safeToDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is Timestamp) return value.toDate();
    return null;
  }

  static LiveDataStatus _parseStatus(dynamic value) {
    if (value == null) return LiveDataStatus.unavailable;
    final statusStr = value.toString().toLowerCase();
    if (statusStr.contains('live')) return LiveDataStatus.live;
    if (statusStr.contains('delayed')) return LiveDataStatus.delayed;
    if (statusStr.contains('cache')) return LiveDataStatus.cached;
    return LiveDataStatus.unavailable;
  }
}

/// Enum for live data status
enum LiveDataStatus { live, delayed, cached, unavailable }

/// Represents flow conditions for a river run
/// #todo: Replace flow status Map<String, dynamic> with this typed model
class FlowCondition {
  final double currentFlow;
  final double? minRunnable;
  final double? maxSafe;
  final double? optimal;
  final FlowStatus status;
  final String statusLabel;
  final int colorValue; // Store color as int for JSON serialization

  const FlowCondition({
    required this.currentFlow,
    this.minRunnable,
    this.maxSafe,
    this.optimal,
    required this.status,
    required this.statusLabel,
    required this.colorValue,
  });

  /// Create from current flow and recommended ranges
  factory FlowCondition.fromFlow(
    double currentFlow, {
    double? minRunnable,
    double? maxSafe,
    double? optimal,
  }) {
    // Use realistic defaults if not provided
    minRunnable ??= currentFlow * 0.5;
    maxSafe ??= currentFlow * 3.0;
    optimal ??= currentFlow;

    FlowStatus status;
    String label;
    int color;

    if (currentFlow < minRunnable * 0.7) {
      status = FlowStatus.tooLow;
      label = 'Too Low';
      color = 0xFFE53E3E; // Red
    } else if (currentFlow < minRunnable) {
      status = FlowStatus.low;
      label = 'Low';
      color = 0xFFFF8C00; // Orange
    } else if (currentFlow <= maxSafe) {
      status = FlowStatus.good;
      label = 'Good';
      color = 0xFF38A169; // Green
    } else if (currentFlow <= maxSafe * 1.2) {
      status = FlowStatus.high;
      label = 'High';
      color = 0xFFFF8C00; // Orange
    } else {
      status = FlowStatus.tooHigh;
      label = 'Too High';
      color = 0xFFE53E3E; // Red
    }

    return FlowCondition(
      currentFlow: currentFlow,
      minRunnable: minRunnable,
      maxSafe: maxSafe,
      optimal: optimal,
      status: status,
      statusLabel: label,
      colorValue: color,
    );
  }

  /// Get formatted flow with status
  String get formattedFlow =>
      '${currentFlow.toStringAsFixed(2)} m³/s ($statusLabel)';

  @override
  String toString() => formattedFlow;
}

/// Enum for flow status
enum FlowStatus { tooLow, low, good, high, tooHigh }
