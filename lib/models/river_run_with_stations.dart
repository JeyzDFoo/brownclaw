import '../models/models.dart';

/// Composite model that represents a RiverRun with its associated GaugeStations
/// This makes it easier to work with the hierarchical data in UI components
class RiverRunWithStations {
  final RiverRun run;
  final List<GaugeStation> stations;
  final River? river; // Optional parent river information

  const RiverRunWithStations({
    required this.run,
    required this.stations,
    this.river,
  });

  // Convenience getters
  String get id => run.id;
  String get name => run.name;
  String get difficultyClass => run.difficultyClass;
  String? get description => run.description;

  // Enhanced display name that includes river name when available
  String get displayName {
    if (river != null && river!.name != 'Unknown River') {
      print(
        '✅ RiverRunWithStations displayName - Using river: ${river!.name} (${run.name}) - ${run.difficultyClass}',
      );
      return '${river!.name} (${run.name}) - ${run.difficultyClass}';
    }

    // If no valid river or river name is "Unknown River", try to extract from run name
    print(
      '⚠️  RiverRunWithStations displayName - No valid river (${river?.name}), checking run name: "${run.name}"',
    );

    if (run.name != 'Unknown Section' && run.name.contains(' at ')) {
      // If run name contains location info, it might be the full station name
      // Try to extract meaningful parts
      final parts = run.name.split(' at ');
      if (parts.length >= 2) {
        final riverPart = parts[0].trim();
        final locationPart = parts[1].trim();
        print(
          '✅ RiverRunWithStations displayName - Extracted from run name: $riverPart ($locationPart) - ${run.difficultyClass}',
        );
        return '$riverPart ($locationPart) - ${run.difficultyClass}';
      }
    }

    print(
      '❌ RiverRunWithStations displayName - Using fallback: ${run.displayName}',
    );
    return run.displayName; // Fallback to original format
  } // Flow status based on first station with current data

  String get flowStatus {
    // If we have a direct stationId, we need to fetch live data
    if (run.stationId != null && run.stationId!.isNotEmpty) {
      return 'Fetching...'; // Will be updated by live data service
    }

    if (stations.isEmpty) return 'No Data';

    final stationWithData = stations.firstWhere(
      (station) => station.currentDischarge != null,
      orElse: () => stations.first,
    );

    if (stationWithData.currentDischarge == null) {
      return 'No Data';
    }

    return run.getFlowStatus(stationWithData.currentDischarge);
  }

  // Get the primary station (first one or the one with best data)
  GaugeStation? get primaryStation {
    if (stations.isEmpty) return null;

    // Prefer stations with live data
    final liveStations = stations.where((s) => s.hasLiveData).toList();
    if (liveStations.isNotEmpty) {
      return liveStations.first;
    }

    return stations.first;
  }

  // Get current discharge - prefer from run's stationId if available
  double? get currentDischarge {
    // If the run has a stationId, we should fetch live data directly
    if (run.stationId != null && run.stationId!.isNotEmpty) {
      // Return null for now - live data will be fetched separately
      // This allows the UI to trigger live data fetching
      return null;
    }
    return primaryStation?.currentDischarge;
  }

  // Get current water level - prefer from run's stationId if available
  double? get currentWaterLevel {
    // If the run has a stationId, we should fetch live data directly
    if (run.stationId != null && run.stationId!.isNotEmpty) {
      // Return null for now - live data will be fetched separately
      return null;
    }
    return primaryStation?.currentWaterLevel;
  }

  // Check if we have live data capability
  bool get hasLiveData {
    // If run has stationId, it can potentially have live data
    if (run.stationId != null && run.stationId!.isNotEmpty) {
      return true; // Assume capability exists
    }
    return stations.any((station) => station.hasLiveData);
  }

  // Get the station ID for live data fetching
  String? get liveDataStationId {
    // Prefer the run's direct stationId
    if (run.stationId != null && run.stationId!.isNotEmpty) {
      return run.stationId;
    }
    // Fallback to primary station
    return primaryStation?.stationId;
  }

  // Get the most recent data update time
  DateTime? get lastDataUpdate {
    final updates = stations
        .map((s) => s.lastDataUpdate)
        .where((d) => d != null)
        .cast<DateTime>()
        .toList();

    if (updates.isEmpty) return null;

    updates.sort((a, b) => b.compareTo(a));
    return updates.first;
  }

  // Create a copy with modified values
  RiverRunWithStations copyWith({
    RiverRun? run,
    List<GaugeStation>? stations,
    River? river,
  }) {
    return RiverRunWithStations(
      run: run ?? this.run,
      stations: stations ?? this.stations,
      river: river ?? this.river,
    );
  }

  // Serialization for persistent cache
  Map<String, dynamic> toMap({bool forCache = true}) {
    return {
      'run': run.toMap(forCache: forCache),
      'stations': stations.map((s) => s.toMap(forCache: forCache)).toList(),
      'river': river?.toMap(forCache: forCache),
    };
  }

  // Deserialization from persistent cache
  factory RiverRunWithStations.fromMap(Map<String, dynamic> map) {
    return RiverRunWithStations(
      run: RiverRun.fromMap(map['run'] as Map<String, dynamic>),
      stations: (map['stations'] as List<dynamic>)
          .map((s) => GaugeStation.fromMap(s as Map<String, dynamic>))
          .toList(),
      river: map['river'] != null
          ? River.fromMap(map['river'] as Map<String, dynamic>)
          : null,
    );
  }

  @override
  String toString() => '$displayName (${stations.length} stations)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RiverRunWithStations && other.run.id == run.id;
  }

  @override
  int get hashCode => run.id.hashCode;
}
