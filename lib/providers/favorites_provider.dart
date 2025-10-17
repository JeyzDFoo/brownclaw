import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/user_favorites_service.dart';

class FavoritesProvider extends ChangeNotifier {
  Set<String> _favoriteRunIds = {};
  bool _isLoading = false;
  String? _error;
  StreamSubscription<List<String>>? _favoritesSubscription;
  StreamSubscription<User?>? _authSubscription;

  // Debouncing for rapid favorite toggles to reduce Firestore writes
  final Map<String, Timer> _debounceTimers = {};
  final Map<String, bool> _pendingToggles = {};
  static const _debounceDuration = Duration(milliseconds: 500);

  Set<String> get favoriteRunIds => _favoriteRunIds;
  bool get isLoading => _isLoading;
  String? get error => _error;

  FavoritesProvider() {
    // 🔥 CRITICAL FIX: Check if user is already logged in
    // authStateChanges() only fires on CHANGES, not current state!
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      if (kDebugMode) {
        print(
          '👤 FavoritesProvider: User already authenticated on init (${currentUser.uid}), loading favorites...',
        );
      }
      _loadFavorites();
    } else {
      if (kDebugMode) {
        print(
          '👤 FavoritesProvider: No user logged in on init, waiting for auth...',
        );
      }
    }

    // 🔥 ALSO listen to auth state changes for future sign-ins/sign-outs
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((
      User? user,
    ) {
      if (user != null) {
        if (kDebugMode) {
          print(
            '👤 FavoritesProvider: Auth state changed - User signed in (${user.uid}), loading favorites...',
          );
        }
        _loadFavorites();
      } else {
        if (kDebugMode) {
          print(
            '👤 FavoritesProvider: Auth state changed - User signed out, clearing favorites',
          );
        }
        _favoriteRunIds.clear();
        _favoritesSubscription?.cancel();
        notifyListeners();
      }
    });
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
    // Cancel existing subscription before creating a new one
    _favoritesSubscription?.cancel();

    _favoritesSubscription = UserFavoritesService.getUserFavoriteRunIds()
        .listen(
          (favoriteIds) {
            if (kDebugMode) {
              print(
                '⭐ FavoritesProvider: Loaded ${favoriteIds.length} favorites',
              );
            }
            _favoriteRunIds = favoriteIds.toSet();
            notifyListeners();
          },
          onError: (error) {
            if (kDebugMode) {
              print('❌ FavoritesProvider: Error loading favorites: $error');
            }
            setError(error.toString());
          },
        );
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
    // Cancel subscriptions
    _favoritesSubscription?.cancel();
    _authSubscription?.cancel();

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
