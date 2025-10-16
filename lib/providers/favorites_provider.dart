import 'package:flutter/foundation.dart';
import '../services/user_favorites_service.dart';

class FavoritesProvider extends ChangeNotifier {
  Set<String> _favoriteRunIds = {};
  bool _isLoading = false;
  String? _error;

  // #todo: Add local caching for offline favorites access
  // Map<String, RiverRun> _cachedFavoriteRuns = {};

  // #todo: Add debouncing for rapid favorite toggles to reduce Firestore writes
  // Timer? _debounceTimer;

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
    try {
      // #todo: Implement optimistic updates for better UX
      // Update UI immediately, then sync to Firestore
      // Rollback if Firestore operation fails

      if (_favoriteRunIds.contains(runId)) {
        await UserFavoritesService.removeFavoriteRun(runId);
      } else {
        await UserFavoritesService.addFavoriteRun(runId);
      }
    } catch (e) {
      setError(e.toString());
      if (kDebugMode) {
        print('Error toggling favorite: $e');
      }
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
