# Sprint Plan - BrownClaw App
**Generated:** October 16, 2025  
**Focus:** Performance Optimization, Code Quality, and Production Readiness

---

## 📊 Overview

This sprint plan consolidates all TODO items found in the codebase, organized by priority and technical area. The plan focuses on critical performance issues, type safety improvements, and production readiness.

**Total TODOs Found:** 59 items across services, models, screens, and providers

---

## 🔥 Sprint 1: Critical Performance & Caching (Priority 1)
**Goal:** Reduce app load time from 8-15s to 1-3s  
**Duration:** 1 week

### 1.1 Implement Centralized Caching System
**Files:** 
- `lib/providers/cache_provider.dart` (currently skeleton)
- `lib/providers/providers.dart`

**TODOs:**
- [ ] Implement core cache methods in `CacheProvider`
- [ ] Add cache size limits and LRU eviction strategy
- [ ] Add offline support with cache fallbacks
- [ ] Integrate CacheProvider into main app providers

**Impact:** Foundation for all caching improvements below

---

### 1.2 Add Static Caching to Services
**Files & TODOs:**

#### GaugeStationService (`lib/services/gauge_station_service.dart`)
- [ ] Add static caching for gauge stations to reduce Firestore reads (line 12)
- [ ] Check cache first before making Firestore call (line 44)
- [ ] Cache the result for future use (line 56)
- [ ] Add batch operations for multiple station queries (line 18)

#### FirestoreStationService (`lib/services/firestore_station_service.dart`)
- [ ] Add static caching for station data to reduce Firestore reads (line 99)
- [ ] Check cache first to avoid redundant Firestore reads (line 173)
- [ ] Cache the combined results for future use (line 206)
- [ ] Add pagination support for large station lists (line 105)

#### RiverRunService (`lib/services/river_run_service.dart`)
- [ ] Add static caching to reduce redundant Firestore reads (line 13)
- [ ] Check cache first before making Firestore call (line 44)
- [ ] **CRITICAL:** Optimize expensive method that loads ALL runs (line 537)
- [ ] Replace individual calls with batch operations (line 545)
- [ ] Add connection state monitoring for offline support (line 18)

#### UserFavoritesService (`lib/services/user_favorites_service.dart`)
- [ ] Add local caching to reduce Firestore reads for favorites (line 13)
- [ ] Check cache first to reduce Firestore reads (line 31)
- [ ] Cache the result for future use (line 42)
- [ ] Add offline support for favorites (line 19)
- [ ] Optimize method that makes individual Firestore calls for each run (line 56)
- [ ] Implement optimistic updates - update cache immediately (line 112)
- [ ] Update cache after successful Firestore write (line 120)

**Success Criteria:**
- Cache hit rate > 80% for repeated queries
- Reduce Firestore reads by 70%+
- Load time for favorites screen < 2 seconds

---

### 1.3 Provider-Level Caching
**Files:**
- `lib/providers/river_run_provider.dart`
- `lib/providers/favorites_provider.dart`

**TODOs:**

#### RiverRunProvider
- [ ] Check cache first before making Firestore call (line 50)
- [ ] Cache the loaded data to reduce subsequent Firestore reads (line 61)
- [ ] Optimize live data refresh to avoid redundant Firestore calls (line 156)

#### FavoritesProvider
- [ ] Add local caching for offline favorites access (line 9)
- [ ] Add debouncing for rapid favorite toggles to reduce Firestore writes (line 12)
- [ ] Implement optimistic updates for better UX (line 46)

**Success Criteria:**
- Favorites toggle responds instantly (optimistic updates)
- No duplicate Firestore writes within 1 second

---

## 🎨 Sprint 2: Type Safety & Data Models (Priority 2)
**Goal:** Replace all `Map<String, dynamic>` with typed models  
**Duration:** 1 week

### 2.1 Adopt LiveWaterData Typed Model
**Files:**
- `lib/models/live_water_data.dart` (model exists, needs adoption)
- `lib/services/live_water_data_service.dart`
- `lib/services/gauge_station_service.dart`

**TODOs:**

#### LiveWaterDataService
- [ ] Update `_fetchFromCsvDataMart` to return `LiveWaterData` instead of raw Map (line 142)

#### GaugeStationService
- [ ] Update to use `LiveWaterData` instead of `Map<String, dynamic>` (line 184)
- [ ] Use `LiveWaterData.toMap()` instead of manual field extraction (line 188)

