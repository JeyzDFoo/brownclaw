import 'package:flutter_test/flutter_test.dart';
import 'package:brownclaw/providers/favorites_provider.dart';

void main() {
  group('FavoritesProvider Tests', () {
    late FavoritesProvider favoritesProvider;

    setUp(() {
      // Note: This will try to initialize with real service
      // In production tests, we'd want to inject a mock service
      favoritesProvider = FavoritesProvider();
    });

    test('should initialize with empty favorites', () {
      expect(favoritesProvider.favoriteRunIds, isEmpty);
      expect(favoritesProvider.isLoading, false);
      expect(favoritesProvider.error, null);
    });

    test('should check if run is favorite', () {
      // Initially no favorites
      expect(favoritesProvider.isFavorite('run1'), false);
      expect(favoritesProvider.isFavorite('nonexistent'), false);
    });

    test('should set loading state', () {
      bool notified = false;
      favoritesProvider.addListener(() {
        notified = true;
      });

      favoritesProvider.setLoading(true);

      expect(favoritesProvider.isLoading, true);
      expect(notified, true);
    });

    test('should set error state', () {
      const errorMessage = 'Test error';
      bool notified = false;
      favoritesProvider.addListener(() {
        notified = true;
      });

      favoritesProvider.setError(errorMessage);

      expect(favoritesProvider.error, errorMessage);
      expect(notified, true);
    });

    test('should clear error', () {
      // First set an error
      favoritesProvider.setError('Test error');
      expect(favoritesProvider.error, 'Test error');

      bool notified = false;
      favoritesProvider.addListener(() {
        notified = true;
      });

      // Clear the error
      favoritesProvider.clearError();

      expect(favoritesProvider.error, null);
      expect(notified, true);
    });

    test('should notify listeners when state changes', () {
      int notificationCount = 0;
      favoritesProvider.addListener(() {
        notificationCount++;
      });

      favoritesProvider.setLoading(true);
      favoritesProvider.setLoading(false);
      favoritesProvider.setError('error');
      favoritesProvider.clearError();

      expect(notificationCount, 4);
    });

    test('should handle error states properly', () {
      expect(favoritesProvider.error, null);

      favoritesProvider.setError('Network error');
      expect(favoritesProvider.error, 'Network error');

      favoritesProvider.clearError();
      expect(favoritesProvider.error, null);
    });

    test('should handle loading states properly', () {
      expect(favoritesProvider.isLoading, false);

      favoritesProvider.setLoading(true);
      expect(favoritesProvider.isLoading, true);

      favoritesProvider.setLoading(false);
      expect(favoritesProvider.isLoading, false);
    });
  });
}
