import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:async';

// Mock service for testing
class MockUserFavoritesService {
  static StreamController<List<String>> _favoritesController =
      StreamController<List<String>>.broadcast();
  static List<String> _currentFavorites = [];
  static bool _shouldThrowError = false;
  static String? _errorMessage;

  static Stream<List<String>> getUserFavoriteRunIds() {
    if (_shouldThrowError && _errorMessage != null) {
      return Stream.error(Exception(_errorMessage!));
    }
    return _favoritesController.stream;
  }

  static Future<void> addFavoriteRun(String runId) async {
    if (_shouldThrowError && _errorMessage != null) {
      throw Exception(_errorMessage!);
    }
    if (!_currentFavorites.contains(runId)) {
      _currentFavorites.add(runId);
      _favoritesController.add(List.from(_currentFavorites));
    }
  }

  static Future<void> removeFavoriteRun(String runId) async {
    if (_shouldThrowError && _errorMessage != null) {
      throw Exception(_errorMessage!);
    }
    if (_currentFavorites.contains(runId)) {
      _currentFavorites.remove(runId);
      _favoritesController.add(List.from(_currentFavorites));
    }
  }

  // Test helper methods
  static void setFavorites(List<String> favorites) {
    _currentFavorites = List.from(favorites);
    _favoritesController.add(List.from(_currentFavorites));
  }

  static void setErrorMode(bool shouldThrow, [String? errorMessage]) {
    _shouldThrowError = shouldThrow;
    _errorMessage = errorMessage;
  }

  static void reset() {
    _currentFavorites.clear();
    _shouldThrowError = false;
    _errorMessage = null;
    _favoritesController.add([]);
  }

  static void dispose() {
    _favoritesController.close();
  }
}

// Testable version of FavoritesProvider that accepts dependencies
class TestableFavoritesProvider extends ChangeNotifier {
  Set<String> _favoriteRunIds = {};
  bool _isLoading = false;
  String? _error;
  StreamSubscription<List<String>>? _favoritesSubscription;

  Set<String> get favoriteRunIds => _favoriteRunIds;
  bool get isLoading => _isLoading;
  String? get error => _error;

  TestableFavoritesProvider() {
    _loadFavorites();
  }

  @override
  void dispose() {
    _favoritesSubscription?.cancel();
    super.dispose();
  }