**Additional Implementation:**
- [ ] Replace `_liveDataCache Map<String, dynamic>` usage (model comment)
- [ ] Update cache storage with typed approach (model comment)
- [ ] Replace flow status `Map<String, dynamic>` with `FlowCondition` typed model (model comment)

**Success Criteria:**
- Zero raw Map usage for live water data
- Compile-time type safety for all live data operations
- Better IDE autocomplete and refactoring support

---

### 2.2 Adopt API Response Models
**File:** `lib/models/api_response.dart` (models exist, need adoption)

**TODOs:**
- [ ] Use `ApiResponse<T>` instead of raw JSON parsing throughout app (line 2)
- [ ] Use `FirestoreResult<T>` for consistent Firestore response handling (line 50)
- [ ] Use `UserResult` for authentication and profile operations (line 95)
- [ ] Use `CacheResult` for cache operations instead of raw boolean returns (line 119)

**Target Files for Migration:**
- All services that make API calls
- All Firestore query methods
- All cache operations

**Success Criteria:**
- Standardized error handling across all API calls
- Consistent response format for better testing

---

### 2.3 Additional Model Implementations
**File:** `lib/models/models.dart`

**TODOs:**
- [ ] Add typed live data models export (line 9)
- [ ] Create `SearchQuery` model (from TYPED_MODELS_PLAN.md)
- [ ] Create `FilterCriteria` model (from TYPED_MODELS_PLAN.md)
- [ ] Create `UserPreferences` model (from TYPED_MODELS_PLAN.md)

**Success Criteria:**
- All core data structures have typed models
- No more manual JSON manipulation in business logic

---

## 🏗️ Sprint 3: Architecture & Screen Refactoring (Priority 3)
**Goal:** Clean up screen architecture and data flow  
**Duration:** 1 week

### 3.1 RiverLevelsScreen Major Refactor
**File:** `lib/screens/river_levels_screen.dart`

**TODOs:**
- [ ] **MAJOR REFACTOR:** Move all live data management to LiveWaterDataProvider (line 18)
- [ ] Remove navigation helper method by updating RiverDetailScreen to accept RiverRunWithStations directly (line 96)

**Impact:** This is marked as a major refactor - likely touches multiple components

---

### 3.2 Screen Navigation Updates
**Files:**
- `lib/screens/river_run_search_screen.dart`
- `lib/screens/searchable_stations_screen.dart`

**TODOs:**
- [ ] Update RiverDetailScreen to accept RiverRunWithStations (line 394 of river_run_search_screen.dart)
- [ ] Navigate to detailed station view (line 501 of searchable_stations_screen.dart)

**Success Criteria:**
- Consistent navigation patterns
- Type-safe screen parameters

---

### 3.3 MainScreen Optimizations
**File:** `lib/screens/main_screen.dart`

**TODOs:**
- [ ] Implement lazy loading of screens to improve initial load time (line 21)
- [ ] Remove debug options before production deployment (lines 55, 71)

**Success Criteria:**
- Screens load on-demand, not all at startup
- No debug UI in production builds

---

## 🚀 Sprint 4: Production Readiness (Priority 4)
**Goal:** Prepare app for production deployment  
**Duration:** 1 week

### 4.1 Firebase Production Features
**File:** `lib/main.dart`

**TODOs:**
- [ ] Add Firebase performance monitoring and analytics (line 23)
- [ ] Implement error reporting with Crashlytics (line 24)

**Implementation:**
```yaml
# pubspec.yaml additions needed
dependencies:
  firebase_analytics: ^latest
  firebase_crashlytics: ^latest
  firebase_performance: ^latest
```

---

### 4.2 Provider Architecture
**File:** `lib/main.dart`

**TODOs:**
- [ ] Add caching provider for shared data management (line 42)
- [ ] Consider adding StationProvider for centralized station data (line 43)

**Success Criteria:**
- All shared data managed through providers
- No direct service calls from widgets

---

### 4.3 UI/UX Polish
**File:** `lib/main.dart`

**TODOs:**
- [ ] Remove artificial width constraint for mobile-first design (line 57)

**Success Criteria:**
- App responsive across all device sizes
- Mobile-first approach validated

---

### 4.4 Build Configuration
**Files:**
- `android/app/build.gradle.kts`

**TODOs:**
- [ ] Specify unique Application ID (line 23)
- [ ] Add release build signing config (line 35)

**Success Criteria:**
- Production-ready Android build configuration
- Signed release builds

---

## 📦 Sprint 5: Dependencies & Package Management (Priority 5)
**Goal:** Add optimization packages  
**Duration:** 2-3 days

