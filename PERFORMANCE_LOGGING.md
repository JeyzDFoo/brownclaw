# Performance Logging Implementation

This document describes the performance logging system implemented to identify startup bottlenecks in the Brown Paw web app.

## Overview

A comprehensive performance logging system has been added to track the app startup process from initial page load through to the first rendered frame. This is especially useful for identifying slow initialization on iOS devices.

## Components

### 1. PerformanceLogger Utility (`lib/utils/performance_logger.dart`)

A centralized logging utility that tracks timestamps and durations throughout the app lifecycle.

**Key Methods:**
- `markAppStart()` - Call at the very beginning of app initialization
- `log(String label, {String? detail})` - Log a checkpoint with time since app start
- `printSummary()` - Print a complete summary of all logged checkpoints
- `getTimeSinceStart()` - Get milliseconds since app start

### 2. Web Performance Tracking (`web/index.html`)

Browser-level performance tracking that logs:
- Initial page load start
- DOM ready time
- Window load complete
- Flutter first frame rendered
- Launch screen removal

### 3. Dart/Flutter Performance Tracking

Logging added throughout the Flutter app initialization:

#### Main Entry Point (`lib/main.dart`)
- App start marker
- Flutter binding initialization
- Firebase initialization
- Analytics logging
- runApp call
- Provider creation (all 10 providers)
- MaterialApp building
- Auth state checking
- Screen loading decisions

#### MainScreen (`lib/screens/main_screen.dart`)
- initState timing
- Version check timing
- First frame callback
- Performance summary print

#### FavouritesScreen (`lib/screens/favourites_screen.dart`)
- Screen initialization
- Favorites loading start
- River runs loaded
- Live water data loaded

## How to Use

### 1. View Logs in Browser Console

When running the web app, open browser DevTools (F12) and check the Console tab. You'll see logs like:

```
⏱️ [WEB] Page load started
⏱️ [WEB] DOM ready (+234ms)
⏱️ [PERF] App startup initiated
⏱️ [PERF] flutter_binding_initialized (+12ms)
⏱️ [PERF] firebase_initialized (+456ms)
⏱️ [PERF] analytics_logged (+478ms)
⏱️ [PERF] runApp_called (+480ms)
⏱️ [PERF] main_app_build_started (+481ms)
⏱️ [PERF] cache_provider_creating (+482ms)
⏱️ [PERF] cache_provider_created (+485ms)
...
⏱️ [WEB] Flutter first frame rendered (+2341ms)
```

### 2. View Flutter Logs

In the terminal where you're running `flutter run -d chrome` (or similar), you'll see:

```
⏱️ [PERF] App startup initiated
⏱️ [PERF] flutter_binding_initialized (+12ms)
⏱️ [PERF] firebase_initialized (+456ms)
...
📊 PERFORMANCE SUMMARY
============================================================
⏱️ [PERF] flutter_binding_initialized (+12ms)
⏱️ [PERF] firebase_initialized (+456ms)
⏱️ [PERF] analytics_logged (+478ms)
...
🏁 Total startup time: 2341ms
============================================================
```

### 3. iOS Safari Testing

For iOS devices:
1. Connect your iOS device to your Mac
2. Open Safari on Mac
3. Enable Developer menu (Safari → Preferences → Advanced → Show Develop menu)
4. Navigate to Develop → [Your Device] → [Your App Tab]
5. View Console logs showing the same performance data

Alternatively, use remote debugging:
1. Enable Web Inspector on iOS (Settings → Safari → Advanced → Web Inspector)
2. Connect device to Mac
3. Open Safari Developer Tools

## Interpreting the Results

### Key Milestones to Monitor

1. **DOM Ready** (~200-500ms on fast connections)
   - Time for HTML/CSS to load and parse
   - If high: Check network speed, reduce initial HTML size

2. **Flutter Binding** (~10-50ms)
   - Flutter framework initialization
   - Should be fast, if slow it may indicate device CPU issues

3. **Firebase Initialization** (~200-800ms)
   - Firebase SDK loading and connection
   - If high: Check network latency to Firebase servers
   - iOS may show higher times due to Safari constraints

4. **Provider Creation** (~100-300ms total)
   - All 10 providers being instantiated
   - Watch for any single provider taking >50ms
   - Favorites and User providers include Firebase listeners

5. **First Frame** (Total: 1500-3000ms target)
   - Complete app ready and rendered
   - iOS Safari typically 1.5-2x slower than desktop
   - If >5000ms: Significant performance issue

### Common Bottlenecks

**Slow Firebase Init (>1000ms)**
- Network latency issue
- Try pre-connecting to Firebase domains in index.html
- Consider lazy-loading non-critical Firebase features

**Slow Provider Creation (>500ms)**
- Check which specific provider is slow from logs
- Consider lazy initialization for non-critical providers
- Review provider constructors for heavy operations

**Slow First Frame (>5000ms)**
- May indicate heavy initial screen rendering
- Check FavouritesScreen data loading
- Consider showing skeleton screens earlier
- Review widget tree complexity

## Adding More Logging

To add logging to additional components:

```dart
// Import the logger
import '../utils/performance_logger.dart';

// Log a checkpoint
PerformanceLogger.log('my_checkpoint_name');

// Log with additional detail
PerformanceLogger.log('data_loaded', detail: '${items.length} items');

// In async operations
await someAsyncOperation();
PerformanceLogger.log('async_operation_complete');
```

## Production Builds

The performance logging only runs in debug mode (`kDebugMode`) and has minimal overhead. In production builds, all logging is automatically stripped out by the Dart compiler.

To disable logging in debug builds, you can comment out specific log calls or modify the `PerformanceLogger` class to check an additional flag.

## Next Steps

1. **Run the app on iOS** and capture the performance logs
2. **Identify the slowest phase** (usually Firebase init or provider creation)
3. **Focus optimization efforts** on the bottleneck identified
4. **Test improvements** by comparing before/after timing logs

## Optimization Strategies

Based on timing results:

- **Firebase slow**: Add DNS prefetch, use lazy init, or bundle config
- **Providers slow**: Lazy load non-critical providers, defer heavy operations
- **First frame slow**: Reduce initial widget tree, defer data loading, add skeleton screens
- **Network slow**: Add service worker caching, optimize asset sizes