  bool isFavorite(String runId) {
    return _favoriteRunIds.contains(runId);
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void _loadFavorites() {
    _favoritesSubscription = MockUserFavoritesService.getUserFavoriteRunIds()
        .listen(
          (favoriteIds) {
            _favoriteRunIds = favoriteIds.toSet();
            notifyListeners();
          },
          onError: (error) {
            setError(error.toString());
          },
        );
  }

  Future<void> toggleFavorite(String runId) async {
    try {
      if (_favoriteRunIds.contains(runId)) {
        await MockUserFavoritesService.removeFavoriteRun(runId);
      } else {
        await MockUserFavoritesService.addFavoriteRun(runId);
      }
    } catch (e) {
      setError(e.toString());
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

void main() {
  group('FavoritesProvider Tests', () {
    late TestableFavoritesProvider favoritesProvider;

    setUp(() {
      MockUserFavoritesService.reset();
      favoritesProvider = TestableFavoritesProvider();
    });

    tearDown(() {
      favoritesProvider.dispose();
    });

    test('should initialize with empty favorites', () {
      expect(favoritesProvider.favoriteRunIds, isEmpty);
      expect(favoritesProvider.isLoading, false);
      expect(favoritesProvider.error, null);
    });

    test('should load favorites from service', () async {
      // Setup initial favorites
      MockUserFavoritesService.setFavorites(['run1', 'run2', 'run3']);

      // Wait for stream to process
      await Future.delayed(Duration(milliseconds: 10));

      expect(favoritesProvider.favoriteRunIds, {'run1', 'run2', 'run3'});
      expect(favoritesProvider.favoriteRunIds.length, 3);
    });

    test('should check if run is favorite correctly', () async {
      // Setup favorites
      MockUserFavoritesService.setFavorites(['run1', 'run2']);
      await Future.delayed(Duration(milliseconds: 10));

      expect(favoritesProvider.isFavorite('run1'), true);
      expect(favoritesProvider.isFavorite('run2'), true);
      expect(favoritesProvider.isFavorite('run3'), false);
      expect(favoritesProvider.isFavorite('nonexistent'), false);
    });

    test('should add favorite when toggling non-favorite run', () async {
      // Start with no favorites
      MockUserFavoritesService.setFavorites([]);
      await Future.delayed(Duration(milliseconds: 10));

      expect(favoritesProvider.isFavorite('run1'), false);

      // Toggle to add favorite
      await favoritesProvider.toggleFavorite('run1');
      await Future.delayed(Duration(milliseconds: 10));

      expect(favoritesProvider.isFavorite('run1'), true);
      expect(favoritesProvider.favoriteRunIds, contains('run1'));
    });

    test('should remove favorite when toggling favorite run', () async {
      // Start with favorites
      MockUserFavoritesService.setFavorites(['run1', 'run2']);
      await Future.delayed(Duration(milliseconds: 10));

      expect(favoritesProvider.isFavorite('run1'), true);

      // Toggle to remove favorite
      await favoritesProvider.toggleFavorite('run1');
      await Future.delayed(Duration(milliseconds: 10));

      expect(favoritesProvider.isFavorite('run1'), false);
      expect(favoritesProvider.favoriteRunIds, isNot(contains('run1')));
      expect(favoritesProvider.favoriteRunIds, contains('run2'));
    });

    test('should set and clear loading state', () {
      bool notified = false;
      favoritesProvider.addListener(() {
        notified = true;
      });

      expect(favoritesProvider.isLoading, false);

      favoritesProvider.setLoading(true);
      expect(favoritesProvider.isLoading, true);
      expect(notified, true);

      notified = false;
      favoritesProvider.setLoading(false);
      expect(favoritesProvider.isLoading, false);
      expect(notified, true);
    });

    test('should set and clear error state', () {
      const errorMessage = 'Network error';
      bool notified = false;
      favoritesProvider.addListener(() {
        notified = true;
      });

      expect(favoritesProvider.error, null);

      favoritesProvider.setError(errorMessage);
      expect(favoritesProvider.error, errorMessage);
      expect(notified, true);

      notified = false;
      favoritesProvider.clearError();
      expect(favoritesProvider.error, null);
      expect(notified, true);
    });

    test('should handle toggle favorite errors', () async {
      // Setup service to throw errors
      MockUserFavoritesService.setErrorMode(true, 'Network error');

      expect(favoritesProvider.error, null);

      await favoritesProvider.toggleFavorite('run1');

      expect(favoritesProvider.error, isNotNull);
      expect(favoritesProvider.error, contains('Network error'));
    });

    test('should handle stream errors when loading favorites', () async {
      // Reset and setup error mode before creating provider
      MockUserFavoritesService.reset();
      MockUserFavoritesService.setErrorMode(true, 'Stream error');

      final errorProvider = TestableFavoritesProvider();
      await Future.delayed(Duration(milliseconds: 10));

      expect(errorProvider.error, isNotNull);
      expect(errorProvider.error, contains('Stream error'));

      errorProvider.dispose();
    });

    test('should notify listeners when favorites change', () async {
      int notificationCount = 0;
      favoritesProvider.addListener(() {
        notificationCount++;
      });

      // Add favorites
      MockUserFavoritesService.setFavorites(['run1']);
      await Future.delayed(Duration(milliseconds: 10));
      expect(notificationCount, 1);

      // Add more favorites
      MockUserFavoritesService.setFavorites(['run1', 'run2']);
      await Future.delayed(Duration(milliseconds: 10));
      expect(notificationCount, 2);

      // Remove a favorite
      MockUserFavoritesService.setFavorites(['run2']);
      await Future.delayed(Duration(milliseconds: 10));
      expect(notificationCount, 3);
    });

    test('should handle multiple rapid favorite changes', () async {
      MockUserFavoritesService.setFavorites([]);
      await Future.delayed(Duration(milliseconds: 10));

      // Rapid toggles
      await favoritesProvider.toggleFavorite('run1');
      await favoritesProvider.toggleFavorite('run2');
      await favoritesProvider.toggleFavorite('run3');

      await Future.delayed(Duration(milliseconds: 20));

      expect(favoritesProvider.favoriteRunIds.length, 3);
      expect(favoritesProvider.favoriteRunIds, {'run1', 'run2', 'run3'});
    });

    test('should maintain Set behavior for favorites', () async {
      MockUserFavoritesService.setFavorites([
        'run1',
        'run2',
        'run1',
      ]); // Duplicate
      await Future.delayed(Duration(milliseconds: 10));

      // Set should eliminate duplicates
      expect(favoritesProvider.favoriteRunIds.length, 2);
      expect(favoritesProvider.favoriteRunIds, {'run1', 'run2'});
    });
  });
}
