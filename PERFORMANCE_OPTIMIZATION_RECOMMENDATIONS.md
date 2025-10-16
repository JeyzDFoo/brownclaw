# Performance Optimization Recommendations
**Analysis Date:** October 16, 2025  
**Focus:** Launch Process & Favorites Screen Loading

---

## 🎯 Executive Summary

The app suffers from **cascading performance issues** during the launch and favorites screen loading process. The primary bottleneck is the **sequential Firestore queries** combined with **redundant live data API calls**. The loading spinner duration is caused by multiple round-trips to Firebase and external APIs that could be parallelized or eliminated through caching.

**Key Issue:** For a user with 10 favorite river runs, the app makes:
- **10+ individual Firestore reads** for run data
- **10+ individual Firestore reads** for river data  
- **10+ individual Firestore reads** for gauge station data
- **10+ HTTP API calls** to Government of Canada for live flow data
- All happening **sequentially** in nested loops

**Estimated Current Load Time:** 8-15 seconds  
**Potential Optimized Load Time:** 1-3 seconds (5-15x improvement)

---

## 🔴 Critical Performance Issues

### 1. **Sequential Firestore Queries (Most Critical)**
**Location:** `lib/providers/river_run_provider.dart` - `loadFavoriteRuns()`

**Problem:**
```dart
for (final runId in favoriteRunIds) {
  final runWithStations = await RiverRunService.getRunWithStations(runId);
  // Each call makes 3 Firestore queries:
  // 1. Get run document
  // 2. Get river document  
  // 3. Get gauge stations query
}
```

**Impact:**
- For 10 favorites: **30+ Firestore reads**
- Each read has ~100-300ms latency
- Total time: **3-9 seconds just for Firestore**

**Solution:**
✅ **Batch fetch using `whereIn` queries**
```dart
// Fetch ALL runs in one query (max 10 per batch)
final runsSnapshot = await _runsCollection
    .where(FieldPath.documentId, whereIn: favoriteRunIds.take(10).toList())
    .get();

// Extract unique river IDs and batch fetch rivers
final riverIds = runs.map((r) => r.riverId).toSet();
final riversSnapshot = await _firestore
    .collection('rivers')
    .where(FieldPath.documentId, whereIn: riverIds.toList())
    .get();

// Batch fetch all gauge stations for these runs
final stationsSnapshot = await _firestore
    .collection('gauge_stations')
    .where('riverRunId', whereIn: favoriteRunIds.take(10).toList())
    .where('isActive', isEqualTo: true)
    .get();
```

**Expected Improvement:** 30 queries → 3-4 queries = **90% reduction in Firestore calls**

---

### 2. **Duplicate Live Data API Calls**
**Location:** `lib/screens/river_levels_screen.dart` - `_updateLiveDataInBackground()`

**Problem:**
```dart
// Multiple triggers calling the same live data fetch:
// 1. initState() calls _testLiveDataService()
// 2. didChangeDependencies() triggers when favorites change
// 3. build() method triggers addPostFrameCallback twice
// 4. No proper deduplication across the app
```

**Impact:**
- Same station fetched **2-4 times** within seconds
- API rate limiting delays responses
- Wasted bandwidth and processing time

**Solution:**
✅ **Fully migrate to LiveWaterDataProvider (already partially implemented)**
```dart
// In river_levels_screen.dart - REPLACE local cache with provider
final liveDataProvider = context.read<LiveWaterDataProvider>();

// Single call with automatic deduplication
await liveDataProvider.fetchMultipleStations(uniqueStationIds);

// UI automatically updates via Consumer<LiveWaterDataProvider>
```

**Expected Improvement:** 4 API calls → 1 API call = **75% reduction in API requests**

---

### 3. **Excessive Widget Rebuilds**
**Location:** `lib/screens/river_levels_screen.dart` - build()

**Problem:**
```dart
Widget build(BuildContext context) {
  return Consumer2<FavoritesProvider, RiverRunProvider>(
    builder: (context, favoritesProvider, riverRunProvider, child) {
      // This entire logic runs on EVERY rebuild
      if (!_lastFavoriteRunIds.containsAll(currentFavoriteIds) || ...) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await riverRunProvider.loadFavoriteRuns(currentFavoriteIds);
          _updateLiveDataInBackground(currentFavoriteIds.toList());
        });
      }
      // Multiple addPostFrameCallback calls throughout build()
    }
  );
}
```

**Impact:**
- Build method triggers data loading
- Multiple `addPostFrameCallback` calls per rebuild
- Race conditions between competing updates

