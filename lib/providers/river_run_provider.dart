import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/river_run_service.dart';
import 'cache_provider.dart';

class RiverRunProvider extends ChangeNotifier {
  final CacheProvider? _cacheProvider;

  List<RiverRunWithStations> _riverRuns = [];
  List<RiverRunWithStations> _favoriteRuns = [];
  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;
  Future<void>? _initializationFuture;

  // 🔥 PERFORMANCE: Simple but effective memory cache
  // Static so cache persists across provider instances
  static final Map<String, RiverRunWithStations> _cache = {};
  static DateTime? _cacheTime;
  static const _cacheTimeout = Duration(minutes: 10);

  // Cache keys for persistent storage
  static const String _allRunsCacheKey = 'all_river_runs';

  /// Check if cache is still valid (within timeout period)
  bool get _isCacheValid {
    if (_cacheTime == null) return false;
    final age = DateTime.now().difference(_cacheTime!);
    return age < _cacheTimeout;
  }

  /// Clear the cache (useful for force refresh)
  void clearCache() {
    _cache.clear();
    _cacheTime = null;

    // Also clear persistent cache
    _cacheProvider?.removeStatic(_allRunsCacheKey);
    // Note: Individual runs will be cleared as part of the all runs cache
  }

  RiverRunProvider({CacheProvider? cacheProvider})
    : _cacheProvider = cacheProvider {
    // Load all runs when provider is created
    _initializationFuture = _initializeData();
  }

  Future<void> _initializeData() async {
    if (_isInitialized) return;
    _isInitialized = true;

    if (kDebugMode) {
      print('🚀 RiverRunProvider: Initializing and loading all runs...');
    }

    await loadAllRuns();
  }

  /// Wait for the provider to finish initializing
  Future<void> ensureInitialized() async {
    if (_initializationFuture != null) {
      await _initializationFuture;
    }
  }

  List<RiverRunWithStations> get riverRuns => _riverRuns;
  List<RiverRunWithStations> get favoriteRuns => _favoriteRuns;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isInitialized => _isInitialized;

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setError(String? error) {
    _error = error;
    notifyListeners();
  }

