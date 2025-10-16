import 'package:flutter_test/flutter_test.dart';
import 'package:brownclaw/models/river.dart';
import 'package:brownclaw/models/river_run.dart';
import 'package:brownclaw/models/gauge_station.dart';

void main() {
  group('Integration Tests - River System', () {
    test('should create a complete river system with runs and stations', () {
      // Create a river
      final river = River(
        id: 'kicking-horse',
        name: 'Kicking Horse River',
        region: 'British Columbia',
        country: 'Canada',
        description: 'World-class whitewater destination',
      );

      // Create river runs on this river
      final lowerCanyon = RiverRun(
        id: 'kh-lower',
        riverId: river.id,
        name: 'Lower Canyon',
        difficultyClass: 'Class III-IV',
        length: 8.0,
        minRecommendedFlow: 25.0,
        maxRecommendedFlow: 120.0,
        optimalFlowMin: 40.0,
        optimalFlowMax: 80.0,
        flowUnit: 'cms',
      );

      final upperCanyon = RiverRun(
        id: 'kh-upper',
        riverId: river.id,
        name: 'Upper Canyon',
        difficultyClass: 'Class V',
        length: 5.0,
        minRecommendedFlow: 30.0,
        maxRecommendedFlow: 100.0,
        optimalFlowMin: 50.0,
        optimalFlowMax: 80.0,
        flowUnit: 'cms',
      );

      // Create a gauge station
      final station = GaugeStation(
        stationId: '05AD007',
        name: 'Kicking Horse River at Golden',
        associatedRiverRunIds: [lowerCanyon.id, upperCanyon.id],
        latitude: 51.2963,
        longitude: -116.9633,
        agency: 'Environment Canada',
        region: 'British Columbia',
        country: 'Canada',
        isActive: true,
        parameters: ['discharge', 'water_level', 'temperature'],
        currentDischarge: 65.0,
        dataStatus: 'live',
      );

      // Verify the river system structure
      expect(river.name, 'Kicking Horse River');
      expect(lowerCanyon.riverId, river.id);
      expect(upperCanyon.riverId, river.id);
      expect(station.associatedRiverRunIds, contains(lowerCanyon.id));
      expect(station.associatedRiverRunIds, contains(upperCanyon.id));

      // Test flow recommendations
      expect(lowerCanyon.getFlowStatus(65.0), 'Optimal');
      expect(upperCanyon.getFlowStatus(65.0), 'Optimal');

      // Test station capabilities
      expect(station.measuresDischarge, true);
      expect(station.measuresWaterLevel, true);
      expect(station.measuresTemperature, true);
    });

    test('should handle multiple rivers and runs', () {
      final rivers = [
        River(
          id: 'ottawa',
          name: 'Ottawa River',
          region: 'Ontario',
          country: 'Canada',
        ),
        River(
          id: 'bow',
          name: 'Bow River',
          region: 'Alberta',
          country: 'Canada',
        ),
      ];

      final runs = [
        RiverRun(
          id: 'ottawa-1',
          riverId: 'ottawa',
          name: 'Champlain Bridge',
          difficultyClass: 'Class I-II',
        ),
        RiverRun(
          id: 'bow-1',
          riverId: 'bow',
          name: 'Harvey Passage',
          difficultyClass: 'Class II-III',
        ),
      ];

      // Group runs by river
      final runsByRiver = <String, List<RiverRun>>{};
      for (final run in runs) {
        runsByRiver.putIfAbsent(run.riverId, () => []).add(run);
      }

      expect(runsByRiver['ottawa']?.length, 1);
      expect(runsByRiver['bow']?.length, 1);
      expect(runsByRiver['ottawa']?.first.name, 'Champlain Bridge');
      expect(runsByRiver['bow']?.first.name, 'Harvey Passage');
    });

    test('should serialize and deserialize complete system', () {
      // Create original objects
      final originalRiver = River(
        id: 'test-river',
        name: 'Test River',
        region: 'Test Region',
        country: 'Canada',
      );

      final originalRun = RiverRun(
        id: 'test-run',
        riverId: originalRiver.id,
        name: 'Test Run',
        difficultyClass: 'Class III',
        minRecommendedFlow: 20.0,
        maxRecommendedFlow: 100.0,
      );

      final originalStation = GaugeStation(
        stationId: 'TEST-001',
        name: 'Test Station',
        associatedRiverRunIds: [originalRun.id],
        latitude: 50.0,
        longitude: -115.0,
        isActive: true,
        parameters: ['discharge'],
      );

      // Convert to maps (as if storing in Firestore)
      final riverMap = originalRiver.toMap();
      final runMap = originalRun.toMap();
      final stationMap = originalStation.toMap();

      // Recreate from maps
      final restoredRiver = River.fromMap(riverMap, docId: originalRiver.id);
      final restoredRun = RiverRun.fromMap(runMap, docId: originalRun.id);
      final restoredStation = GaugeStation.fromMap(stationMap);

      // Verify integrity
      expect(restoredRiver, originalRiver);
      expect(restoredRun, originalRun);
      expect(restoredStation, originalStation);
      expect(restoredRun.riverId, restoredRiver.id);
      expect(restoredStation.associatedRiverRunIds, contains(restoredRun.id));
    });

    test('should handle flow status across multiple runs', () {
      final runs = [
        RiverRun(
          id: 'easy-run',
          riverId: 'river-1',
          name: 'Easy Section',
          difficultyClass: 'Class II',
          minRecommendedFlow: 10.0,
          maxRecommendedFlow: 50.0,
        ),
        RiverRun(
          id: 'hard-run',
          riverId: 'river-1',
          name: 'Hard Section',
          difficultyClass: 'Class V',
          minRecommendedFlow: 30.0,
          maxRecommendedFlow: 80.0,
        ),
      ];

      const currentFlow = 40.0;

      // Check which runs are runnable
      final runnableRuns = runs.where((run) {
        final status = run.getFlowStatus(currentFlow);
        return status == 'Optimal' || status == 'Runnable';
      }).toList();

      expect(runnableRuns.length, 2);
      expect(
        runnableRuns.map((r) => r.name),
        containsAll(['Easy Section', 'Hard Section']),
      );
    });

    test('should filter runs by difficulty', () {
      final allRuns = [
        RiverRun(
          id: 'run-1',
          riverId: 'river-1',
          name: 'Beginner Run',
          difficultyClass: 'Class I',
        ),
        RiverRun(
          id: 'run-2',
          riverId: 'river-1',
          name: 'Intermediate Run',
          difficultyClass: 'Class III',
        ),
        RiverRun(
          id: 'run-3',
          riverId: 'river-1',
          name: 'Advanced Run',
          difficultyClass: 'Class V',
        ),
      ];

      // Filter for beginner/intermediate
      final easyRuns = allRuns.where((run) {
        return run.difficultyClass.contains('I') &&
            !run.difficultyClass.contains('IV') &&
            !run.difficultyClass.contains('V');
      }).toList();

      expect(easyRuns.length, 2);
      expect(
        easyRuns.map((r) => r.name),
        containsAll(['Beginner Run', 'Intermediate Run']),
      );
    });

    test('should find active stations for a region', () {
      final stations = [
        GaugeStation(
          stationId: 'BC-001',
          name: 'BC Station 1',
          latitude: 51.0,
          longitude: -116.0,
          region: 'British Columbia',
          isActive: true,
          parameters: ['discharge'],
        ),
        GaugeStation(
          stationId: 'BC-002',
          name: 'BC Station 2',
          latitude: 51.5,
          longitude: -116.5,
          region: 'British Columbia',
          isActive: false,
          parameters: ['discharge'],
        ),
        GaugeStation(
          stationId: 'AB-001',
          name: 'AB Station 1',
          latitude: 51.0,
          longitude: -114.0,
          region: 'Alberta',
          isActive: true,
          parameters: ['discharge'],
        ),
      ];

      final activeBCStations = stations.where((s) {
        return s.region == 'British Columbia' && s.isActive;
      }).toList();

      expect(activeBCStations.length, 1);
      expect(activeBCStations.first.stationId, 'BC-001');
    });

    test('should calculate distance between stations (simplified)', () {
      final station1 = GaugeStation(
        stationId: 'STATION-1',
        name: 'Station 1',
        latitude: 51.0,
        longitude: -116.0,
        isActive: true,
        parameters: ['discharge'],
      );

      final station2 = GaugeStation(
        stationId: 'STATION-2',
        name: 'Station 2',
        latitude: 51.5,
        longitude: -116.5,
        isActive: true,
        parameters: ['discharge'],
      );

      // Simple difference calculation (not actual distance)
      final latDiff = (station2.latitude - station1.latitude).abs();
      final lonDiff = (station2.longitude - station1.longitude).abs();

      expect(latDiff, 0.5);
      expect(lonDiff, 0.5);
      expect(latDiff > 0 && lonDiff > 0, true);
    });
  });
}