**Solution:**
✅ **Move data loading to proper lifecycle methods**
```dart
@override
void didChangeDependencies() {
  super.didChangeDependencies();
  
  final currentFavoriteIds = context.read<FavoritesProvider>().favoriteRunIds;
  if (!setEquals(_lastFavoriteRunIds, currentFavoriteIds)) {
    _lastFavoriteRunIds = Set.from(currentFavoriteIds);
    _loadFavoriteData();
  }
}

Future<void> _loadFavoriteData() async {
  await context.read<RiverRunProvider>().loadFavoriteRuns(_lastFavoriteRunIds);
  await context.read<LiveWaterDataProvider>().fetchMultipleStations(
    _extractStationIds()
  );
}
```

**Expected Improvement:** Eliminates duplicate triggers and race conditions

---

### 4. **No Caching Strategy**
**Location:** Multiple files - marked with `#todo: Add caching`

**Problem:**
- No local caching for Firestore data
- Re-fetching same data on every app launch
- No offline support

**Impact:**
- Cold start always takes full loading time
- No graceful degradation when offline

**Solution:**
✅ **Implement multi-layer caching**

**Layer 1: Memory Cache**
```dart
// In RiverRunProvider
static final Map<String, RiverRunWithStations> _memoryCache = {};
static DateTime? _lastCacheUpdate;
static const _cacheTimeout = Duration(minutes: 10);

Future<void> loadFavoriteRuns(Set<String> favoriteRunIds) async {
  // Check cache first
  if (_isCacheValid()) {
    final cached = favoriteRunIds
        .map((id) => _memoryCache[id])
        .whereType<RiverRunWithStations>()
        .toList();
    
    if (cached.length == favoriteRunIds.length) {
      _favoriteRuns = cached;
      notifyListeners();
      return; // Cache hit!
    }
  }
  
  // Cache miss - fetch from Firestore
  // ... batch fetch logic ...
}
```

**Layer 2: Local Storage (Optional)**
```dart
// Use shared_preferences or hive for persistent cache
await _prefs.setString('cached_favorites', jsonEncode(favoriteRuns));
```

**Expected Improvement:** 
- Subsequent loads: 0-100ms (from cache)
- Offline support for previously loaded data

---

### 5. **Inefficient River Data Fetching**
**Location:** `lib/services/river_run_service.dart` - `getRunWithStations()`

**Problem:**
```dart
Future<RiverRunWithStations?> getRunWithStations(String runId) async {
  final run = await getRunById(runId);  // Query 1
  final stationsSnapshot = await _firestore
      .collection('gauge_stations')
      .where('riverRunId', isEqualTo: runId)  // Query 2
      .get();
  
  if (run.riverId.isNotEmpty) {
    river = await RiverService.getRiverById(run.riverId);  // Query 3
  }
}
```

**Impact:**
- Each favorite requires 3 sequential queries
- No batching or parallelization

**Solution:**
✅ **Parallel queries + batch fetching**
```dart
// Fetch run and stations in parallel
final results = await Future.wait([
  getRunById(runId),
  _firestore
      .collection('gauge_stations')
      .where('riverRunId', isEqualTo: runId)
      .get(),
]);

final run = results[0];
final stationsSnapshot = results[1];

// Then fetch river if needed
final river = run.riverId.isNotEmpty 
    ? await RiverService.getRiverById(run.riverId)
    : null;
```

**Expected Improvement:** 3 sequential queries → 2 queries (1 parallel) = **33% faster**

---

## 🟡 Secondary Performance Issues

### 6. **Unnecessary Test Code in Production**
**Location:** `lib/screens/river_levels_screen.dart` - initState()

```dart
void initState() {
  super.initState();
  if (kDebugMode) {
    _testLiveDataService();  // Makes API call on every screen load in debug
  }
}
```

**Solution:** Remove test code from screen initialization

---

### 7. **Redundant State Management**
**Location:** `lib/screens/river_levels_screen.dart`

**Problem:**
- Screen maintains local cache: `_liveDataCache`
- Service maintains cache: `LiveWaterDataService._liveDataCache`
- Provider maintains cache: `LiveWaterDataProvider._liveDataCache`
- Three separate caches for the same data!

**Solution:** Use **only** LiveWaterDataProvider

---

## 🟢 Quick Wins (Easy Implementation)

### Quick Win 1: Remove Debug Code
**Time to implement:** 5 minutes  
**Impact:** 1-2 seconds faster in debug mode

```dart
// REMOVE this from initState():
if (kDebugMode) {
  _testLiveDataService();
}
```

### Quick Win 2: Optimize Build Method
**Time to implement:** 15 minutes  
**Impact:** Eliminates duplicate triggers

```dart
// MOVE data loading from build() to didChangeDependencies()
// See Solution #3 above
```

### Quick Win 3: Use Existing Provider
**Time to implement:** 30 minutes  
**Impact:** 50-75% reduction in API calls

```dart
// REPLACE local _liveDataCache with LiveWaterDataProvider
// Provider already has deduplication built-in!
```

