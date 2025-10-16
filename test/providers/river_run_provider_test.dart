import 'package:flutter_test/flutter_test.dart';
import 'package:brownclaw/providers/river_run_provider.dart';

void main() {
  group('RiverRunProvider Tests', () {
    late RiverRunProvider riverRunProvider;

    setUp(() {
      riverRunProvider = RiverRunProvider();
    });

    test('should initialize with empty state', () {
      expect(riverRunProvider.riverRuns, isEmpty);
      expect(riverRunProvider.favoriteRuns, isEmpty);
      expect(riverRunProvider.isLoading, false);
      expect(riverRunProvider.error, null);
    });

    test('should set loading state', () {
      bool notified = false;
      riverRunProvider.addListener(() {
        notified = true;
      });

      riverRunProvider.setLoading(true);

      expect(riverRunProvider.isLoading, true);
      expect(notified, true);
    });

    test('should set error state', () {
      const errorMessage = 'Failed to load runs';
      bool notified = false;
      riverRunProvider.addListener(() {
        notified = true;
      });

      riverRunProvider.setError(errorMessage);

      expect(riverRunProvider.error, errorMessage);
      expect(notified, true);
    });

    test('should clear error', () {
      // First set an error
      riverRunProvider.setError('Test error');
      expect(riverRunProvider.error, 'Test error');

      bool notified = false;
      riverRunProvider.addListener(() {
        notified = true;
      });

      // Clear the error (set to null)
      riverRunProvider.setError(null);

      expect(riverRunProvider.error, null);
      expect(notified, true);
    });

    test('should handle loading states properly', () {
      expect(riverRunProvider.isLoading, false);

      riverRunProvider.setLoading(true);
      expect(riverRunProvider.isLoading, true);

      riverRunProvider.setLoading(false);
      expect(riverRunProvider.isLoading, false);
    });

    test('should notify listeners when state changes', () {
      int notificationCount = 0;
      riverRunProvider.addListener(() {
        notificationCount++;
      });

      riverRunProvider.setLoading(true);
      riverRunProvider.setLoading(false);
      riverRunProvider.setError('error');
      riverRunProvider.setError(null);

      expect(notificationCount, 4);
    });

    test('should handle error states properly', () {
      expect(riverRunProvider.error, null);

      riverRunProvider.setError('Network error');
      expect(riverRunProvider.error, 'Network error');

      riverRunProvider.setError('Different error');
      expect(riverRunProvider.error, 'Different error');

      riverRunProvider.setError(null);
      expect(riverRunProvider.error, null);
    });

    test('should maintain separate collections for runs and favorites', () {
      expect(riverRunProvider.riverRuns, isEmpty);
      expect(riverRunProvider.favoriteRuns, isEmpty);

      // Both collections should be independent
      expect(
        riverRunProvider.riverRuns,
        isNot(same(riverRunProvider.favoriteRuns)),
      );
    });

    // Note: Testing loadAllRuns, addRiverRun, and other service-dependent methods
    // would require mocking the RiverRunService. This is typically done by:
    // 1. Injecting the service as a dependency
    // 2. Using a mock service for testing
    // 3. Using integration tests with test databases

    // Example of what service-dependent tests might look like:
    // test('should load all runs successfully', () async {
    //   // This would require mocking RiverRunService
    //   // await riverRunProvider.loadAllRuns();
    //   // expect(riverRunProvider.riverRuns, isNotEmpty);
    //   // expect(riverRunProvider.isLoading, false);
    // });
  });
}
