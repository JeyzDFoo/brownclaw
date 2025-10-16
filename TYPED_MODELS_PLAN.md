# Typed Models Implementation Plan

## Current Issue: Raw JSON Object Usage 

The BrownClaw app currently uses raw `Map<String, dynamic>` objects throughout the codebase instead of proper typed models. This leads to:

- **Type Safety Issues**: No compile-time type checking
- **Runtime Errors**: Potential crashes from missing/wrong data types
- **Poor IDE Support**: No auto-completion or refactoring help
- **Maintenance Problems**: Hard to track data structure changes
- **Performance Issues**: Runtime type checking overhead

## 🎯 **Implementation Strategy**

### **Phase 1: Core Data Models (Week 1)**

#### 1.1 Live Water Data Models ✅
- [x] `LiveWaterData` class - Replace `Map<String, dynamic>` for live station data
- [x] `FlowCondition` class - Replace flow status calculations
- [x] `LiveDataStatus` enum - Type-safe status handling

#### 1.2 API Response Models ✅
- [x] `ApiResponse<T>` - Standardized API response wrapper
- [x] `FirestoreResult<T>` - Consistent Firestore query results
- [x] `CacheResult<T>` - Type-safe cache operations

### **Phase 2: Service Layer Updates (Week 2)**

#### 2.1 LiveWaterDataService Updates
**Current Issues:**
```dart
// ❌ Raw JSON returns
static Future<Map<String, dynamic>?> fetchStationData(String stationId)

// ❌ Manual JSON parsing
return {
  'flowRate': flowRate,
  'level': level,
  'stationName': 'Station $stationId',
  'status': 'live',
};
```

**Target Implementation:**
```dart
// ✅ Typed returns
static Future<LiveWaterData?> fetchStationData(String stationId)

// ✅ Structured data creation
return LiveWaterData.fromApiResponse(stationId, rawData, 'csv');
```

**Files to Update:**
- [x] `lib/services/live_water_data_service.dart` - Added TODOs
- [ ] Update method signatures to return `LiveWaterData?`
- [ ] Replace raw Map returns with typed objects
- [ ] Update all callers to use typed methods

#### 2.2 GaugeStationService Updates
**Current Issues:**
```dart
// ❌ Raw Map field access
final updateData = <String, dynamic>{
  'currentDischarge': liveData['flowRate'],
  'currentWaterLevel': liveData['waterLevel'],
};
```

**Target Implementation:**
```dart
// ✅ Typed object access
final updateData = liveData.toFirestoreMap();
```

**Files to Update:**
- [x] `lib/services/gauge_station_service.dart` - Added TODOs
- [ ] Update `updateStationLiveData()` to use `LiveWaterData`
- [ ] Add batch station update methods
- [ ] Implement proper error handling with `ApiResponse<T>`

### **Phase 3: UI Layer Updates (Week 3)**

#### 3.1 RiverLevelsScreen Updates
**Current Issues:**
```dart
// ❌ Raw Map cache
Map<String, Map<String, dynamic>> _liveDataCache = {};

// ❌ Manual field access
final liveData = _getLiveDataForStation(stationId);
if (liveData != null && liveData['flowRate'] != null) {
  return liveData['flowRate'] as double?;
}
```

**Target Implementation:**
```dart
// ✅ Typed cache
Map<String, LiveWaterData> _liveDataCache = {};

// ✅ Type-safe access
final liveData = _getLiveDataForStation(stationId);
return liveData?.flowRate;
```

**Files to Update:**
- [x] `lib/screens/river_levels_screen.dart` - Added TODOs
- [ ] Update cache to use `LiveWaterData` objects
- [ ] Replace raw Map usage with typed methods
- [ ] Update UI widgets to use typed data

### **Phase 4: Advanced Models (Week 4)**

#### 4.1 Search and Filter Models
```dart
// #todo: Create SearchQuery model
class SearchQuery {
  final String query;
  final List<String> provinces;
  final List<String> difficulties;
  final FlowRange? flowRange;
}

// #todo: Create FilterCriteria model  
class FilterCriteria {
  final bool onlyFavorites;
  final bool onlyWithLiveData;
  final DateRange? season;
}
```