---

## 📊 Implementation Priority

### Phase 1: Immediate (1-2 hours) - 60% improvement
1. ✅ Remove debug test code from initState()
2. ✅ Move data loading to didChangeDependencies()
3. ✅ Migrate to LiveWaterDataProvider fully
4. ✅ Add memory caching to RiverRunProvider

### Phase 2: Short-term (2-4 hours) - 80% improvement
5. ✅ Implement batch Firestore queries with whereIn
6. ✅ Parallelize river data fetching
7. ✅ Add proper error boundaries for graceful failures

### Phase 3: Medium-term (1-2 days) - 90% improvement
8. ✅ Add persistent local storage caching
9. ✅ Implement offline support
10. ✅ Add prefetching for predicted favorites

---

## 🎯 Expected Results

### Current Performance
- **Cold start:** 8-15 seconds
- **With cache:** 8-15 seconds (no cache exists)
- **Firestore reads per load:** 30-40 for 10 favorites
- **API calls per load:** 10-40 (with duplicates)

### After Phase 1 Optimizations
- **Cold start:** 3-5 seconds
- **With cache:** 0.5-1 second
- **Firestore reads per load:** 30-40 (unchanged)
- **API calls per load:** 10-15 (reduced duplicates)

### After Phase 2 Optimizations
- **Cold start:** 1-3 seconds ⚡
- **With cache:** 0.1-0.5 seconds ⚡⚡
- **Firestore reads per load:** 3-5 (85% reduction) ⚡
- **API calls per load:** 10 (deduplicated) ⚡

### After Phase 3 Optimizations
- **Cold start:** 1-2 seconds ⚡
- **With cache:** <0.1 seconds (instant) ⚡⚡⚡
- **Firestore reads per load:** 0-3 (95% reduction) ⚡⚡
- **API calls per load:** 0-10 (offline support) ⚡

---

## 🛠️ Code Examples for Implementation

### Example 1: Batch Firestore Query for Favorites

**File:** `lib/providers/river_run_provider.dart`

```dart
Future<void> loadFavoriteRuns(Set<String> favoriteRunIds) async {
  if (favoriteRunIds.isEmpty) {
    _favoriteRuns = [];
    notifyListeners();
    return;
  }

  setLoading(true);
  setError(null);

  try {
    // Check memory cache first
    final cachedRuns = _getCachedRuns(favoriteRunIds);
    if (cachedRuns.length == favoriteRunIds.length) {
      _favoriteRuns = cachedRuns;
      notifyListeners();
      setLoading(false);
      return;
    }

    // Batch fetch runs (max 10 per whereIn query)
    final List<RiverRunWithStations> allRuns = [];
    final runIdBatches = _createBatches(favoriteRunIds.toList(), 10);

    for (final batch in runIdBatches) {
      final runsSnapshot = await _firestore
          .collection('river_runs')
          .where(FieldPath.documentId, whereIn: batch)
          .get();

      final runs = runsSnapshot.docs
          .map((doc) => RiverRun.fromMap(doc.data(), docId: doc.id))
          .toList();

      // Extract unique river IDs and station IDs for this batch
      final riverIds = runs.map((r) => r.riverId).where((id) => id.isNotEmpty).toSet();
      final runIds = runs.map((r) => r.id).toList();

      // Parallel fetch rivers and stations
      final results = await Future.wait([
        _fetchRivers(riverIds),
        _fetchStationsForRuns(runIds),
      ]);

      final riverMap = results[0] as Map<String, River>;
      final stationsMap = results[1] as Map<String, List<GaugeStation>>;

      // Combine into RiverRunWithStations
      for (final run in runs) {
        final river = riverMap[run.riverId];
        final stations = stationsMap[run.id] ?? [];
        allRuns.add(RiverRunWithStations(
          run: run,
          stations: stations,
          river: river,
        ));
      }
    }

    _favoriteRuns = allRuns;
    _cacheRuns(allRuns); // Store in memory cache
    notifyListeners();
  } catch (e) {
    setError(e.toString());
  } finally {
    setLoading(false);
  }
}

Future<Map<String, River>> _fetchRivers(Set<String> riverIds) async {
  if (riverIds.isEmpty) return {};
  
  final riverIdBatches = _createBatches(riverIds.toList(), 10);
  final Map<String, River> riverMap = {};

  for (final batch in riverIdBatches) {
    final snapshot = await _firestore
        .collection('rivers')
        .where(FieldPath.documentId, whereIn: batch)
        .get();

    for (final doc in snapshot.docs) {
      riverMap[doc.id] = River.fromMap(doc.data(), docId: doc.id);
    }
  }

  return riverMap;
}

Future<Map<String, List<GaugeStation>>> _fetchStationsForRuns(
  List<String> runIds,
) async {
  if (runIds.isEmpty) return {};

  final runIdBatches = _createBatches(runIds, 10);
  final Map<String, List<GaugeStation>> stationsMap = {};

  for (final batch in runIdBatches) {
    final snapshot = await _firestore
        .collection('gauge_stations')
        .where('riverRunId', whereIn: batch)
        .where('isActive', isEqualTo: true)
        .get();

    for (final doc in snapshot.docs) {
      final station = GaugeStation.fromMap(doc.data(), docId: doc.id);
      final runId = station.riverRunId;
      stationsMap.putIfAbsent(runId, () => []).add(station);
    }
  }

  return stationsMap;
}

List<List<T>> _createBatches<T>(List<T> items, int batchSize) {
  final batches = <List<T>>[];
  for (int i = 0; i < items.length; i += batchSize) {
    batches.add(items.skip(i).take(batchSize).toList());
  }
  return batches;
}
```

