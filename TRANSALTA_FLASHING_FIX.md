# TransAlta Provider Flashing Fix

## Problem Description

The TransAlta provider was experiencing rapid flashing/flickering in web deployment but working fine in local debug mode.

### Root Cause

The issue was caused by **multiple concurrent fetch calls** being triggered during rapid widget rebuilds:

1. **In `favourites_screen.dart` (line 321-323)**:
   ```dart
   if (favoriteRuns.any((run) => _isKananaskis(run))) {
     if (!transAltaProvider.hasData && !transAltaProvider.isLoading) {
       Future.microtask(() => transAltaProvider.fetchFlowData());
     }
   }
   ```

2. **In `transalta_flow_widget.dart` (line 22-25)**:
   ```dart
   if (!transAltaProvider.hasData &&
       !transAltaProvider.isLoading &&
       transAltaProvider.error == null) {
     Future.microtask(() => transAltaProvider.fetchFlowData());
   }
   ```

### Why It Only Happened in Web

- **Web deployment** has different timing characteristics than debug mode
- Network latency is often higher in production
- Provider rebuilds happen more frequently due to:
  - Network state changes
  - Parent widget updates
  - Flutter web's rendering pipeline differences
- This caused the `build()` method to be called many times **before** the first microtask could execute
- Each build scheduled a new fetch, creating a cascade of API calls
- The rapid loading/loaded state changes caused the UI to flash

### Race Condition Flow

```
Time 0ms:  Build called → Check passes → Schedule fetch #1
Time 5ms:  Build called → Check passes → Schedule fetch #2
Time 10ms: Build called → Check passes → Schedule fetch #3
Time 15ms: Fetch #1 executes → Sets loading=true, triggers rebuild
Time 16ms: Build called → Check fails (loading=true) → No fetch scheduled
Time 250ms: Fetch #1 completes → Sets data, triggers rebuild  
Time 251ms: Build called → Has data now, no fetch
Time 255ms: Fetch #2 executes → Sets loading=true, triggers rebuild (FLASH!)
Time 260ms: Build called → Check fails (loading=true)
Time 500ms: Fetch #2 completes → Sets data, triggers rebuild
Time 505ms: Fetch #3 executes → FLASH CONTINUES...
```

## Solution

Implemented **three layers of protection** against duplicate fetches:

### 1. Provider-Level Guard (`transalta_provider.dart`)

Added a `_isFetching` flag to prevent concurrent fetch operations:

```dart
class TransAltaProvider extends ChangeNotifier {
  bool _isFetching = false; // Guard against concurrent fetch calls

  Future<void> fetchFlowData({bool forceRefresh = false}) async {
    // Guard against concurrent fetch calls
    if (_isFetching) {
      debugPrint('TransAltaProvider: Already fetching, skipping duplicate call');
      return;
    }

    // Return cached data if valid
    if (!forceRefresh && isCacheValid) {
      return;
    }

    _isFetching = true;
    _isLoading = true;
    // ... fetch logic ...
    finally {
      _isLoading = false;
      _isFetching = false;
      notifyListeners();
    }
  }
}
```

**Benefits**:
- Prevents overlapping API calls at the provider level
- Works across all consumers of the provider
- Provides immediate protection even if widgets call fetchFlowData multiple times

### 2. Widget-Level Guard (`transalta_flow_widget.dart`)

Converted from `StatelessWidget` to `StatefulWidget` with initialization flag:

```dart
class _TransAltaFlowWidgetState extends State<TransAltaFlowWidget> {
  bool _hasInitialized = false;

  @override
  Widget build(BuildContext context) {
    return Consumer2<TransAltaProvider, PremiumProvider>(
      builder: (context, transAltaProvider, premiumProvider, child) {
        // Fetch data ONCE on first build if not already loaded
        if (!_hasInitialized &&
            !transAltaProvider.hasData &&
            !transAltaProvider.isLoading &&
            transAltaProvider.error == null) {
          _hasInitialized = true;
          Future.microtask(() => transAltaProvider.fetchFlowData());
        }
        // ...
      },
    );
  }
}
```

**Benefits**:
- Widget only schedules fetch once in its lifetime
- Prevents multiple microtasks from the same widget instance
- Maintains clean initialization pattern

### 3. Screen-Level Guard (`favourites_screen.dart`)

Added initialization flag to prevent repeated fetch scheduling:

```dart
class _FavouritesScreenState extends State<FavouritesScreen>
    with AutomaticKeepAliveClientMixin {
  bool _hasInitializedTransAlta = false;

  @override
  Widget build(BuildContext context) {
    // ...
    // Fetch TransAlta data ONCE if we have any Kananaskis rivers
    if (!_hasInitializedTransAlta && 
        favoriteRuns.any((run) => _isKananaskis(run))) {
      if (!transAltaProvider.hasData && !transAltaProvider.isLoading) {
        _hasInitializedTransAlta = true;
        Future.microtask(() => transAltaProvider.fetchFlowData());
      }
    }
  }
}
```

**Benefits**:
- Screen only triggers fetch once
- Respects AutomaticKeepAliveClientMixin state
- Works well with tab navigation

## Files Modified

1. ✅ `lib/providers/transalta_provider.dart` - Added `_isFetching` guard
2. ✅ `lib/widgets/transalta_flow_widget.dart` - Converted to StatefulWidget with init flag
3. ✅ `lib/screens/favourites_screen.dart` - Added `_hasInitializedTransAlta` flag

## Testing Recommendations

### Local Testing
1. Run in debug mode - should work as before
2. Test hot reload - should not cause extra fetches
3. Navigate between tabs - should maintain cache correctly

### Web Deployment Testing
1. Test with network throttling (slow 3G) to simulate latency
2. Navigate quickly between favorites and river detail screens
3. Add/remove Kananaskis rivers from favorites
4. Watch Network tab in DevTools for duplicate API calls
5. Verify no flashing/flickering in UI

### Expected Behavior
- ✅ Single API call when TransAlta data is needed
- ✅ 15-minute cache respected
- ✅ Smooth UI with no flashing
- ✅ Force refresh button still works
- ✅ No duplicate network requests

## Debug Output

You should see log messages like:
```
TransAltaProvider: Fetching flow data from API...
TransAltaProvider: Successfully fetched 4 days of data
```

Or when cache is valid:
```
TransAltaProvider: Using cached data (5min old)
```

If duplicates were attempted:
```
TransAltaProvider: Already fetching, skipping duplicate call
```

## Additional Notes

### Why Not Just Use `didChangeDependencies()`?

While `didChangeDependencies()` could work, it's called frequently in Flutter web and can still trigger multiple times during initialization. The initialization flag approach is:
- More explicit
- Easier to reason about
- More performant (no unnecessary checks)

### Cache Behavior

The 15-minute cache is still fully functional:
- Cache is checked before `_isFetching` guard
- Valid cache returns immediately without any state changes
- Force refresh bypasses cache but still respects `_isFetching` guard

### Future Improvements

Consider adding:
1. Exponential backoff for failed requests
2. Request cancellation tokens
3. More sophisticated cache invalidation strategies
4. Background refresh when cache is close to expiring

---

**Implementation Date**: October 17, 2025  
**Status**: ✅ Fixed  
**Impact**: High (resolves production issue)
