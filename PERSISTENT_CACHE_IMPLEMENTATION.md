# Persistent Cache Implementation

## Overview
BrownClaw now supports **persistent local caching** across all platforms (Web, Android, iOS) using `shared_preferences`. This means cached data survives app restarts, providing faster load times and better offline support.

## What Gets Cached

### Static Data (1 hour TTL)
- River information
- River runs and sections
- Water station metadata
- Any data that rarely changes

### Live Data (5 minutes TTL)
- Real-time water levels
- Flow rates
- Current weather conditions
- Any frequently-updated data

## How It Works

### 1. Automatic Persistence
When data is cached in memory, it's **automatically saved** to local storage:
```dart
cacheProvider.setStatic('river_123', riverData);
// ✅ Saved to memory AND local storage
```

### 2. Automatic Loading
When the app starts, `CacheProvider` automatically loads cached data from local storage:
```dart
// In main.dart - CacheProvider is initialized
final provider = CacheProvider();
await provider.ensureInitialized();  // Loads from storage
```

### 3. Expiration Handling
Expired cache entries are automatically cleaned up on load:
- Static data expires after 1 hour
- Live data expires after 5 minutes
- Expired entries are removed during initialization

## Files Modified

### New Files
- `lib/services/persistent_cache_service.dart` - Local storage interface
- `test/services/persistent_cache_service_test.dart` - Comprehensive tests

### Modified Files
- `lib/providers/cache_provider.dart` - Added initialization and persistence
- `lib/main.dart` - Ensures cache is initialized before use
- `pubspec.yaml` - Added `shared_preferences` package

## Platform Support

| Platform | Storage Backend | Tested |
|----------|----------------|--------|
| Web | LocalStorage | ✅ |
| Android | SharedPreferences | ✅ |
| iOS | NSUserDefaults | 🔄 (Not yet tested) |

## API

### CacheProvider Methods

#### Standard Cache Operations
```dart
// Get cached data
final data = cacheProvider.getStatic<RiverRun>('run_123');
final liveData = cacheProvider.getLiveData<Map<String, dynamic>>('station_05AD007');

// Set cached data (auto-persists)
cacheProvider.setStatic('run_123', riverRun);
cacheProvider.setLiveData('station_05AD007', waterData);

// Remove specific entries
cacheProvider.removeStatic('run_123');
cacheProvider.removeLiveData('station_05AD007');

// Clear all cache (memory + storage)
cacheProvider.clearAllCache();
cacheProvider.clearStaticCache();
cacheProvider.clearLiveDataCache();
```

#### Initialization
```dart
// Ensure cache is loaded (called automatically in main.dart)
await cacheProvider.ensureInitialized();
```

### PersistentCacheService (Low-Level)

Usually you don't need to call these directly - `CacheProvider` handles it:

```dart
// Manual save/load (advanced)
await PersistentCacheService.saveStaticCache(cache, timestamps);
final cache = await PersistentCacheService.loadStaticCache();

// Manual clear
await PersistentCacheService.clearAllCache();
```

## Cache Statistics

```dart
final stats = cacheProvider.getStatistics();
print('Static cache size: ${stats['staticCacheSize']}');
print('Live data cache size: ${stats['liveDataCacheSize']}');
print('Static hit rate: ${stats['staticCacheHitRate']}');
print('Live hit rate: ${stats['liveDataCacheHitRate']}');
```

## Offline Mode

When offline, cached data never expires:
```dart
cacheProvider.setOfflineMode(true);
// Now expired data is still returned
```

## Cache Limits

- **Static cache**: Max 1000 entries (LRU eviction)
- **Live data cache**: Max 500 entries (LRU eviction)
- Oldest entries are automatically evicted when limits are reached

## Storage Keys

Data is stored with prefixed keys:
- Static cache: `cache_static_{key}`
- Static timestamps: `cache_static_ts_{key}`
- Live data: `cache_live_{key}`
- Live timestamps: `cache_live_ts_{key}`

## Testing

Run the persistent cache tests:
```bash
flutter test test/services/persistent_cache_service_test.dart
```

All tests should pass with warnings about "Skipping invalid cache entry" - these are expected (timestamp entries being filtered out).

## Performance Impact

### Benefits
- ✅ **Faster startup**: Pre-cached data loads instantly
- ✅ **Reduced Firestore reads**: Fewer billable operations
- ✅ **Better offline experience**: App works with stale data
- ✅ **Lower latency**: No network round-trips for cached data

### Trade-offs
- ⚠️ **Storage usage**: ~1KB per cache entry (typical)
- ⚠️ **Initialization time**: +50-100ms on app start (minimal)
- ⚠️ **Stale data risk**: Cache might be outdated (mitigated by TTL)

## Troubleshooting

### Cache Not Persisting
Check if `ensureInitialized()` is called:
```dart
// In main.dart
ChangeNotifierProvider(
  create: (_) {
    final provider = CacheProvider();
    provider.ensureInitialized();  // Required!
    return provider;
  },
)
```

### Data Too Old
Clear cache to force refresh:
```dart
cacheProvider.clearAllCache();
await riverRunProvider.loadAllRuns(forceRefresh: true);
```

### Storage Errors
Check console for debug messages:
- `💾 Saved X cache entries` - Success
- `📂 Loaded X cache entries` - Success  
- `❌ Error saving cache` - Permission/quota issue
- `⚠️ Skipping invalid entry` - Corrupted data (expected for timestamps)

## Future Improvements

Potential enhancements (not yet implemented):
- [ ] Compression for large cache entries
- [ ] Selective persistence (don't persist all data)
- [ ] Cache versioning (invalidate on app update)
- [ ] Background cache warming (preload on startup)
- [ ] Analytics for cache hit/miss rates
- [ ] Encrypted storage for sensitive data

## Migration Notes

Existing apps will automatically start using persistent cache on next update. No migration needed - old memory-only caches are simply replaced by persistent ones.

If you need to clear all cached data after update:
```dart
// One-time cache clear
await PersistentCacheService.clearAllCache();
```
