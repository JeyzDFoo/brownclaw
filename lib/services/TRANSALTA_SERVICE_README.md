# TransAlta Flow Service

Service for fetching and displaying TransAlta Barrier Dam flow data in the BrownClaw Flutter app.

## Overview

TransAlta operates hydro facilities in Kananaskis, Alberta:
- **Barrier Dam** - Main facility
- **Pocaterra Hydro Facility**

This service provides:
- Real-time flow data
- 4-day hourly forecasts
- Water arrival times (with 45-minute travel time from dam)
- High flow schedules for trip planning

## Files

- `lib/models/transalta_flow_data.dart` - Data models
- `lib/services/transalta_service.dart` - API service
- `lib/widgets/transalta_flow_widget.dart` - Example UI widget

## Usage

### Basic Usage

```dart
import 'package:brownclaw/services/transalta_service.dart';
import 'package:brownclaw/models/transalta_flow_data.dart';

// Fetch all flow data
final flowData = await transAltaService.fetchFlowData();

// Get current flow
final currentFlow = await transAltaService.getCurrentFlow();
print('Current flow: ${currentFlow?.barrierFlow} m³/s');

// Get high flow schedule (≥20 m³/s)
final schedule = await transAltaService.getHighFlowSchedule(threshold: 20.0);
for (final period in schedule) {
  print('${period.dateString}: ${period.arrivalTimeRange}');
}

// Check if runnable now
final isRunnable = await transAltaService.isRunnableNow(minFlow: 20.0);

// Get next high flow time
final nextHighFlow = await transAltaService.getNextHighFlowTime(threshold: 20.0);
```

### Using the Widget

```dart
import 'package:brownclaw/widgets/transalta_flow_widget.dart';

// In your widget tree:
TransAltaFlowWidget(
  threshold: 20.0, // Show flows ≥20 m³/s
)
```

### Advanced Usage

```dart
// Get all flow data
final data = await transAltaService.fetchFlowData();

if (data != null) {
  // Get current conditions
  final current = data.currentFlow;
  print('Status: ${current?.flowStatus.displayName}');
  print('Water arrives: ${current?.getArrivalTimeString()}');
  
  // Get high flow hours
  final highFlows = data.getHighFlowHours(threshold: 20.0);
  
  for (final period in highFlows) {
    print('\nDay ${period.dayNumber} (${period.dateString}):');
    print('  ${period.totalHours} hours of high flow');
    print('  Water arrives: ${period.arrivalTimeRange}');
    
    // Get individual hours
    for (final entry in period.entries) {
      print('  - ${entry.hourEndingString}: ${entry.barrierFlow} m³/s');
      print('    Arrives: ${entry.getArrivalTimeString()}');
    }
  }
}

// Force refresh (bypass cache)
final freshData = await transAltaService.fetchFlowData(forceRefresh: true);

// Clear cache
transAltaService.clearCache();

// Check cache status
final cacheAge = transAltaService.getCacheAgeMinutes();
final isValid = transAltaService.isCacheValid;
```

## Data Models

### TransAltaFlowData
Main data container with 4 days of forecasts.

Properties:
- `forecasts` - List of daily forecasts
- `currentFlow` - Most recent flow data
- `getHighFlowHours()` - Filter for high flow periods

### HourlyFlowEntry
Individual hourly flow measurement.

Properties:
- `barrierFlow` - Flow at Barrier Dam (m³/s)
- `pocaterraFlow` - Flow at Pocaterra (m³/s)
- `hourEnding` - HE number (1-24)
- `dateTime` - When flow starts
- `flowStatus` - Status enum (offline/low/moderate/high)
- `getWaterArrivalTime()` - Calculate downstream arrival
- `getArrivalTimeString()` - Formatted arrival time (e.g., "4:45pm")

### HighFlowPeriod
A day with high flow hours.

Properties:
- `date` - Date of the period
- `dayNumber` - 0=today, 1=tomorrow, etc.
- `entries` - List of high flow hours
- `totalHours` - Count of high flow hours
- `arrivalTimeRange` - First to last arrival time
- `threshold` - Flow threshold used