### 5.1 Add Optimization Packages
**File:** `pubspec.yaml`

**TODOs:**
- [ ] Add optimization packages (line 20)

**Recommended packages from PERFORMANCE_OPTIMIZATION_RECOMMENDATIONS.md:**
```yaml
dependencies:
  cached_network_image: ^3.3.0  # Image caching
  hive: ^2.2.3                   # Fast local storage
  hive_flutter: ^1.1.0
  connectivity_plus: ^5.0.2      # Offline detection
```

---

## 📈 Success Metrics

### Performance Targets
- **App Launch Time:** < 2 seconds (from 8-15s)
- **Favorites Screen Load:** < 2 seconds (from 5-10s)
- **Firestore Reads:** Reduce by 70%
- **Cache Hit Rate:** > 80%
- **API Calls:** Reduce redundant calls by 60%

### Code Quality Targets
- **Type Safety:** Zero raw Map usage for core data
- **Test Coverage:** > 70% (add tests for new cache logic)
- **Code Duplication:** Reduce `_safeToDouble()` duplications
- **Documentation:** All public APIs documented

### Production Readiness
- [ ] Firebase Analytics integrated
- [ ] Crashlytics error reporting active
- [ ] Offline mode functional
- [ ] Debug UI removed
- [ ] Release builds signed

---

## 🎯 Sprint Execution Priority

### Must Have (Sprint 1)
1. **Caching System** - Blocks all other optimizations
2. **Service-Level Caching** - Biggest performance win
3. **Batch Firestore Queries** - Critical for favorites screen

### Should Have (Sprints 2-3)
4. **Type Safety** - Improves maintainability
5. **LiveWaterData Adoption** - Reduces bugs
6. **RiverLevelsScreen Refactor** - Cleans architecture

### Nice to Have (Sprints 4-5)
7. **Production Features** - Firebase monitoring
8. **UI Polish** - Mobile-first design
9. **Build Configuration** - Release readiness

---

## 🚧 Implementation Notes

### High-Risk Changes
- **RiverLevelsScreen refactor** (marked as MAJOR) - needs careful planning
- **LiveWaterData migration** - touches many files
- **Batch query implementation** - changes data flow

### Quick Wins
- Debug UI removal (2 TODOs, 5 minutes)
- Width constraint removal (1 TODO, 5 minutes)
- Optimistic updates (improves perceived performance)

### Dependencies Between Tasks
1. CacheProvider must be implemented first
2. Type models should be adopted before major refactors
3. Service caching before provider caching
4. Architecture refactor before production features

---

## 📝 Additional Observations

### Code Duplication Issues
Multiple files have duplicate `_safeToDouble()` helper:
- `lib/models/river_station.dart`
- `lib/models/gauge_station.dart`
- `lib/models/river_run.dart`
- `lib/models/river_descent.dart`
- `lib/models/live_water_data.dart`
- `lib/services/favorite_rivers_service.dart`

**Recommendation:** Create shared utility in `lib/utils/type_converters.dart`

### Generated Code (Not TODOs)
These are Flutter/Gradle generated and can be ignored:
- `windows/flutter/CMakeLists.txt` - Flutter framework TODO
- Various `toDouble()` calls - normal Dart conversion

---

## 🎬 Getting Started

### Week 1 (Sprint 1) - Recommended First Steps:
1. ✅ Create `lib/utils/type_converters.dart` with shared helpers
2. ✅ Implement core `CacheProvider` methods
3. ✅ Add caching to `GaugeStationService` (smallest service)
4. ✅ Test and validate caching works
5. ✅ Roll out to other services

### Validation at Each Step:
- Run existing tests: `flutter test`
- Check performance with Flutter DevTools
- Measure Firestore reads in Firebase Console
- Profile app launch time

---

## 📊 Tracking Progress

Consider creating GitHub issues/tasks for each TODO category:
- **Issue #1:** Implement CacheProvider (Sprint 1.1)
- **Issue #2:** Service Layer Caching (Sprint 1.2)
- **Issue #3:** Provider Caching (Sprint 1.3)
- **Issue #4:** LiveWaterData Migration (Sprint 2.1)
- **Issue #5:** RiverLevelsScreen Refactor (Sprint 3.1)
- **Issue #6:** Production Features (Sprint 4)

Use labels: `performance`, `type-safety`, `architecture`, `production-ready`

---

**Total Estimated Development Time:** 4-5 weeks  
**Priority Areas:** Caching (50%), Type Safety (25%), Architecture (15%), Production (10%)
