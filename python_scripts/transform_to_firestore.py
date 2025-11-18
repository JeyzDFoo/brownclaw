#!/usr/bin/env python3
"""
Transform BC Whitewater scraped data into BrownClaw Firestore format.
Generates three JSON files ready for Firestore upload:
- rivers.json: Unique river entities
- river_runs.json: River sections/runs
- gauge_stations.json: Water monitoring stations
"""

import json
import os
import re
from typing import Dict, List, Set, Optional
from collections import defaultdict
from datetime import datetime

# Input/output paths
INPUT_DIR = 'run_data/detailed_runs'
OUTPUT_DIR = 'run_data/firestore_import'

def normalize_river_id(river_name: str) -> str:
    """Convert river name to Firestore document ID."""
    # Convert to lowercase, replace spaces/special chars with dashes
    name = river_name.lower().strip()
    name = re.sub(r'[^a-z0-9]+', '-', name)
    name = re.sub(r'-+', '-', name)  # Remove duplicate dashes
    return name.strip('-')

def extract_difficulty_class(difficulty: Dict) -> str:
    """Ensure difficulty has 'Class' prefix."""
    text = difficulty.get('text', 'Unknown')
    
    # Already has Class prefix
    if text.upper().startswith('CLASS'):
        return text
    
    # Has roman numerals or numbers - add Class prefix
    if re.match(r'^[IV\d]', text):
        return f'Class {text}'
    
    return text

def extract_hazards(scouting_text: Optional[str]) -> List[str]:
    """Extract hazards from scouting/portaging description."""
    if not scouting_text:
        return []
    
    hazards = []
    text_lower = scouting_text.lower()
    
    # Common hazard keywords
    if 'portage' in text_lower:
        hazards.append('Portage required')
    if 'waterfall' in text_lower:
        hazards.append('Waterfall')
    if 'canyon' in text_lower and ('unrunnable' in text_lower or 'mandatory' in text_lower):
        hazards.append('Unrunnable canyon')
    if 'wood' in text_lower or 'log' in text_lower:
        hazards.append('Wood hazards')
    if 'sieve' in text_lower:
        hazards.append('Sieves')
    if 'undercut' in text_lower:
        hazards.append('Undercuts')
    
    return hazards[:5]  # Limit to 5 most important

def extract_put_in_take_out(shuttle_desc: Optional[str]) -> tuple[Optional[str], Optional[str]]:
    """Extract put-in and take-out from shuttle description."""
    if not shuttle_desc:
        return None, None
    
    put_in = None
    take_out = None
    
    # Look for put-in mentions
    putin_match = re.search(r'(?:put[\s-]?in|start)[:\s]+([^.]+)', shuttle_desc, re.IGNORECASE)
    if putin_match:
        put_in = putin_match.group(1).strip()[:200]
    
    # Look for take-out mentions
    takeout_match = re.search(r'(?:take[\s-]?out|end)[:\s]+([^.]+)', shuttle_desc, re.IGNORECASE)
    if takeout_match:
        take_out = takeout_match.group(1).strip()[:200]
    
    return put_in, take_out

def transform_to_river(run_data: Dict) -> Dict:
    """Transform BC Whitewater run to River entity."""
    river_name = run_data.get('river_name', run_data.get('title', 'Unknown River'))
    
    # Combine descriptions
    descriptions = []
    if run_data.get('whats_it_like'):
        descriptions.append(run_data['whats_it_like'])
    if run_data.get('flows_description'):
        # Truncate flows description for river-level overview
        descriptions.append(run_data['flows_description'][:500])
    
    description = ' '.join(descriptions) if descriptions else None
    
    return {
        'id': normalize_river_id(river_name),
        'name': river_name,
        'region': run_data.get('province', 'British Columbia'),
        'country': run_data.get('country', 'Canada'),
        'description': description,
        'source': 'bcwhitewater.org',
        'sourceUrl': run_data.get('url'),
        'createdAt': run_data.get('last_updated'),
        'updatedAt': run_data.get('last_updated'),
    }

