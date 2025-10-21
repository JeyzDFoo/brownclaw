# Quick Performance Testing Guide

## 🚀 Quick Start

### Option 1: Run in Chrome (Recommended)
```bash
flutter run -d chrome
```

### Option 2: Use the Test Script
```bash
./test_performance.sh chrome
```

### Option 3: Test on iOS Safari
1. Build for web: `flutter build web`
2. Serve locally: `python3 -m http.server 8000 -d build/web`
3. On iOS device, navigate to: `http://YOUR_MAC_IP:8000`
4. Open Safari DevTools on Mac (Develop → Your Device → localhost)

## 📊 Reading the Logs

### In Terminal
Look for logs like:
```
⏱️ [PERF] flutter_binding_initialized (+12ms)
⏱️ [PERF] firebase_initialized (+456ms)
⏱️ [PERF] cache_provider_created (+485ms)
...
📊 PERFORMANCE SUMMARY
🏁 Total startup time: 2341ms
```

### In Browser Console (F12)
Look for logs like:
```
⏱️ [WEB] Page load started
⏱️ [WEB] DOM ready (+234ms)
⏱️ [WEB] Flutter first frame rendered (+2341ms)
```

## 🎯 Target Benchmarks

### Good Performance
- **DOM Ready**: < 500ms
- **Firebase Init**: < 800ms
- **First Frame**: < 2500ms
- **Total Startup**: < 3000ms

### Acceptable Performance
- **DOM Ready**: < 1000ms
- **Firebase Init**: < 1500ms
- **First Frame**: < 4000ms
- **Total Startup**: < 5000ms

### Poor Performance (Needs Optimization)
- **DOM Ready**: > 1000ms
- **Firebase Init**: > 1500ms
- **First Frame**: > 4000ms
- **Total Startup**: > 5000ms

## 🔍 Common Issues & Solutions

### Issue: Firebase Init is slow (>1500ms)
**Solutions:**
- Check network connection
- Add DNS prefetch to index.html
- Consider lazy loading Firebase features
- Check Firebase console for service issues

### Issue: Provider creation is slow (>500ms)
**Solutions:**
- Review provider constructors
- Move heavy operations to lazy loading
- Defer non-critical provider initialization
- Check specific provider taking the most time

### Issue: First frame is slow (>5000ms)
**Solutions:**
- Reduce initial widget tree complexity
- Defer data loading until after first frame
- Use skeleton screens
- Check FavouritesScreen data loading
- Review async operations in initState

### Issue: Overall slow on iOS only
**Solutions:**
- Safari has stricter resource limits
- Optimize JavaScript bundle size
- Reduce initial asset loading
- Test with iOS-specific profiling tools
- Check for memory leaks or excessive repaints

## 📱 iOS Testing Tips

1. **Enable Web Inspector on iOS:**
   - Settings → Safari → Advanced → Web Inspector

2. **Connect to Mac:**
   - Connect device via USB
   - Open Safari on Mac
   - Go to Develop → [Your Device] → [Your Tab]

3. **Monitor Performance:**
   - Use Timeline tab for frame rates
   - Check Network tab for slow resources
   - Monitor Console for performance logs

4. **Test on Real Device:**
   - Simulators don't represent real performance
   - Test on actual iOS hardware (iPhone/iPad)
   - Test on older devices if possible

## 🛠️ Advanced Debugging

### Add Custom Logging
```dart
import '../utils/performance_logger.dart';

PerformanceLogger.log('my_operation_start');
await myOperation();
PerformanceLogger.log('my_operation_complete');
```

### Measure Specific Duration
```dart
PerformanceLogger.log('phase_1_start');
// ... code ...
PerformanceLogger.log('phase_1_end');

PerformanceLogger.logDuration('Phase 1', 'phase_1_start', 'phase_1_end');
```

### Print Summary Anytime
```dart
PerformanceLogger.printSummary();
```

## 📈 Tracking Improvements

1. **Baseline**: Record current performance metrics
2. **Optimize**: Make targeted improvements
3. **Measure**: Run tests again
4. **Compare**: Check the difference
5. **Iterate**: Continue optimizing bottlenecks

Keep a log of changes and their impact:
```
Before: Total startup 5200ms
- Optimized Firebase init with prefetch
After: Total startup 3800ms (-27% improvement)
```

## 🎨 Visual Performance Tools

### Chrome DevTools Performance Tab
1. Open DevTools (F12)
2. Go to Performance tab
3. Click Record
4. Reload page
5. Stop recording
6. Analyze the timeline

### Lighthouse Audit
1. Open Chrome DevTools
2. Go to Lighthouse tab
3. Select "Performance" category
4. Click "Generate report"
5. Review recommendations

## 💡 Pro Tips

- Test with throttled network (DevTools → Network → Throttling)
- Clear cache between tests for consistent results
- Test in incognito/private mode
- Compare different times of day (server load varies)
- Test on different network types (WiFi, 4G, 5G)
- Use browser's native performance.measure() API for precise timing