### Example 2: Proper Lifecycle Data Loading

**File:** `lib/screens/river_levels_screen.dart`

```dart
class _RiverLevelsScreenState extends State<RiverLevelsScreen> {
  Set<String> _lastFavoriteRunIds = {};
  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Only run once and when dependencies actually change
    if (!_isInitialized) {
      _isInitialized = true;
      _initializeData();
      return;
    }

    final currentFavoriteIds = context.read<FavoritesProvider>().favoriteRunIds;
    if (!setEquals(_lastFavoriteRunIds, currentFavoriteIds)) {
      _lastFavoriteRunIds = Set.from(currentFavoriteIds);
      _loadFavoriteData();
    }
  }

  Future<void> _initializeData() async {
    final favoritesProvider = context.read<FavoritesProvider>();
    _lastFavoriteRunIds = Set.from(favoritesProvider.favoriteRunIds);
    await _loadFavoriteData();
  }

  Future<void> _loadFavoriteData() async {
    if (_lastFavoriteRunIds.isEmpty) return;

    final riverRunProvider = context.read<RiverRunProvider>();
    final liveDataProvider = context.read<LiveWaterDataProvider>();

    // Load runs from Firestore (with caching)
    await riverRunProvider.loadFavoriteRuns(_lastFavoriteRunIds);

    // Extract station IDs and fetch live data
    final runs = riverRunProvider.favoriteRuns;
    final stationIds = runs
        .map((r) => r.run.stationId)
        .where((id) => id != null && id.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();

    if (stationIds.isNotEmpty) {
      // This call is automatically deduplicated by the provider
      await liveDataProvider.fetchMultipleStations(stationIds);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<FavoritesProvider, RiverRunProvider, LiveWaterDataProvider>(
      builder: (context, favoritesProvider, riverRunProvider, liveDataProvider, child) {
        // Pure UI rendering - no data loading logic here
        final favoriteRuns = riverRunProvider.favoriteRuns;
        final isLoading = riverRunProvider.isLoading;

        return Scaffold(
          body: isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildFavoritesList(favoriteRuns, liveDataProvider),
        );
      },
    );
  }

  Widget _buildFavoritesList(
    List<RiverRunWithStations> runs,
    LiveWaterDataProvider liveDataProvider,
  ) {
    // Use liveDataProvider.getLiveData(stationId) to get cached live data
    // No direct API calls from UI
  }
}
```

---

## 📝 Additional Recommendations

### Monitoring & Analytics
1. Add Firebase Performance Monitoring to track:
   - App startup time
   - Screen load times
   - API call durations
   - Firestore query counts

2. Add custom traces:
```dart
final trace = FirebasePerformance.instance.newTrace('load_favorites');
await trace.start();
// ... load favorites ...
await trace.stop();
```

### User Experience Improvements
1. **Show stale data immediately** while refreshing in background
2. **Progressive loading**: Show cached UI instantly, then update
3. **Skeleton screens**: Replace spinner with content placeholders
4. **Pull-to-refresh**: Manual refresh instead of auto-refresh
5. **Optimistic updates**: Update UI immediately, sync in background

---

## 🎓 Summary

The current implementation suffers from a classic **N+1 query problem** combined with **lack of caching** and **redundant API calls**. The good news is that many optimizations are straightforward to implement:

✅ **Batch queries instead of loops** (biggest impact)  
✅ **Use existing LiveWaterDataProvider** (already built!)  
✅ **Add memory caching** (simple Map-based cache)  
✅ **Move data loading to proper lifecycle** (avoid build() triggers)  

Implementing Phase 1 alone will give you a **60% improvement** with just **1-2 hours of work**. The architecture already has most of the pieces needed (LiveWaterDataProvider, proper models), they just need to be wired up correctly.

The app is well-structured with good separation of concerns - it just needs optimization of the data fetching layer. Focus on the Firestore batch queries first, as that's the biggest bottleneck.
