import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/river_run_service.dart';

class RiverRunProvider extends ChangeNotifier {
  List<RiverRunWithStations> _riverRuns = [];
  List<RiverRunWithStations> _favoriteRuns = [];
  bool _isLoading = false;
  String? _error;

  // #todo: Add local caching mechanism to reduce Firestore reads
  // Map<String, RiverRunWithStations> _cachedRuns = {};
  // DateTime? _lastCacheUpdate;

  // #todo: Add offline support for cached data
  // bool _isOffline = false;

  List<RiverRunWithStations> get riverRuns => _riverRuns;
  List<RiverRunWithStations> get favoriteRuns => _favoriteRuns;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setError(String? error) {
    _error = error;
    notifyListeners();
  }

  Future<void> loadAllRuns() async {
    setLoading(true);
    setError(null);

    try {
      // #todo: Check cache first before making Firestore call
      // if (_cachedRuns.isNotEmpty && _lastCacheUpdate != null &&
      //     DateTime.now().difference(_lastCacheUpdate!) < Duration(minutes: 5)) {
      //   _riverRuns = _cachedRuns.values.toList();
      //   notifyListeners();
      //   return;
      // }

      final runs = await RiverRunService.getAllRunsWithStations().first;
      _riverRuns = runs;

      // #todo: Cache the loaded data to reduce subsequent Firestore reads
      // _cachedRuns = {for (var run in runs) run.run.id: run};
      // _lastCacheUpdate = DateTime.now();

      notifyListeners();
    } catch (e) {
      setError(e.toString());
      if (kDebugMode) {
        print('Error loading river runs: $e');
      }
    } finally {
      setLoading(false);
    }
  }

  Future<String> addRiverRun(RiverRun run) async {
    try {
      final runId = await RiverRunService.addRun(run);
      // Reload data after adding
      await loadAllRuns();
      return runId;
    } catch (e) {
      setError(e.toString());
      if (kDebugMode) {
        print('Error loading river runs: $e');
      }
      rethrow;
    }
  }

  Future<void> loadFavoriteRuns(Set<String> favoriteRunIds) async {
    if (_favoriteRuns.isNotEmpty && favoriteRunIds.isEmpty) {
      _favoriteRuns = [];
      notifyListeners();
      return;
    }

    // Only load if we don't already have the data or if favorite IDs changed
    final currentIds = _favoriteRuns.map((run) => run.run.id).toSet();
    if (currentIds.containsAll(favoriteRunIds) &&
        favoriteRunIds.containsAll(currentIds)) {
      // We already have the correct data, no need to reload
      return;
    }

    setLoading(true);
    setError(null);

    try {
      final List<RiverRunWithStations> favoriteRuns = [];

      // #todo: Batch fetch favorite runs instead of individual calls
      // This reduces Firestore reads significantly for users with many favorites
      // Consider using whereIn query with batching for >10 items
      for (final runId in favoriteRunIds) {
        final runWithStations = await RiverRunService.getRunWithStations(runId);
        if (runWithStations != null) {
          favoriteRuns.add(runWithStations);
        }
      }
      _favoriteRuns = favoriteRuns;
      notifyListeners();
    } catch (e) {
      setError(e.toString());
      if (kDebugMode) {
        print('Error loading favorite runs: $e');
      }
    } finally {
      setLoading(false);
    }
  }

  // Silent refresh for live data updates (no loading spinner)
  Future<void> refreshFavoriteRunsLiveData(Set<String> favoriteRunIds) async {
    if (favoriteRunIds.isEmpty) return;

    // Don't set loading state - this is a background update
    try {
      // #todo: Optimize live data refresh to avoid redundant Firestore calls
      // Only fetch live data, not the entire run data which is already cached
      final List<RiverRunWithStations> favoriteRuns = [];
      for (final runId in favoriteRunIds) {
        final runWithStations = await RiverRunService.getRunWithStations(runId);
        if (runWithStations != null) {
          favoriteRuns.add(runWithStations);
        }
      }
      _favoriteRuns = favoriteRuns;
      notifyListeners(); // Update UI with fresh live data
    } catch (e) {
      if (kDebugMode) {
        print('Error refreshing live data: $e');
      }
      // Don't set error state for background updates
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
