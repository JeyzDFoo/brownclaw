# BrownClaw App - Performance Optimization TODO List

## High Priority Optimizations for First Deployment

### 2. Typed Models Implementation 🔧
**Impact: High - Improves type safety, performance, and maintainability**
**PRIORITY: IMPLEMENT FIRST** ⭐

- [x] **Create Core Data Models** 
  - `LiveWaterData` class to replace raw `Map<String, dynamic>` for live data
  - `FlowCondition` class for type-safe flow status handling
  - `ApiResponse<T>` wrapper for consistent API responses
  - `CacheResult<T>` for type-safe cache operations

- [ ] **Update Service Layer**
  - Replace `Map<String, dynamic>` returns with typed models
  - Update `LiveWaterDataService.fetchStationData()` to return `LiveWaterData?`
  - Update `GaugeStationService` to use typed live data objects
  - Add proper error handling with `ApiResponse<T>`

- [ ] **Update UI Layer**
  - Replace raw Map cache with `Map<String, LiveWaterData>`
  - Update river levels screen to use typed data access
  - Remove manual JSON field extraction throughout UI

### 1. Caching Infrastructure 🚀
**Impact: Very High - Reduces Firestore reads by 70-90%**
**PRIORITY: IMPLEMENT AFTER TYPED MODELS** 

- [ ] **Create CacheProvider** (`lib/providers/cache_provider.dart`)
  - Centralized caching for all data types using typed models
  - Separate caches for static data (1 hour TTL) and live data (5 min TTL)
  - Automatic cache invalidation and cleanup
  - Offline support with cached data fallback

- [ ] **Implement Static Data Caching**
  - Cache river runs, stations, and rivers data as typed objects
  - Check cache before Firestore reads
  - Background refresh for expired cache entries

- [ ] **Add Live Data Caching**
  - Cache LiveWaterData objects from API calls
  - Rate limiting to prevent API abuse
  - Smart background updates only for favorite stations

### 3. Firestore Query Optimization 📊
**Impact: High - Reduces read costs and improves load times**

- [ ] **Batch Operations** 
  - Replace individual `getRunById()` calls with batch queries
  - Use `whereIn` queries for multiple favorite runs (max 10 per batch)
  - Implement pagination for large data sets

- [ ] **Lazy Loading**
  - Load basic run info first, then stations on demand
  - Implement infinite scroll for search results
  - Load screen content only when tab is accessed

- [ ] **Query Optimization**
  - Add compound indexes for common query patterns
  - Use Firestore's `limit()` for initial loads
  - Implement proper pagination with cursor-based queries

### 4. State Management Improvements 🔄
**Impact: Medium-High - Better UX and data consistency**

- [ ] **Optimistic Updates**
  - Update favorites UI immediately, sync to Firestore later
  - Rollback on failure with error handling
  - Show pending states for user feedback

- [ ] **Smart Reloading**
  - Only reload data when actually needed
  - Compare data timestamps to avoid unnecessary updates
  - Use stream subscriptions more efficiently

- [ ] **Background Data Sync**
  - Update live data in background without blocking UI
  - Implement retry logic for failed API calls
  - Queue operations for offline sync

### 5. API and Network Optimization 🌐
**Impact: Medium - Reduces external API calls and improves reliability**

- [ ] **API Rate Limiting**
  - Implement minimum interval between API calls per station
  - Cache successful API responses for 5-10 minutes
  - Skip API calls when data is fresh

- [ ] **Connection Monitoring**
  - Detect offline state and adapt behavior
  - Show cached data when offline
  - Queue operations for when connection returns

- [ ] **Error Handling**
  - Graceful fallbacks for API failures
  - Retry logic with exponential backoff
  - User-friendly error messages

### 6. UI/UX Performance 🎨
**Impact: Medium - Improves perceived performance**

- [ ] **Loading States**
  - Skeleton screens for better perceived performance
  - Progressive loading with placeholders
  - Smart refresh indicators

- [ ] **Memory Management**
  - Dispose of unused resources properly
  - Limit cache size with LRU eviction
  - Clear expired data automatically

- [ ] **Responsive Design**
  - Remove artificial width constraints for mobile
  - Implement proper responsive layouts
  - Optimize for different screen sizes

### 7. Production Readiness 🚀
**Impact: High - Essential for deployment**

- [ ] **Remove Debug Code**
  - Remove all debug menu options and test functions
  - Clean up console.log statements
  - Remove development-only features

- [ ] **Add Monitoring**
  - Firebase Performance Monitoring
  - Crashlytics for error reporting
  - Analytics for user behavior insights

- [ ] **Error Boundaries**
  - Wrap screens in error boundaries
  - Graceful error recovery
  - User-friendly error pages

## Implementation Priority

### Phase 1 (Critical - Week 1) - MODELS FIRST ✅
1. **Implement core typed models (LiveWaterData, ApiResponse, FlowCondition)**
2. **Update LiveWaterDataService to return typed objects**
3. **Update RiverLevelsScreen to use typed data**
4. **Test UI with typed models to ensure everything works**
5. Remove debug code and test functions

### Phase 2 (High Priority - Week 2) - CACHING WITH TYPES
1. **Create CacheProvider using typed models from Day 1**
2. Implement Firestore batch operations for favorites
3. Add optimistic updates for favorites
4. Add live data caching with typed objects
5. Implement lazy loading for screens and data

### Phase 3 (Medium Priority - Week 3) - OPTIMIZATION
1. Add offline support with cached typed data
2. Improve loading states and error handling
3. Add production monitoring and analytics
4. Optimize UI performance and memory usage
5. Add comprehensive error boundaries

## Expected Performance Improvements

- **Firestore Reads**: 70-90% reduction
- **API Calls**: 60-80% reduction  
- **Initial Load Time**: 40-60% faster
- **App Responsiveness**: Significantly improved
- **Offline Functionality**: Full cached data access
- **Memory Usage**: 30-50% reduction with proper cleanup
- **Type Safety**: 100% compile-time type checking
- **Code Maintainability**: Significantly improved with typed models

## Key Files to Modify

1. `lib/providers/cache_provider.dart` (new)
2. `lib/models/live_water_data.dart` (new) ✅
3. `lib/models/api_response.dart` (new) ✅
4. `lib/providers/river_run_provider.dart`
5. `lib/providers/favorites_provider.dart`
6. `lib/services/river_run_service.dart`
7. `lib/services/live_water_data_service.dart`
8. `lib/services/user_favorites_service.dart`
9. `lib/services/gauge_station_service.dart`
10. `lib/screens/river_levels_screen.dart`
11. `lib/main.dart`

## Related Documentation

- See `TYPED_MODELS_PLAN.md` for detailed typed models implementation
- Current model classes are well-structured but need broader usage
- Focus on replacing raw `Map<String, dynamic>` usage throughout