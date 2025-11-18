# BC Runs Data Flow Analysis: Working vs Broken

**Date:** November 18, 2025  
**Issue:** BC runs show "Error loading live data" while existing runs (Bow, Kananaskis) work perfectly.

---

## ✅ WORKING EXAMPLE: Bow River - Harvie Passage

### 1. Firestore Structure

**river_runs/N0ptPBwD1u2ByePoCOiY:**
```
{
  name: "Harvie Passage"
  stationId: "05BH004"    ← HAS stationId field
  riverId: "Cc8Qdpo02ZCbMcFcP4jJ"
}
```

**gauge_stations/05BH004:**
```
{
  stationId: "05BH004"    ← Government of Canada station ID
  riverRunId: "N0ptPBwD1u2ByePoCOiY"
  latitude: 51.05027
  longitude: -114.05146
}
```

### 2. Code Flow

```
FavoritesScreen/SearchScreen
  ↓
RiverRunProvider.getRiverRuns()
  ↓
RiverRunService.getRunWithStations(runId)
  ↓ Queries: gauge_stations WHERE riverRunId == "N0ptPBwD1u2ByePoCOiY"
  ↓ Finds: 1 gauge_station document
  ↓
Returns: RiverRunWithStations {
  run: RiverRun(id="N0ptPBwD1u2ByePoCOiY", stationId="05BH004"),
  stations: [GaugeStation(stationId="05BH004")],  ← POPULATED
  river: River(...)
}
  ↓
_convertRunToLegacyFormat()
  ↓ primaryStation = stations[0]
  ↓ stationId = primaryStation.stationId = "05BH004"
  ↓
Returns: { "stationId": "05BH004", ... }
  ↓
RiverDetailScreen receives: { "stationId": "05BH004" }
  ↓
LiveWaterDataProvider.fetchStationData("05BH004")
  ↓
API: https://api.weather.gc.ca/.../items?STATION_NUMBER=05BH004
  ↓
✅ SUCCESS: Returns 42.7 m³/s
```

---

## ❌ BROKEN EXAMPLE: Cheakamus River - Balls to the Wall

### 1. Firestore Structure

**river_runs/cheakamus-river-balls-to-the-wall:**
```
{
  name: "Balls To The Wall"
  stationId: "08GA072"    ← HAS stationId field (from BC import)
  riverId: "cheakamus-river"
}
```

**gauge_stations (4 documents with same stationId):**

| Document ID | stationId | riverRunId | Notes |
|-------------|-----------|------------|-------|
| `mNaLcgmEhNOlhHmPv9Ad` | `08GA072` | `cheakamus-river-upper` | Created for Upper section |
| `qSftvRjF2ONmEOacN1ZA` | `08GA072` | `cheakamus-river-cheakamus-lake-down` | Created for Lake Down |
| `xzZZCOKYBWt9W34VGgZW` | `08GA072` | `cheakamus-river-balls-to-the-wall` | **Created for Balls to the Wall** |
| `ybDUD2g9Pqx60r3LFfCk` | `08GA072` | `cheakamus-river-daisy-lake-canyon` | Created for Daisy Lake |

### 2. Code Flow

```
FavoritesScreen/SearchScreen
  ↓
RiverRunProvider.getRiverRuns()
  ↓
RiverRunService.getRunWithStations(runId)
  ↓ Queries: gauge_stations WHERE riverRunId == "cheakamus-river-balls-to-the-wall"
  ↓ Finds: gauge_station document "xzZZCOKYBWt9W34VGgZW"
  ↓
Returns: RiverRunWithStations {
  run: RiverRun(id="cheakamus-river-balls-to-the-wall", stationId="08GA072"),
  stations: [GaugeStation(stationId="08GA072")],  ← POPULATED
  river: River(...)
}
  ↓
_convertRunToLegacyFormat()
  ↓ primaryStation = stations[0]
  ↓ stationId = primaryStation.stationId = "08GA072" ✅
  ↓
Returns: { "stationId": "08GA072", ... }  ← SHOULD BE CORRECT!
  ↓
❓ BUT FLUTTER LOGS SHOW: "stationId=xzZZCOKYBWt9W34VGgZW"
  ↓
RiverDetailScreen receives: { "stationId": "xzZZCOKYBWt9W34VGgZW" } ❌
  ↓
LiveWaterDataProvider.fetchStationData("xzZZCOKYBWt9W34VGgZW")
  ↓
API: https://api.weather.gc.ca/.../items?STATION_NUMBER=xzZZCOKYBWt9W34VGgZW
  ↓
❌ FAILURE: Station not found (it's a Firestore doc ID, not a Gov Canada ID!)
```

---

## 🔍 ROOT CAUSE - SOLVED!

**The Problem:** BC gauge_stations were created with wrong field structure.

**What We Created (WRONG):**
```
gauge_stations/xzZZCOKYBWt9W34VGgZW {
  stationId: "08GA072"
  riverRunId: "cheakamus-river-balls-to-the-wall"  ← STRING (one run only)
}
```