def transform_to_river_run(run_data: Dict) -> Dict:
    """Transform BC Whitewater run to RiverRun entity."""
    river_name = run_data.get('river_name', run_data.get('title', 'Unknown River'))
    river_id = normalize_river_id(river_name)
    
    # Determine section name
    section_name = run_data.get('section_name')
    if not section_name:
        # No section - use full title or "Main Run"
        section_name = run_data.get('title', 'Main Run')
    
    # Combine descriptions for full context
    descriptions = []
    if run_data.get('whats_it_like'):
        descriptions.append(f"Overview: {run_data['whats_it_like']}")
    if run_data.get('flows_description'):
        descriptions.append(f"\n\nFlows: {run_data['flows_description']}")
    if run_data.get('shuttle_description'):
        descriptions.append(f"\n\nShuttle: {run_data['shuttle_description']}")
    if run_data.get('on_the_water_description'):
        descriptions.append(f"\n\nOn the Water: {run_data['on_the_water_description']}")
    
    description = ''.join(descriptions) if descriptions else None
    
    # Extract difficulty
    difficulty_data = run_data.get('difficulty', {})
    difficulty_class = extract_difficulty_class(difficulty_data)
    
    # Extract flow range
    flow_range = run_data.get('flow_range', {})
    min_flow = flow_range.get('min')
    max_flow = flow_range.get('max')
    flow_unit = flow_range.get('unit', 'cms')
    
    # Extract length
    length_data = run_data.get('length')
    length = length_data.get('km') if length_data else None
    
    # Extract time
    time_data = run_data.get('time', {})
    # Store as metadata string for now
    time_str = time_data.get('original') if time_data else None
    
    # Extract hazards
    hazards = extract_hazards(run_data.get('scouting_portaging'))
    
    # Extract put-in/take-out
    put_in, take_out = extract_put_in_take_out(run_data.get('shuttle_description'))
    
    # Primary gauge station
    gauge_stations = run_data.get('gauge_stations', [])
    station_id = gauge_stations[0]['station_id'] if gauge_stations else None
    
    # Coordinates
    coords = run_data.get('coordinates', {})
    
    run = {
        'id': run_data.get('id'),
        'riverId': river_id,
        'name': section_name,
        'difficultyClass': difficulty_class,
        'description': description,
        'source': 'bcwhitewater.org',
        'sourceUrl': run_data.get('url'),
        'createdBy': 'bcwhitewater-import',
        'createdAt': run_data.get('last_updated'),
        'updatedAt': run_data.get('last_updated'),
    }
    
    # Optional fields
    if length:
        run['length'] = length
    if put_in:
        run['putIn'] = put_in
    if take_out:
        run['takeOut'] = take_out
    if run_data.get('when_to_go'):
        run['season'] = run_data['when_to_go']
    if run_data.get('scouting_portaging'):
        run['permits'] = run_data['scouting_portaging']  # May contain permit info
    if hazards:
        run['hazards'] = hazards
    if min_flow:
        run['minRecommendedFlow'] = min_flow
    if max_flow:
        run['maxRecommendedFlow'] = max_flow
    if flow_unit:
        run['flowUnit'] = flow_unit
    if station_id:
        run['stationId'] = station_id
    if time_str:
        run['estimatedTime'] = time_str
    if coords.get('latitude'):
        run['coordinates'] = {
            'latitude': coords['latitude'],
            'longitude': coords['longitude']
        }
    
    # Store difficulty range for querying
    if isinstance(difficulty_data, dict):
        if 'min' in difficulty_data:
            run['difficultyMin'] = difficulty_data['min']
        if 'max' in difficulty_data:
            run['difficultyMax'] = difficulty_data['max']
    
    return run

def transform_to_gauge_station(run_data: Dict) -> List[Dict]:
    """Transform BC Whitewater gauge stations to BrownClaw GaugeStation entities."""
    gauge_stations = run_data.get('gauge_stations', [])
    run_id = run_data.get('id')
    
    # Get coordinates from run if available
    coords = run_data.get('coordinates', {})
    latitude = coords.get('latitude', 0.0)  # Default to 0.0 if missing (will need manual update)
    longitude = coords.get('longitude', 0.0)
    
    stations = []
    for station in gauge_stations:
        station_id = station.get('station_id')
        if not station_id:
            continue
        
        # Clean up station name (remove station ID if it's duplicated)
        name = station.get('name', f'Station {station_id}')
        name = re.sub(rf'\s*\({station_id}\)\s*$', '', name)
        
        stations.append({
            'stationId': station_id,
            'name': name,
            'riverRunId': run_id,
            'latitude': latitude,
            'longitude': longitude,
            'agency': 'Environment Canada',
            'region': run_data.get('province', 'British Columbia'),
            'country': run_data.get('country', 'Canada'),
            'isActive': True,  # Assume active since scraped from live site
            'parameters': ['discharge', 'water_level'],  # Standard EC measurements
            'dataUrl': station.get('url'),
            'source': 'bcwhitewater.org',
            'createdAt': run_data.get('last_updated'),
            'updatedAt': run_data.get('last_updated'),
        })
    
    return stations

def deduplicate_rivers(rivers: List[Dict]) -> List[Dict]:
    """Deduplicate rivers by ID, keeping the most complete data."""
    river_map = {}
    
    for river in rivers:
        river_id = river['id']
        
        if river_id not in river_map:
            river_map[river_id] = river
        else:
            # Keep the one with more description
            existing = river_map[river_id]
            if river.get('description') and len(river.get('description', '')) > len(existing.get('description', '')):
                river_map[river_id] = river
    
    return list(river_map.values())