#### 4.2 User Preference Models
```dart
// #todo: Create UserPreferences model
class UserPreferences {
  final String preferredUnits; // 'metric' or 'imperial'
  final bool showDifficulty;
  final bool autoRefreshData;
  final int refreshInterval; // minutes
}
```

## 🔧 **Implementation Steps**

### **Step 1: Update LiveWaterDataService**
```dart
// Before
static Future<Map<String, dynamic>?> fetchStationData(String stationId) {
  // Returns raw Map
}

// After  
static Future<ApiResponse<LiveWaterData>> fetchStationData(String stationId) {
  try {
    final rawData = await _fetchFromCsvDataMart(stationId);
    if (rawData != null) {
      final liveData = LiveWaterData.fromApiResponse(stationId, rawData, 'csv');
      return ApiResponse.success(liveData);
    }
    return ApiResponse.error('No data available');
  } catch (e) {
    return ApiResponse.error(e.toString());
  }
}
```

### **Step 2: Update Cache Implementation**
```dart
// Before
Map<String, Map<String, dynamic>> _liveDataCache = {};

// After
Map<String, CacheResult<LiveWaterData>> _liveDataCache = {};

// Usage
final cacheResult = _liveDataCache[stationId];
if (cacheResult?.isValid == true) {
  return cacheResult!.data!.flowRate;
}
```

### **Step 3: Update UI Components**
```dart
// Before
Widget _buildFlowRate(Map<String, dynamic>? liveData) {
  final flowRate = liveData?['flowRate'] as double?;
  return Text(flowRate?.toString() ?? 'N/A');
}

// After  
Widget _buildFlowRate(LiveWaterData? liveData) {
  return Text(liveData?.formattedFlowRate ?? 'N/A');
}
```

## 📋 **Migration Checklist**

### **Core Models**
- [x] Create `LiveWaterData` model
- [x] Create `FlowCondition` model  
- [x] Create `ApiResponse<T>` wrapper
- [x] Create `CacheResult<T>` wrapper
- [ ] Create `SearchQuery` model
- [ ] Create `UserPreferences` model

### **Service Layer**
- [ ] Update `LiveWaterDataService.fetchStationData()`
- [ ] Update `GaugeStationService.updateStationLiveData()`
- [ ] Update `RiverRunService` query methods
- [ ] Update `UserFavoritesService` operations
- [ ] Add error handling with `ApiResponse<T>`

### **Provider Layer**  
- [ ] Update `RiverRunProvider` to use typed models
- [ ] Update `FavoritesProvider` operations
- [ ] Create `CacheProvider` with typed methods
- [ ] Update state management to use typed data

### **UI Layer**
- [ ] Update `RiverLevelsScreen` cache usage
- [ ] Update `RiverRunSearchScreen` filters
- [ ] Update all widgets using live data
- [ ] Add proper error handling UI

## 🚀 **Expected Benefits**

### **Immediate Benefits**
- **Type Safety**: Compile-time error checking
- **IDE Support**: Auto-completion and refactoring
- **Code Clarity**: Clear data structure definitions
- **Error Reduction**: Fewer runtime type errors

### **Long-term Benefits**  
- **Maintainability**: Easy to modify data structures
- **Performance**: Better memory usage and caching
- **Testing**: Easier to write unit tests
- **Documentation**: Self-documenting code

### **Performance Improvements**
- **Faster JSON Parsing**: Direct object creation
- **Better Caching**: Type-safe cache operations  
- **Reduced Memory**: No duplicate Map objects
- **Fewer Allocations**: Object reuse opportunities

## 📊 **Migration Timeline**

- **Week 1**: Core models and basic service updates
- **Week 2**: Complete service layer migration  
- **Week 3**: UI layer updates and testing
- **Week 4**: Advanced features and optimization

## 🧪 **Testing Strategy**

1. **Unit Tests**: Test model serialization/deserialization
2. **Integration Tests**: Test service layer with typed models
3. **UI Tests**: Verify proper data display
4. **Performance Tests**: Measure improvement metrics