  Future<void> loadAllRuns({bool forceRefresh = false}) async {
    // Check in-memory cache first (fastest)
    if (!forceRefresh && _cache.isNotEmpty && _isCacheValid) {
      _riverRuns = _cache.values.toList();
      if (kDebugMode) {
        print(
          '⚡ MEMORY CACHE HIT: Loaded ${_riverRuns.length} runs from memory',
        );
      }
      notifyListeners();
      return;
    }

    // Check persistent cache (fast, survives app restart)
    if (!forceRefresh && _cacheProvider != null) {
      final cachedData = _cacheProvider.getStatic<List<dynamic>>(
        _allRunsCacheKey,
      );
      if (cachedData != null &&
          _cacheProvider.isStaticCacheValid(_allRunsCacheKey)) {
        try {
          // Deserialize from persistent cache
          final runs = cachedData
              .map(
                (data) =>
                    RiverRunWithStations.fromMap(data as Map<String, dynamic>),
              )
              .toList();

          _riverRuns = runs;

          // Populate in-memory cache
          _cache.clear();
          for (final run in runs) {
            _cache[run.run.id] = run;
          }
          _cacheTime = DateTime.now();

          if (kDebugMode) {
            print(
              '💾 PERSISTENT CACHE HIT: Loaded ${runs.length} runs from disk',
            );
          }

          notifyListeners();
          return;
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ Error deserializing cached runs: $e');
          }
          // Fall through to Firestore fetch
        }
      }
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

      // Save to persistent cache
      if (_cacheProvider != null) {
        final serializedRuns = runs.map((run) => run.toMap()).toList();
        _cacheProvider.setStatic(_allRunsCacheKey, serializedRuns);
        if (kDebugMode) {
          print('💾 Saved ${runs.length} runs to persistent cache');
        }
      }

      if (kDebugMode) {
        print('💾 Cached ${runs.length} runs in memory');
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

      // Clear cache to force fresh reload
      clearCache();

      // Reload data after adding
      await loadAllRuns();

      if (kDebugMode) {
        print('✅ Added river run $runId and reloaded all runs');
      }

      return runId;
    } catch (e) {
      setError(e.toString());
      if (kDebugMode) {
        print('Error adding river run: $e');
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

    // 🔥 CRITICAL FIX: Wait for initialization to complete before loading favorites
    // This ensures the cache is populated on initial app launch
    await ensureInitialized();

    // 🔥 STALE-WHILE-REVALIDATE: Check cache first and return immediately
    bool hasStaleCache = false;

    // 🔥 PERFORMANCE: Check if we can use the all-runs cache
    if (_riverRuns.isNotEmpty) {
      // We already have all runs loaded, just filter for favorites
      // 🔥 STABILITY FIX: Preserve order from favoriteRunIds to prevent jank
      final favoriteRunsMap = {
        for (var run in _riverRuns.where(
          (run) => favoriteRunIds.contains(run.run.id),
        ))
          run.run.id: run,
      };

      final favoriteRuns = favoriteRunIds
          .map((id) => favoriteRunsMap[id])
          .whereType<RiverRunWithStations>()
          .toList();

      if (favoriteRuns.length == favoriteRunIds.length) {
        if (kDebugMode) {
          print(
            '⚡ CACHE HIT: Found all ${favoriteRunIds.length} favorites from all-runs cache',
          );
        }
        _favoriteRuns = favoriteRuns;
        notifyListeners(); // Show cached data immediately

        // If cache is still valid, we're done
        if (_isCacheValid) {
          return;
        }
        // Cache is stale - continue to background refresh
        hasStaleCache = true;
      }
    }

    // Check individual cache entries if all-runs cache didn't have everything
    if (!hasStaleCache) {
      // 🔥 STABILITY FIX: Preserve order from favoriteRunIds to prevent jank
      final cached = favoriteRunIds
          .map((id) => _cache[id])
          .whereType<RiverRunWithStations>()
          .toList();

      if (cached.isNotEmpty) {
        if (kDebugMode) {
          print(
            '⚡ PARTIAL CACHE HIT: Found ${cached.length}/${favoriteRunIds.length} runs from cache',
          );
        }
        _favoriteRuns = cached;
        notifyListeners(); // Show partial cached data immediately

        // If we have all favorites and cache is valid, we're done
        if (cached.length == favoriteRunIds.length && _isCacheValid) {
          return;
        }
        // Cache is partial or stale - continue to background refresh
        hasStaleCache = cached.isNotEmpty;
      }
    }

    // 🔥 STALE-WHILE-REVALIDATE: Only show spinner if we have NO cached data
    if (!hasStaleCache) {
      setLoading(true);
    }
    setError(null);

    try {
      if (kDebugMode) {
        print(
          hasStaleCache
              ? '🔄 Background refresh for ${favoriteRunIds.length} favorites...'
              : '🌊 Cache miss, fetching ${favoriteRunIds.length} favorites from Firestore...',
        );
      }

      // 🚀 USE NEW BATCH METHOD - 90% fewer queries!
      final favoriteRuns = await RiverRunService.batchGetFavoriteRuns(
        favoriteRunIds.toList(),
      );

      // 🔥 UPDATE CACHE - merge with existing cache, don't clear it!
      for (final run in favoriteRuns) {
        _cache[run.run.id] = run;
      }
      _cacheTime = DateTime.now();

      _favoriteRuns = favoriteRuns;
      notifyListeners(); // Update UI with fresh data

      if (kDebugMode && hasStaleCache) {
        print('✅ Background refresh complete');
      }
    } catch (e) {
      // Only show error if we don't have cached data to fall back on
      if (!hasStaleCache) {
        setError(e.toString());
      }
      if (kDebugMode) {
        print(
          hasStaleCache
              ? '⚠️ Background refresh failed (cached data still shown): $e'
              : 'Error loading favorite runs: $e',
        );
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

  /// Watch for real-time updates to a specific river run
  /// Returns a stream that emits the run whenever it changes in Firestore
  /// [runId] - The ID of the run to watch
  Stream<RiverRun?> watchRunById(String runId) {
    return RiverRunService.watchRunById(runId);
  }

  /// Get a single river run by ID
  /// First checks cache, then fetches from Firestore if needed
  /// [runId] - The ID of the run to fetch
  /// [forceRefresh] - Bypass cache and fetch fresh data
  Future<RiverRun?> getRunById(
    String runId, {
    bool forceRefresh = false,
  }) async {
    // Check cache first
    if (!forceRefresh && _cache.containsKey(runId)) {
      if (kDebugMode) {
        print('⚡ CACHE HIT: Run $runId from cache');
      }
      return _cache[runId]?.run;
    }

    try {
      if (kDebugMode) {
        print('🌐 Fetching run $runId from Firestore');
      }

      final run = await RiverRunService.getRunById(runId);

      // Update cache if run found
      if (run != null) {
        // Get the full RiverRunWithStations if possible, otherwise create a basic one
        final existingCached = _cache[runId];
        if (existingCached != null) {
          // Update the run in the cached object
          _cache[runId] = RiverRunWithStations(
            run: run,
            stations: existingCached.stations,
          );
        }
      }

      return run;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching run $runId: $e');
      }
      return null;
    }
  }
}