def deduplicate_gauge_stations(stations: List[Dict]) -> List[Dict]:
    """Deduplicate stations by ID, merging associatedRiverRunIds."""
    station_map = defaultdict(lambda: {'riverRunIds': set()})
    
    for station in stations:
        station_id = station['stationId']
        
        if station_id not in station_map or not station_map[station_id].get('name'):
            # First time seeing this station or improving data
            station_map[station_id].update(station)
            station_map[station_id]['riverRunIds'] = {station['riverRunId']}
        else:
            # Add this run to the list
            station_map[station_id]['riverRunIds'].add(station['riverRunId'])
    
    # Convert sets to lists
    result = []
    for station_id, data in station_map.items():
        run_ids = list(data.pop('riverRunIds'))
        data['riverRunId'] = run_ids[0]  # Primary run
        data['associatedRiverRunIds'] = run_ids  # All runs
        result.append(data)
    
    return result

def main():
    """Main transformation pipeline."""
    print("BC Whitewater → BrownClaw Firestore Transformation")
    print("=" * 60)
    
    # Load all run data
    run_files = [f for f in os.listdir(INPUT_DIR) if f.endswith('.json')]
    print(f"\nFound {len(run_files)} run files")
    
    all_runs_data = []
    for filename in run_files:
        with open(os.path.join(INPUT_DIR, filename), 'r', encoding='utf-8') as f:
            all_runs_data.append(json.load(f))
    
    # Transform to Firestore entities
    print("\nTransforming data...")
    
    rivers = []
    river_runs = []
    gauge_stations = []
    
    for run_data in all_runs_data:
        try:
            rivers.append(transform_to_river(run_data))
            river_runs.append(transform_to_river_run(run_data))
            gauge_stations.extend(transform_to_gauge_station(run_data))
        except Exception as e:
            print(f"  ❌ Error processing {run_data.get('id', 'unknown')}: {e}")
    
    # Deduplicate
    print("\nDeduplicating...")
    rivers = deduplicate_rivers(rivers)
    gauge_stations = deduplicate_gauge_stations(gauge_stations)
    
    print(f"  Rivers: {len(rivers)} unique")
    print(f"  River Runs: {len(river_runs)}")
    print(f"  Gauge Stations: {len(gauge_stations)} unique")
    
    # Create output directory
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    
    # Save to files
    print("\nSaving transformed data...")
    
    with open(os.path.join(OUTPUT_DIR, 'rivers.json'), 'w', encoding='utf-8') as f:
        json.dump(rivers, f, indent=2, ensure_ascii=False)
    print(f"  ✅ Saved {len(rivers)} rivers to rivers.json")
    
    with open(os.path.join(OUTPUT_DIR, 'river_runs.json'), 'w', encoding='utf-8') as f:
        json.dump(river_runs, f, indent=2, ensure_ascii=False)
    print(f"  ✅ Saved {len(river_runs)} runs to river_runs.json")
    
    with open(os.path.join(OUTPUT_DIR, 'gauge_stations.json'), 'w', encoding='utf-8') as f:
        json.dump(gauge_stations, f, indent=2, ensure_ascii=False)
    print(f"  ✅ Saved {len(gauge_stations)} stations to gauge_stations.json")
    
    # Generate summary statistics
    print("\n" + "=" * 60)
    print("TRANSFORMATION COMPLETE")
    print("=" * 60)
    
    # Difficulty breakdown
    difficulty_counts = defaultdict(int)
    for run in river_runs:
        diff = run.get('difficultyClass', 'Unknown')
        difficulty_counts[diff] += 1
    
    print("\nDifficulty Distribution:")
    for diff, count in sorted(difficulty_counts.items()):
        print(f"  {diff}: {count}")
    
    # Runs with gauge stations
    with_stations = sum(1 for run in river_runs if run.get('stationId'))
    print(f"\nRuns with gauge stations: {with_stations}/{len(river_runs)} ({with_stations/len(river_runs)*100:.1f}%)")
    
    # Runs with flow data
    with_flows = sum(1 for run in river_runs if run.get('minRecommendedFlow'))
    print(f"Runs with flow data: {with_flows}/{len(river_runs)} ({with_flows/len(river_runs)*100:.1f}%)")
    
    # Runs with coordinates
    with_coords = sum(1 for run in river_runs if run.get('coordinates'))
    print(f"Runs with coordinates: {with_coords}/{len(river_runs)} ({with_coords/len(river_runs)*100:.1f}%)")
    
    print(f"\n📁 All files saved to: {OUTPUT_DIR}/")
    print("\nNext steps:")
    print("  1. Review the generated JSON files for issues")
    print("  2. Run upload_to_firestore.py (with --dry-run first)")
    print("  3. Verify data in Firebase Console")
    print("  4. Test in Flutter app")

if __name__ == "__main__":
    main()
