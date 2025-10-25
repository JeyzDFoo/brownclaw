import 'package:flutter_test/flutter_test.dart';
import 'package:brownclaw/models/river_run.dart';
import 'package:brownclaw/models/river_run_with_stations.dart';
import 'package:brownclaw/models/gauge_station.dart';

/// Integration test for RiverRun business logic
/// Tests the complete model validation without requiring Firebase
///
/// This validates the current working app's model layer:
/// 1. RiverRun model creation and validation
/// 2. Flow status calculation logic
/// 3. Data serialization/deserialization
/// 4. RiverRunWithStations composite model
void main() {
  group('RiverRun Model Integration Test', () {
    test('should create a valid river run with all fields', () {
      // Given: Complete river run data
      final run = RiverRun(
        id: 'kicking-horse-lower',
        riverId: 'kicking-horse',
        name: 'Lower Canyon',
        difficultyClass: 'Class III-IV',
        length: 8.0,
        minRecommendedFlow: 25.0,
        maxRecommendedFlow: 120.0,
        optimalFlowMin: 40.0,
        optimalFlowMax: 80.0,
        flowUnit: 'cms',
        description: 'Classic whitewater run',
        putIn: 'Highway bridge',
        takeOut: 'Parking lot',
      );

      // Then: All fields should be accessible
      expect(run.id, 'kicking-horse-lower');
      expect(run.name, 'Lower Canyon');
      expect(run.difficultyClass, 'Class III-IV');
      expect(run.length, 8.0);
      expect(run.flowUnit, 'cms');
      expect(run.description, 'Classic whitewater run');
    });

    test('should calculate flow status correctly - Optimal', () {
      // Given: A river run with defined optimal range
      final run = RiverRun(
        id: 'test-run',
        riverId: 'test-river',
        name: 'Test Run',
        difficultyClass: 'Class III',
        minRecommendedFlow: 25.0,
        maxRecommendedFlow: 120.0,
        optimalFlowMin: 40.0,
        optimalFlowMax: 80.0,
      );

      // When: Current flow is in optimal range
      const currentFlow = 60.0;

      // Then: Should return 'Optimal'
      expect(run.getFlowStatus(currentFlow), 'Optimal');
    });

    test('should calculate flow status correctly - Runnable (low)', () {
      // Given: A river run
      final run = RiverRun(
        id: 'test-run',
        riverId: 'test-river',
        name: 'Test Run',
        difficultyClass: 'Class III',
        minRecommendedFlow: 25.0,
        maxRecommendedFlow: 120.0,
        optimalFlowMin: 40.0,
        optimalFlowMax: 80.0,
      );

      // When: Current flow is below optimal but above minimum
      const currentFlow = 30.0;

      // Then: Should return 'Runnable'
      expect(run.getFlowStatus(currentFlow), 'Runnable');
    });

    test('should calculate flow status correctly - Runnable (high)', () {
      // Given: A river run
      final run = RiverRun(
        id: 'test-run',
        riverId: 'test-river',
        name: 'Test Run',
        difficultyClass: 'Class III',
        minRecommendedFlow: 25.0,
        maxRecommendedFlow: 120.0,
        optimalFlowMin: 40.0,
        optimalFlowMax: 80.0,
      );

      // When: Current flow is above optimal but below maximum
      const currentFlow = 100.0;

      // Then: Should return 'Runnable'
      expect(run.getFlowStatus(currentFlow), 'Runnable');
    });

    test('should calculate flow status correctly - Too Low', () {
      // Given: A river run
      final run = RiverRun(
        id: 'test-run',
        riverId: 'test-river',
        name: 'Test Run',
        difficultyClass: 'Class III',
        minRecommendedFlow: 25.0,
        maxRecommendedFlow: 120.0,
      );

      // When: Current flow is below minimum
      const currentFlow = 10.0;

      // Then: Should return 'Too Low'
      expect(run.getFlowStatus(currentFlow), 'Too Low');
    });

    test('should calculate flow status correctly - Too High', () {
      // Given: A river run
      final run = RiverRun(
        id: 'test-run',
        riverId: 'test-river',
        name: 'Test Run',
        difficultyClass: 'Class III',
        minRecommendedFlow: 25.0,
        maxRecommendedFlow: 120.0,
      );

      // When: Current flow is above maximum
      const currentFlow = 150.0;

      // Then: Should return 'Too High'
      expect(run.getFlowStatus(currentFlow), 'Too High');
    });

    test('should serialize and deserialize correctly', () {
      // Given: A river run
      final originalRun = RiverRun(
        id: 'test-run',
        riverId: 'test-river',
        name: 'Test Run',
        difficultyClass: 'Class III',
        length: 10.5,
        minRecommendedFlow: 20.0,
        maxRecommendedFlow: 100.0,
        optimalFlowMin: 40.0,
        optimalFlowMax: 70.0,
        flowUnit: 'cms',
        description: 'A test run',
        putIn: 'River access',
        takeOut: 'Bridge',
      );

      // When: Converting to map and back
      final map = originalRun.toMap();
      final restoredRun = RiverRun.fromMap(map, docId: 'test-run');

      // Then: Should be identical
      expect(restoredRun, originalRun);
      expect(restoredRun.id, originalRun.id);
      expect(restoredRun.name, originalRun.name);
      expect(restoredRun.difficultyClass, originalRun.difficultyClass);
      expect(restoredRun.length, originalRun.length);
      expect(restoredRun.flowUnit, originalRun.flowUnit);
    });

    test('should handle RiverRunWithStations composite model', () {
      // Given: A river run and associated stations
      final run = RiverRun(
        id: 'test-run',
        riverId: 'test-river',
        name: 'Test Run',
        difficultyClass: 'Class III',
      );

      final stations = [
        const GaugeStation(
          stationId: 'STATION-001',
          name: 'Station 1',
          latitude: 51.0,
          longitude: -115.0,
          isActive: true,
          parameters: ['discharge'],
        ),
        const GaugeStation(
          stationId: 'STATION-002',
          name: 'Station 2',
          latitude: 51.1,
          longitude: -115.1,
          isActive: true,
          parameters: ['discharge'],
        ),
      ];

      // When: Creating composite model
      final composite = RiverRunWithStations(run: run, stations: stations);

      // Then: Should contain both run and stations
      expect(composite.run, run);
      expect(composite.stations, stations);
      expect(composite.stations.length, 2);
      expect(composite.id, run.id);
      expect(composite.name, run.name);
    });

    test('should support copyWith for immutable updates', () {
      // Given: A river run
      final originalRun = RiverRun(
        id: 'test-run',
        riverId: 'test-river',
        name: 'Original Name',
        difficultyClass: 'Class III',
      );

      // When: Updating with copyWith
      final updatedRun = originalRun.copyWith(
        name: 'Updated Name',
        difficultyClass: 'Class IV',
      );

      // Then: Should have updated fields but keep others
      expect(updatedRun.name, 'Updated Name');
      expect(updatedRun.difficultyClass, 'Class IV');
      expect(updatedRun.id, originalRun.id); // Unchanged
      expect(updatedRun.riverId, originalRun.riverId); // Unchanged
    });

    test('should handle multiple runs for the same river', () {
      // Given: Multiple runs on the same river
      const riverId = 'kicking-horse';

      final runs = [
        RiverRun(
          id: 'kh-lower',
          riverId: riverId,
          name: 'Lower Canyon',
          difficultyClass: 'Class III-IV',
          minRecommendedFlow: 25.0,
          maxRecommendedFlow: 120.0,
        ),
        RiverRun(
          id: 'kh-middle',
          riverId: riverId,
          name: 'Middle Canyon',
          difficultyClass: 'Class IV',
          minRecommendedFlow: 30.0,
          maxRecommendedFlow: 100.0,
        ),
        RiverRun(
          id: 'kh-upper',
          riverId: riverId,
          name: 'Upper Canyon',
          difficultyClass: 'Class V',
          minRecommendedFlow: 40.0,
          maxRecommendedFlow: 90.0,
        ),
      ];

      // When: Checking which runs are runnable at current flow
      const currentFlow = 50.0;
      final runnableRuns = runs.where((run) {
        final status = run.getFlowStatus(currentFlow);
        return status == 'Optimal' || status == 'Runnable';
      }).toList();

      // Then: Should find all 3 runs runnable
      expect(runnableRuns.length, 3);
      expect(runnableRuns.map((r) => r.name), contains('Lower Canyon'));
      expect(runnableRuns.map((r) => r.name), contains('Middle Canyon'));
      expect(runnableRuns.map((r) => r.name), contains('Upper Canyon'));
    });

    test('should filter runs by difficulty level', () {
      // Given: Runs of different difficulties
      final runs = [
        RiverRun(
          id: 'easy',
          riverId: 'river-1',
          name: 'Easy Run',
          difficultyClass: 'Class II',
        ),
        RiverRun(
          id: 'intermediate',
          riverId: 'river-1',
          name: 'Intermediate Run',
          difficultyClass: 'Class III-IV',
        ),
        RiverRun(
          id: 'expert',
          riverId: 'river-1',
          name: 'Expert Run',
          difficultyClass: 'Class V',
        ),
      ];

      // When: Filtering for Class II-III runs (beginner/intermediate)
      final beginnerRuns = runs.where((run) {
        final difficulty = run.difficultyClass.toLowerCase();
        return difficulty.contains('class ii') ||
            difficulty.contains('class iii') ||
            (difficulty.contains('class i') &&
                !difficulty.contains('iv') &&
                !difficulty.contains('v'));
      }).toList();

      // Then: Should find easy and intermediate runs
      expect(beginnerRuns.length, 2);
      expect(beginnerRuns.map((r) => r.name), contains('Easy Run'));
      expect(beginnerRuns.map((r) => r.name), contains('Intermediate Run'));
    });
  });
}
