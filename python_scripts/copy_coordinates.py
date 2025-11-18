#!/usr/bin/env python3
"""
Create gauge_stations entries for BC runs using water_stations data.
This matches the existing architecture where weather data fetches from gauge_stations.
"""

import sys
import os

try:
    import firebase_admin
    from firebase_admin import credentials, firestore
except ImportError:
    print("❌ firebase-admin not installed")
    print("Install with: pip install firebase-admin")
    sys.exit(1)

def init_firebase():
    """Initialize Firebase."""
    if not firebase_admin._apps:
        cred_path = 'admin_scripts/service_account_key.json'
        if not os.path.exists(cred_path):
            print(f"❌ Credentials not found at {cred_path}")
            sys.exit(1)
        cred = credentials.Certificate(cred_path)
        firebase_admin.initialize_app(cred)
    return firestore.client()

def main():
    print("📍 Creating gauge_stations entries from water_stations data...")
    print("=" * 60)
    
    db = init_firebase()
    
    # Get all river_runs with stationId
    print("\n1. Fetching river_runs with stationId...")
    runs_ref = db.collection('river_runs')
    runs_with_stations = []
    
    for doc in runs_ref.stream():
        data = doc.to_dict()
        station_id = data.get('stationId')
        
        if station_id:
            runs_with_stations.append({
                'id': doc.id,
                'name': data.get('name'),
                'riverId': data.get('riverId'),
                'stationId': station_id,
            })
    
    print(f"   Found {len(runs_with_stations)} runs with stationId")
    
    # Check existing gauge_stations and group runs by stationId
    print("\n2. Grouping runs by stationId...")
    runs_by_station = {}
    for run in runs_with_stations:
        station_id = run['stationId']
        if station_id not in runs_by_station:
            runs_by_station[station_id] = []
        runs_by_station[station_id].append(run)
    
    print(f"   Found {len(runs_by_station)} unique stations")
    
    # Check which stations already have gauge_stations
    existing_gauge_stations = set()
    for doc in db.collection('gauge_stations').stream():
        data = doc.to_dict()
        if data.get('stationId'):
            existing_gauge_stations.add(data['stationId'])
    
    print(f"   Found {len(existing_gauge_stations)} existing gauge_stations")
    
    # Process each station (one gauge_station per station, with multiple runs)
    print("\n3. Creating gauge_stations entries...")
    created = 0
    skipped = 0
    errors = 0
    
    for station_id, runs in runs_by_station.items():
        # Skip if gauge_station already exists
        if station_id in existing_gauge_stations:
            run_names = [r['name'] for r in runs]
            print(f"  ⏭️  Station {station_id}: gauge_station already exists ({len(runs)} runs)")
            skipped += len(runs)
            continue
        
        # Fetch water_station data
        station_doc = db.collection('water_stations').document(station_id).get()
        
        if not station_doc.exists:
            print(f"  ⚠️  Station {station_id}: water_station not found")
            errors += len(runs)
            continue
        
        station_data = station_doc.to_dict()
        lat = station_data.get('latitude')
        lon = station_data.get('longitude')
        station_name = station_data.get('stationName') or f'Station {station_id}'
        
        if lat is None or lon is None:
            print(f"  ⚠️  Station {station_id}: has no coordinates")
            errors += len(runs)
            continue
        
        # Collect all run IDs for this station
        associated_run_ids = [run['id'] for run in runs]
        
        # Create gauge_station entry with associatedRiverRunIds array
        gauge_station_data = {
            'stationId': station_id,
            'name': station_name,
            'associatedRiverRunIds': associated_run_ids,  # ARRAY of run IDs
            'latitude': lat,
            'longitude': lon,
            'isActive': True,
            'parameters': ['discharge', 'water_level'],
            'agency': 'Environment Canada',
            'region': 'British Columbia',
            'country': 'Canada',
            'createdAt': firestore.SERVER_TIMESTAMP,
            'updatedAt': firestore.SERVER_TIMESTAMP,
        }
        
        # Add to gauge_stations collection
        db.collection('gauge_stations').add(gauge_station_data)
        
        run_names = ', '.join([r['name'] for r in runs])
        print(f"  ✅ Station {station_id}: Created gauge_station for {len(runs)} runs")
        print(f"     Runs: {run_names}")
        print(f"     GPS: ({lat}, {lon})")
        created += 1
    
    # Summary
    print("\n" + "=" * 60)
    print("SUMMARY")
    print("=" * 60)
    print(f"Total runs with stationId: {len(runs_with_stations)}")
    print(f"Unique stations: {len(runs_by_station)}")
    print(f"✅ Gauge stations created: {created}")
    print(f"⏭️  Skipped (already exist): {skipped} runs")
    print(f"⚠️  Errors (station not found or no coords): {errors} runs")
    
    if created > 0:
        print("\n✅ gauge_stations created successfully!")
        print("Multiple runs can now share the same gauge_station.")
        print("Weather and flow data should work for all BC runs.")

if __name__ == "__main__":
    main()
