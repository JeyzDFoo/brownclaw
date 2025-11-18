#!/usr/bin/env python3
"""
Check if stationId references in river_runs match actual water_stations.
"""

import sys
import os

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

try:
    import firebase_admin
    from firebase_admin import credentials, firestore
except ImportError:
    print("❌ firebase-admin not installed")
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
    print("🔍 Checking station ID references...")
    print("=" * 60)
    
    db = init_firebase()
    
    # Get all water_stations
    print("\n1. Fetching water_stations collection...")
    stations_ref = db.collection('water_stations')
    stations = {doc.id: doc.to_dict() for doc in stations_ref.stream()}
    print(f"   Found {len(stations)} water stations")
    
    if len(stations) > 0:
        print("\n   Sample station IDs:")
        for i, station_id in enumerate(list(stations.keys())[:5]):
            station = stations[station_id]
            print(f"     - {station_id}: {station.get('stationName', 'Unknown')}")
    
    # Get river_runs with stationId
    print("\n2. Fetching river_runs with stationId...")
    runs_ref = db.collection('river_runs')
    runs_with_stations = []
    
    for doc in runs_ref.stream():
        data = doc.to_dict()
        if data.get('stationId'):
            runs_with_stations.append({
                'id': doc.id,
                'name': data.get('name'),
                'stationId': data.get('stationId'),
                'riverId': data.get('riverId')
            })
    
    print(f"   Found {len(runs_with_stations)} runs with stationId")
    
    # Check matches
    print("\n3. Checking stationId matches...")
    print("=" * 60)
    
    matches = []
    mismatches = []
    
    for run in runs_with_stations:
        station_id = run['stationId']
        if station_id in stations:
            matches.append(run)
            station = stations[station_id]
            print(f"✅ {run['name']}")
            print(f"   Run ID: {run['id']}")
            print(f"   Station: {station_id} - {station.get('stationName', 'Unknown')}")
            print()
        else:
            mismatches.append(run)
            print(f"❌ {run['name']}")
            print(f"   Run ID: {run['id']}")
            print(f"   Station ID: {station_id} (NOT FOUND in water_stations)")
            print()
    
    # Summary
    print("=" * 60)
    print("SUMMARY")
    print("=" * 60)
    print(f"Water stations in database: {len(stations)}")
    print(f"Runs with stationId: {len(runs_with_stations)}")
    print(f"✅ Matching links: {len(matches)}")
    print(f"❌ Missing stations: {len(mismatches)}")
    
    if mismatches:
        print(f"\n⚠️  Missing station IDs:")
        for run in mismatches:
            print(f"  - {run['stationId']}")
        print("\nThese stations need to be added to water_stations collection")
        print("They are Environment Canada stations that don't exist in your database yet")

if __name__ == "__main__":
    main()
