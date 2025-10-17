import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/river_run_service.dart';

class RiverRunProvider extends ChangeNotifier {
  List<RiverRunWithStations> _riverRuns = [];
  List<RiverRunWithStations> _favoriteRuns = [];
  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;

  // 🔥 PERFORMANCE: Simple but effective memory cache
  // Static so cache persists across provider instances
  static final Map<String, RiverRunWithStations> _cache = {};
  static DateTime? _cacheTime;
  static const _cacheTimeout = Duration(minutes: 10);

  /// Check if cache is still valid (within timeout period)
  bool get _isCacheValid {
    if (_cacheTime == null) return false;
    final age = DateTime.now().difference(_cacheTime!);
    return age < _cacheTimeout;
  }

  /// Clear the cache (useful for force refresh)
  static void clearCache() {
    _cache.clear();
    _cacheTime = null;
  }

  RiverRunProvider() {
    // Load all runs when provider is created
    _initializeData();
  }

  Future<void> _initializeData() async {
    if (_isInitialized) return;
    _isInitialized = true;

    if (kDebugMode) {
      print('🚀 RiverRunProvider: Initializing and loading all runs...');
    }

    await loadAllRuns();
  }

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
    // Check cache first before making Firestore call
    if (_cache.isNotEmpty && _isCacheValid) {
      _riverRuns = _cache.values.toList();
      if (kDebugMode) {
        print('⚡ CACHE HIT: Loaded ${_riverRuns.length} runs from cache');
      }
      notifyListeners();
      return;
    }

    setLoading(true);
    setError(null);

    try {
      if (kDebugMode) {
        print('🌊 Cache miss or expired, fetching all runs from Firestore...');
      }

      final runs = await RiverRunService.getAllRunsWithStations().first;
      _riverRuns = runs;

      // Cache the loaded data to reduce subsequent Firestore reads
      _cache.clear();
      for (final run in runs) {
        _cache[run.run.id] = run;
      }
      _cacheTime = DateTime.now();

      if (kDebugMode) {
        print('💾 Cached ${runs.length} runs');
      }

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

  Future<void> deleteRiverRun(String runId) async {
    try {
      // Delete from Firestore
      await RiverRunService.deleteRun(runId);

      // Remove from cache
      _cache.remove(runId);

      // Remove from local lists
      _riverRuns.removeWhere((run) => run.run.id == runId);
      _favoriteRuns.removeWhere((run) => run.run.id == runId);

      if (kDebugMode) {
        print('✅ Deleted run $runId and updated cache');
      }

      notifyListeners();
    } catch (e) {
      setError(e.toString());
      if (kDebugMode) {
        print('❌ Error deleting river run: $e');
      }
      rethrow;
    }
  }

  Future<void> loadFavoriteRuns(Set<String> favoriteRunIds) async {
    if (favoriteRunIds.isEmpty) {
      _favoriteRuns = [];
      notifyListeners();
      return;
    }

    // 🔥 PERFORMANCE: Check cache first!
    if (_isCacheValid) {
      final cached = favoriteRunIds
          .map((id) => _cache[id])
          .whereType<RiverRunWithStations>()
          .toList();

      if (cached.length == favoriteRunIds.length) {
        if (kDebugMode) {
          print('⚡ CACHE HIT: All ${favoriteRunIds.length} runs from cache');
        }
        _favoriteRuns = cached;
        notifyListeners();
        return; // Done! No Firestore calls needed
      }
    }

    setLoading(true);
    setError(null);

    try {
      if (kDebugMode) {
        print('🌊 Cache miss or expired, fetching from Firestore...');
      }

      // 🚀 USE NEW BATCH METHOD - 90% fewer queries!
      final favoriteRuns = await RiverRunService.batchGetFavoriteRuns(
        favoriteRunIds.toList(),
      );

      // 🔥 UPDATE CACHE
      _cache.clear(); // Clear old entries
      for (final run in favoriteRuns) {
        _cache[run.run.id] = run;
      }
      _cacheTime = DateTime.now();

      if (kDebugMode) {
        print('💾 Cached ${favoriteRuns.length} runs');
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
      // Optimize live data refresh to avoid redundant Firestore calls
      // Use batch method instead of individual calls
      if (kDebugMode) {
        print(
          '🔄 Refreshing live data for ${favoriteRunIds.length} favorites...',
        );
      }

      final favoriteRuns = await RiverRunService.batchGetFavoriteRuns(
        favoriteRunIds.toList(),
      );

      // Update cache with fresh data
      for (final run in favoriteRuns) {
        _cache[run.run.id] = run;
      }
      _cacheTime = DateTime.now();

      _favoriteRuns = favoriteRuns;

      if (kDebugMode) {
        print('✅ Live data refreshed and cached');
      }

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
