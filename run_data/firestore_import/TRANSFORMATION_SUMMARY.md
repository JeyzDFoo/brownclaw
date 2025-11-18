# BC Whitewater → BrownClaw Transformation Summary

**Date:** November 18, 2025  
**Source:** 190 BC Whitewater river runs  
**Output:** 156 rivers, 190 runs, 23 gauge stations

## Files Generated

- `rivers.json` - 156 unique river entities
- `river_runs.json` - 190 river sections/runs
- `gauge_stations.json` - 23 Environment Canada monitoring stations

## Data Quality Metrics

### Coverage
- **Gauge Stations:** 29/190 runs (15.3%) have associated Environment Canada stations
- **Flow Data:** 40/190 runs (21.1%) have min/max flow recommendations
- **Coordinates:** 10/190 runs (5.3%) have GPS coordinates
- **Descriptions:** 190/190 runs (100%) have detailed descriptions

### Difficulty Distribution
- Class II-III: 21 runs (11%)
- Class III-IV: 43 runs (23%)
- Class IV: 45 runs (24%)
- Class IV-V: 52 runs (27%)
- Class V+: 29 runs (15%)

## Field Mapping

### Rivers Collection
```
BC Whitewater → BrownClaw:
- river_name → name
- province → region
- country → country
- whats_it_like → description (partial)
```

### River Runs Collection
```
BC Whitewater → BrownClaw:
- id → id (unchanged, e.g., "big-creek-lower")
- river_name → riverId (normalized, e.g., "big-creek")
- section_name → name (e.g., "Lower")
- difficulty.text → difficultyClass (with "Class" prefix)
- difficulty.min/max → difficultyMin/Max (for querying)
- flow_range.min/max → minRecommendedFlow/maxRecommendedFlow
- flow_range.unit → flowUnit (default "cms")
- gauge_stations[0].station_id → stationId
- when_to_go → season
- length.km → length
- coordinates → coordinates {latitude, longitude}
- Combined descriptions → description
```

### Gauge Stations Collection
```
BC Whitewater → BrownClaw:
- gauge_stations[].station_id → stationId
- gauge_stations[].name → name (cleaned)
- run.id → riverRunId (primary)
- all associated runs → associatedRiverRunIds (array)
- dataSource: "Environment Canada"
```

## Data Transformations Applied

1. **River ID Normalization**: "Big Creek" → "big-creek"
2. **Difficulty Formatting**: "V" → "Class V"
3. **Hazard Extraction**: Parsed from scouting/portaging descriptions
4. **Description Combination**: Merged flows, shuttle, and on-water descriptions
5. **Station Deduplication**: Multiple runs can share the same gauge station

## Known Issues & Limitations

### Missing Data
- **67 runs** (35%) have no gauge station
- **150 runs** (79%) have no flow recommendations
- **180 runs** (95%) have no GPS coordinates
- Many runs missing: length, gradient, permit requirements

### Data Quality Issues
1. **Put-in/Take-out extraction** - Regex-based, may capture irrelevant text
2. **Inconsistent difficulty formats** - Many variations (see distribution above)
3. **No optimal flow ranges** - BC Whitewater only provides min/max runnable
4. **Section names** - Some runs don't have clear section distinction

### River Deduplication
- 190 runs → 156 unique rivers
- 34 runs share river names (e.g., "Ashlu Creek" has 3 sections)

## Next Steps

### 1. Manual Review (Recommended)
```bash
# Check for duplicate/similar river names
jq '.[].name' run_data/firestore_import/rivers.json | sort | uniq -c | sort -rn | head -20

# Verify runs with missing critical data
jq '.[] | select(.stationId == null) | {id, name, riverId}' run_data/firestore_import/river_runs.json | head -20

# Check difficulty format consistency
jq '.[].difficultyClass' run_data/firestore_import/river_runs.json | sort | uniq -c
```

### 2. Upload to Firestore (DRY RUN FIRST!)
```bash
# Create upload script
python3 python_scripts/upload_to_firestore.py --dry-run

# After review, do actual upload
python3 python_scripts/upload_to_firestore.py --collection rivers
python3 python_scripts/upload_to_firestore.py --collection river_runs
python3 python_scripts/upload_to_firestore.py --collection gauge_stations
```

### 3. Post-Upload Tasks
- [ ] Verify data in Firebase Console
- [ ] Test in Flutter app (favorites, river detail, flow data)
- [ ] Add missing gauge stations manually
- [ ] Validate flow recommendations with community feedback
- [ ] Add coordinates for popular runs

## Security Considerations

- All uploads will have `createdBy: "bcwhitewater-import"`
- Source attribution: `source: "bcwhitewater.org"`
- Firestore rules require admin auth for writes
- Data is licensed from BC Whitewater (community-contributed)

## Maintenance

To re-run transformation after data updates:
```bash
# Re-scrape BC Whitewater
python3 python_scripts/extract_run_details.py

# Re-transform
python3 python_scripts/transform_to_firestore.py

# Compare with existing Firestore data before uploading
```