### FlowStatus
Enum for flow conditions:
- `offline` - 0 m³/s (plant offline)
- `tooLow` - <10 m³/s
- `low` - 10-20 m³/s
- `moderate` - 20-30 m³/s (good for paddling)
- `high` - 30+ m³/s (advanced only)

## Hour Ending (HE) Explained

TransAlta uses "Hour Ending" format from AESO:
- **HE01** = 00:00:01 to 01:00:00 (midnight to 1am)
- **HE17** = 16:00:01 to 17:00:00 (4pm to 5pm)
- **HE24** = 23:00:01 to 00:00:00 (11pm to midnight)

Flow is for the ENTIRE hour period, not just the end.

## Water Travel Time

- **45 minutes** from Barrier Dam to Canoe Meadows (downstream)
- Automatically calculated in `getWaterArrivalTime()`
- All displayed times include this travel time

## Caching

- Automatic 15-minute cache to reduce API calls
- Use `forceRefresh: true` to bypass cache
- Cache survives if API call fails
- Use `clearCache()` to manually reset

## API Endpoint

```
https://transalta.com/river-flows/?get-riverflow-data=1
```

Returns JSON with:
```json
{
  "name": "pv_hydro_river_flow_by_site",
  "elements": [
    {
      "day": 0,
      "entry": [
        {
          "period": "2025-10-17 17",
          "barrier": 26,
          "pocaterra": 23
        },
        ...
      ]
    },
    ...
  ]
}
```

## Integration Examples

### River Detail Page
Show TransAlta flows on the Kananaskis River detail page:

```dart
// In your river detail widget
if (river.name.contains('Kananaskis')) {
  TransAltaFlowWidget(threshold: 20.0)
}
```

### Dashboard Widget
Add to main dashboard:

```dart
FutureBuilder<HourlyFlowEntry?>(
  future: transAltaService.getCurrentFlow(),
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      final flow = snapshot.data!;
      return ListTile(
        leading: Text(flow.flowStatus.emoji, style: TextStyle(fontSize: 32)),
        title: Text('Kananaskis River'),
        subtitle: Text('${flow.barrierFlow} m³/s - ${flow.flowStatus.displayName}'),
        trailing: Text(flow.getArrivalTimeString()),
      );
    }
    return CircularProgressIndicator();
  },
)
```

### Notification Service
Notify users when high flow is available:

```dart
final nextHighFlow = await transAltaService.getNextHighFlowTime(threshold: 20.0);
if (nextHighFlow != null) {
  final hoursUntil = nextHighFlow.difference(DateTime.now()).inHours;
  if (hoursUntil < 2 && hoursUntil > 0) {
    // Send notification: "Kananaskis high flow in $hoursUntil hours!"
  }
}
```

### Filter Rivers by Current Flow
```dart
final isRunnable = await transAltaService.isRunnableNow(minFlow: 20.0);
if (isRunnable) {
  // Show Kananaskis in "Currently Runnable" list
}
```

## Testing

The service includes cache management for testing:

```dart
// Clear cache before testing
transAltaService.clearCache();

// Force fresh data
final data = await transAltaService.fetchFlowData(forceRefresh: true);

// Check cache status
expect(transAltaService.isCacheValid, true);
expect(transAltaService.getCacheAgeMinutes(), lessThan(1));
```

## Safety Notes

Always include appropriate safety warnings when displaying this data:
- Flows can change rapidly without notice
- Check TransAlta website for latest updates
- Respect all safety signage and barriers
- When flow shows 0, the plant is offline
- High flows can create hazardous conditions

## Future Enhancements

Potential improvements:
- [ ] Historical flow data storage
- [ ] Flow change notifications
- [ ] Integration with weather forecasts
- [ ] User-configurable thresholds
- [ ] Favorite flow alerts
- [ ] Comparison with gauge station data
- [ ] Flow predictions based on electricity demand
