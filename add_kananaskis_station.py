#!/usr/bin/env python3
"""
Script to add TransAlta gauge station for Kananaskis River
This creates a special station entry for TransAlta data source
"""

import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime
import os

# Initialize Firebase Admin SDK
# Try admin_scripts directory first, then current directory
service_account_path = 'admin_scripts/service_account_key.json'
if not os.path.exists(service_account_path):
    service_account_path = 'serviceAccountKey.json'

cred = credentials.Certificate(service_account_path)
firebase_admin.initialize_app(cred)

db = firestore.client()

def add_kananaskis_station():
    """Add TransAlta station for Kananaskis River"""
    
    # TransAlta Barrier Dam coordinates (Widowmaker put-in)
    station_data = {
        'stationId': 'TRANSALTA_BARRIER',  # Special ID for TransAlta data
        'name': 'TransAlta Barrier Dam',
        'latitude': 51.05472703268625,
        'longitude': -115.01728354587776,
        'isActive': True,
        'parameters': ['Flow'],  # TransAlta provides flow data
        'dataSource': 'TransAlta',  # Mark as TransAlta source (not Gov of Canada)
        'region': 'Kananaskis',
        'addedAt': firestore.SERVER_TIMESTAMP,
    }
    
    # Add the station to gauge_stations collection
    station_ref = db.collection('gauge_stations').document('TRANSALTA_BARRIER')
    station_ref.set(station_data)
    print(f"✅ Added TransAlta Barrier Dam station: {station_data['stationId']}")
    
    # Now update the Kananaskis river run to reference this station
    # Find Kananaskis river run (Upper Kan)
    river_runs = db.collection('river_runs').where('name', '==', 'Upper Kan').stream()
    
    updated_count = 0
    for run in river_runs:
        run_data = run.to_dict()
        print(f"\nFound river run: {run.id} - {run_data.get('name')}")
        
        # Update to include the TransAlta station
        update_data = {
            'stationId': 'TRANSALTA_BARRIER',
            'hasValidStation': True,
            'updatedAt': firestore.SERVER_TIMESTAMP,
        }
        
        db.collection('river_runs').document(run.id).update(update_data)
        print(f"✅ Updated {run.id} with TransAlta station reference")
        updated_count += 1
    
    if updated_count == 0:
        print("\n⚠️  No Kananaskis river runs found. You may need to update manually.")
        print("   Check the river_runs collection for the correct document ID.")
    else:
        print(f"\n✅ Successfully updated {updated_count} river run(s)")

if __name__ == '__main__':
    print("Adding TransAlta Barrier Dam station for Kananaskis River...")
    print("=" * 60)
    
    try:
        add_kananaskis_station()
        print("\n" + "=" * 60)
        print("✅ Script completed successfully!")
        print("\nThe Kananaskis river should now show as having live data available.")
    except Exception as e:
        print(f"\n❌ Error: {e}")
        print("\nMake sure:")
        print("1. serviceAccountKey.json exists in the current directory")
        print("2. You have Firebase Admin permissions")
        print("3. The Firestore database is accessible")
