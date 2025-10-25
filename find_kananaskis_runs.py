#!/usr/bin/env python3
"""Find all Kananaskis river runs in the database"""

import firebase_admin
from firebase_admin import credentials, firestore
import os

# Initialize Firebase Admin SDK
service_account_path = 'admin_scripts/service_account_key.json'
if not os.path.exists(service_account_path):
    service_account_path = 'serviceAccountKey.json'

cred = credentials.Certificate(service_account_path)
firebase_admin.initialize_app(cred)

db = firestore.client()

print("Searching for Kananaskis river runs...")
print("=" * 60)

# Search for river runs containing "kananaskis" (case-insensitive search)
all_runs = db.collection('river_runs').stream()

kananaskis_runs = []
for run in all_runs:
    run_data = run.to_dict()
    name = run_data.get('name', '').lower()
    river = run_data.get('river', '').lower()
    location = run_data.get('location', '').lower()
    
    # Check if any field contains "kananaskis"
    if 'kananaskis' in name or 'kananaskis' in river or 'kananaskis' in location:
        kananaskis_runs.append({
            'id': run.id,
            'name': run_data.get('name'),
            'river': run_data.get('river'),
            'location': run_data.get('location'),
            'hasValidStation': run_data.get('hasValidStation', False),
            'stationId': run_data.get('stationId', 'None'),
        })

if kananaskis_runs:
    print(f"\nFound {len(kananaskis_runs)} Kananaskis river run(s):\n")
    for run in kananaskis_runs:
        print(f"Document ID: {run['id']}")
        print(f"  Name: {run['name']}")
        print(f"  River: {run['river']}")
        print(f"  Location: {run['location']}")
        print(f"  Has Valid Station: {run['hasValidStation']}")
        print(f"  Station ID: {run['stationId']}")
        print()
else:
    print("\n⚠️  No Kananaskis river runs found in the database.")
    print("   Check the Firestore console to verify the river_runs collection.")
