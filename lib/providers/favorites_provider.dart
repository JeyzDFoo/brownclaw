import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/user_favorites_service.dart';

class FavoritesProvider extends ChangeNotifier {
  Set<String> _favoriteRunIds = {};
  bool _isLoading = false;
  String? _error;

  // Local caching for offline favorites access
  static final Map<String, Set<String>> _userFavoritesCache = {};
  static String? _lastUserId;

  // Debouncing for rapid favorite toggles to reduce Firestore writes
  final Map<String, Timer> _debounceTimers = {};
  final Map<String, bool> _pendingToggles = {};
  static const _debounceDuration = Duration(milliseconds: 500);

  Set<String> get favoriteRunIds => _favoriteRunIds;
  bool get isLoading => _isLoading;
  String? get error => _error;

  FavoritesProvider() {
    _loadFavorites();
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
    UserFavoritesService.getUserFavoriteRunIds().listen((favoriteIds) {
      _favoriteRunIds = favoriteIds.toSet();
      notifyListeners();
    });
  }

  Future<void> toggleFavorite(String runId) async {
    // Implement optimistic updates for instant UI feedback
    final wasFavorite = _favoriteRunIds.contains(runId);
    final willBeFavorite = !wasFavorite;

    // Update UI immediately (optimistic)
    if (willBeFavorite) {
      _favoriteRunIds.add(runId);
    } else {
      _favoriteRunIds.remove(runId);
    }
    notifyListeners(); // UI updates instantly!

    // Cancel any existing timer for this run
    _debounceTimers[runId]?.cancel();

    // Store the pending toggle
    _pendingToggles[runId] = willBeFavorite;

    // Debounce: Wait for rapid toggles to settle
    _debounceTimers[runId] = Timer(_debounceDuration, () async {
      final shouldBeFavorite = _pendingToggles[runId];
      if (shouldBeFavorite == null) return;

      try {
        // Sync to Firestore after debounce
        if (shouldBeFavorite) {
          await UserFavoritesService.addFavoriteRun(runId);
          if (kDebugMode) {
            print('✅ Added favorite: $runId');
          }
        } else {
          await UserFavoritesService.removeFavoriteRun(runId);
          if (kDebugMode) {
            print('✅ Removed favorite: $runId');
          }
        }

        // Clean up
        _debounceTimers.remove(runId);
        _pendingToggles.remove(runId);
      } catch (e) {
        // Rollback on failure
        if (shouldBeFavorite) {
          _favoriteRunIds.remove(runId);
        } else {
          _favoriteRunIds.add(runId);
        }
        notifyListeners();

        setError(e.toString());
        if (kDebugMode) {
          print('❌ Error toggling favorite (rolled back): $e');
        }

        // Clean up
        _debounceTimers.remove(runId);
        _pendingToggles.remove(runId);
      }
    });
  }

  @override
  void dispose() {
    // Cancel all pending timers
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
    _pendingToggles.clear();
    super.dispose();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
