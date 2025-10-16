import 'package:flutter_test/flutter_test.dart';
import 'package:brownclaw/models/river_run.dart';

void main() {
  group('RiverRun Flow Status Tests', () {
    late RiverRun riverRun;

    setUp(() {
      riverRun = RiverRun(
        id: 'run-id',
        riverId: 'river-id',
        name: 'Test Run',
        difficultyClass: 'Class III',
        minRecommendedFlow: 20.0,
        maxRecommendedFlow: 150.0,
        optimalFlowMin: 40.0,
        optimalFlowMax: 100.0,
      );
    });

    test('should return "Too Low" for flow below minimum', () {
      expect(riverRun.getFlowStatus(10.0), 'Too Low');
      expect(riverRun.getFlowStatus(19.9), 'Too Low');
      expect(riverRun.getFlowStatus(0.0), 'Too Low');
    });

    test('should return "Too High" for flow above maximum', () {
      expect(riverRun.getFlowStatus(151.0), 'Too High');
      expect(riverRun.getFlowStatus(200.0), 'Too High');
      expect(riverRun.getFlowStatus(1000.0), 'Too High');
    });

    test('should return "Optimal" for flow in optimal range', () {
      expect(riverRun.getFlowStatus(40.0), 'Optimal');
      expect(riverRun.getFlowStatus(50.0), 'Optimal');
      expect(riverRun.getFlowStatus(100.0), 'Optimal');
    });

    test(
      'should return "Runnable" for flow in runnable but not optimal range',
      () {
        expect(riverRun.getFlowStatus(20.0), 'Runnable');
        expect(riverRun.getFlowStatus(30.0), 'Runnable');
        expect(riverRun.getFlowStatus(110.0), 'Runnable');
        expect(riverRun.getFlowStatus(150.0), 'Runnable');
      },
    );

    test('should return "Unknown" for null flow', () {
      expect(riverRun.getFlowStatus(null), 'Unknown');
    });

    test('should return "Unknown" when no flow recommendations exist', () {
      final noFlowRun = RiverRun(
        id: 'run-id',
        riverId: 'river-id',
        name: 'No Flow Run',
        difficultyClass: 'Class III',
      );

      expect(noFlowRun.getFlowStatus(50.0), 'Unknown');
    });

    test('should return "Unknown" when only min is set', () {
      final partialRun = RiverRun(
        id: 'run-id',
        riverId: 'river-id',
        name: 'Partial Flow Run',
        difficultyClass: 'Class III',
        minRecommendedFlow: 20.0,
      );

      expect(partialRun.getFlowStatus(50.0), 'Unknown');
    });

    test('should handle edge cases at boundaries', () {
      // Exactly at minimum
      expect(riverRun.getFlowStatus(20.0), 'Runnable');

      // Exactly at maximum
      expect(riverRun.getFlowStatus(150.0), 'Runnable');

      // Just inside optimal
      expect(riverRun.getFlowStatus(40.0), 'Optimal');
      expect(riverRun.getFlowStatus(100.0), 'Optimal');

      // Just outside optimal
      expect(riverRun.getFlowStatus(39.9), 'Runnable');
      expect(riverRun.getFlowStatus(100.1), 'Runnable');
    });

    test('should handle negative flow values', () {
      expect(riverRun.getFlowStatus(-10.0), 'Too Low');
    });

    test('should work without optimal range', () {
      final noOptimalRun = RiverRun(
        id: 'run-id',
        riverId: 'river-id',
        name: 'No Optimal Run',
        difficultyClass: 'Class III',
        minRecommendedFlow: 20.0,
        maxRecommendedFlow: 150.0,
      );

      expect(noOptimalRun.getFlowStatus(10.0), 'Too Low');
      expect(noOptimalRun.getFlowStatus(50.0), 'Runnable');
      expect(noOptimalRun.getFlowStatus(200.0), 'Too High');
    });

    test('should handle very small and very large flow values', () {
      expect(riverRun.getFlowStatus(0.001), 'Too Low');
      expect(riverRun.getFlowStatus(10000.0), 'Too High');
    });
  });

  group('RiverRun Display Properties Tests', () {
    test('should return correct display name', () {
      final riverRun = RiverRun(
        id: 'run-id',
        riverId: 'river-id',
        name: 'Lower Canyon',
        difficultyClass: 'Class III-IV',
      );

      expect(riverRun.displayName, 'Lower Canyon (Class III-IV)');
    });

    test(
      'hasFlowRecommendations should be true when both min and max are set',
      () {
        final riverRun = RiverRun(
          id: 'run-id',
          riverId: 'river-id',
          name: 'Test Run',
          difficultyClass: 'Class III',
          minRecommendedFlow: 20.0,
          maxRecommendedFlow: 150.0,
        );

        expect(riverRun.hasFlowRecommendations, true);
      },
    );

    test('hasFlowRecommendations should be false when min is missing', () {
      final riverRun = RiverRun(
        id: 'run-id',
        riverId: 'river-id',
        name: 'Test Run',
        difficultyClass: 'Class III',
        maxRecommendedFlow: 150.0,
      );

      expect(riverRun.hasFlowRecommendations, false);
    });

    test('hasFlowRecommendations should be false when max is missing', () {
      final riverRun = RiverRun(
        id: 'run-id',
        riverId: 'river-id',
        name: 'Test Run',
        difficultyClass: 'Class III',
        minRecommendedFlow: 20.0,
      );

      expect(riverRun.hasFlowRecommendations, false);
    });

    test('hasFlowRecommendations should be false when both are missing', () {
      final riverRun = RiverRun(
        id: 'run-id',
        riverId: 'river-id',
        name: 'Test Run',
        difficultyClass: 'Class III',
      );

      expect(riverRun.hasFlowRecommendations, false);
    });

    test('hasAssociatedStations should return true (placeholder)', () {
      final riverRun = RiverRun(
        id: 'run-id',
        riverId: 'river-id',
        name: 'Test Run',
        difficultyClass: 'Class III',
      );

      // This is a placeholder implementation
      expect(riverRun.hasAssociatedStations, true);
    });
  });
}