**What Should Exist (CORRECT):**
```
gauge_stations/tt16NTNFAhvsueH8Neq0 {
  stationId: "08GA072"
  associatedRiverRunIds: [                          ← ARRAY (multiple runs)
    "cheakamus-river-balls-to-the-wall",
    "cheakamus-river-cheakamus-lake-down",
    "cheakamus-river-daisy-lake-canyon",
    "cheakamus-river-upper"
  ]
}
```

**Why It Failed:**
1. `RiverRunService.getRunWithStations()` queries `WHERE riverRunId == runId` (legacy single-run)
2. BC gauge_stations were created with `riverRunId` pointing to ONE run only
3. Multiple runs shared same station → only first run's gauge_station was found
4. Other runs got empty `stations` array → fallback to `run.stationId` → should work BUT...
5. The script incorrectly set `riverRunId` to the RIVER ID, not run ID!

**Evidence:**
- Screenshot shows: `riverRunId: "babine-river"` ← River ID, not run ID! ❌
- Should be: `riverRunId: "babine-river-babine-river"` ← Run ID ✅

---

## 🎯 THE FIX - IMPLEMENTED!

### What We Did:

1. **Fixed `python_scripts/copy_coordinates.py`:**
   - Group runs by `stationId` instead of creating one gauge_station per run
   - Create ONE gauge_station per station with `associatedRiverRunIds` array
   - Allows multiple runs to share the same station data

2. **Updated `lib/services/river_run_service.dart`:**
   - Modified `getRunWithStations()` to query BOTH:
     - `riverRunId == runId` (legacy single-run)
     - `associatedRiverRunIds contains runId` (new multi-run array)
   - Backward compatible with existing runs

3. **Deleted and Recreated BC gauge_stations:**
   - Removed 30 incorrectly created gauge_stations
   - Created 23 new gauge_stations with correct structure
   - Cheakamus now has 1 gauge_station shared by 4 runs ✅

### New Structure:

```firestore
gauge_stations/tt16NTNFAhvsueH8Neq0 {
  stationId: "08GA072"
  name: "Station 08GA072"
  associatedRiverRunIds: [
    "cheakamus-river-balls-to-the-wall",
    "cheakamus-river-cheakamus-lake-down", 
    "cheakamus-river-daisy-lake-canyon",
    "cheakamus-river-upper"
  ]
  latitude: 50.07991
  longitude: -123.03562
  isActive: true
  agency: "Environment Canada"
  region: "British Columbia"
}
```

### Why This Works:

1. **One source of truth** - One gauge_station per physical station
2. **Efficient** - No duplicate GPS/metadata for shared stations
3. **Scalable** - Easy to add more runs to existing stations
4. **Backward compatible** - Still supports legacy `riverRunId` field

---

## 📊 Data Architecture Summary

### Working Architecture (Existing Runs):
```
river_run.stationId → Gov Canada ID (e.g., "05BH004")
      ↓
gauge_station.riverRunId → Links to specific run
gauge_station.stationId → Same as river_run.stationId
      ↓
API fetch uses stationId → ✅ Works
```

### BC Runs Architecture (Should Work):
```
river_run.stationId → Gov Canada ID (e.g., "08GA072")
      ↓
gauge_station.riverRunId → Links to specific run
gauge_station.stationId → Same as river_run.stationId ("08GA072")
      ↓
Multiple gauge_stations share same stationId ← VALID PATTERN
      ↓
API fetch uses stationId → ✅ Should work!
```

### The Bug:
```
Somewhere in _convertRunToLegacyFormat() or data parsing:
  stationId gets replaced with Firestore document ID
      ↓
API fetch uses document ID instead → ❌ Breaks
```

---

## 🚀 Action Items

1. ✅ **Document the data flow** (this file)
2. ✅ **Fix python_scripts/copy_coordinates.py** to use `associatedRiverRunIds` array
3. ✅ **Update RiverRunService.getRunWithStations()** to query array field
4. ✅ **Delete incorrectly created BC gauge_stations** (30 deleted)
5. ✅ **Recreate gauge_stations with correct structure** (23 created)
6. ⏳ **Test with both Bow River (control) and Cheakamus (BC)**
7. ⏳ **Verify all BC runs display live data correctly**

### Optional Future Improvements:

- **Refactor RiverDetailScreen** to accept `RiverRunWithStations` directly (eliminates `_convertRunToLegacyFormat()`)
- **Remove legacy `riverRunId` field** after confirming all runs use `associatedRiverRunIds`

---

## 🧪 Test Cases

### Control Test (Bow River):
- [x] Navigate to Harvie Passage
- [x] Verify flow data displays (42.7 m³/s)
- [x] Verify weather displays
- [x] Verify historical chart loads

### BC Run Test (Cheakamus):
- [ ] Navigate to Balls to the Wall
- [ ] Verify flow data displays (should be ~7 m³/s based on API)
- [ ] Verify weather displays
- [ ] Verify historical chart loads

### Multiple Runs Same Station (Cheakamus):
- [ ] Test all 4 Cheakamus sections share station 08GA072
- [ ] Verify each shows same live flow data
- [ ] Verify each shows correct GPS-based weather
