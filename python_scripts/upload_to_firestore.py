#!/usr/bin/env python3
"""
Upload transformed BC Whitewater data to Firestore.
REQUIRES: Firebase Admin SDK credentials

Setup:
    pip install firebase-admin
    
Usage:
    # Dry run (no writes)
    python3 upload_to_firestore.py --dry-run
    
    # Upload specific collection
    python3 upload_to_firestore.py --collection rivers
    python3 upload_to_firestore.py --collection river_runs
    
    # Upload all
    python3 upload_to_firestore.py --all
"""

import json
import os
import sys
import argparse
from datetime import datetime
from typing import List, Dict

try:
    import firebase_admin
    from firebase_admin import credentials, firestore
except ImportError:
    print("❌ Error: firebase-admin not installed")
    print("Install with: pip install firebase-admin")
    sys.exit(1)

# Paths
INPUT_DIR = 'run_data/firestore_import'
RIVERS_FILE = os.path.join(INPUT_DIR, 'rivers.json')
RIVER_RUNS_FILE = os.path.join(INPUT_DIR, 'river_runs.json')

# Firebase service account key path (try multiple locations)
SERVICE_ACCOUNT_KEY_PATHS = [
    'admin_scripts/service_account_key.json',  # Primary location
    'serviceAccountKey.json',  # Alternative
    os.path.expanduser('~/brownclaw-firebase-key.json'),  # User home
]

def init_firebase():
    """Initialize Firebase Admin SDK."""
    # Try to find service account key
    service_account_key = None
    for path in SERVICE_ACCOUNT_KEY_PATHS:
        if os.path.exists(path):
            service_account_key = path
            print(f"✅ Found credentials at: {path}")
            break
    
    if not service_account_key:
        print(f"❌ Error: Firebase service account key not found")
        print("Tried locations:")
        for path in SERVICE_ACCOUNT_KEY_PATHS:
            print(f"  - {path}")
        print("\nDownload it from Firebase Console: Project Settings > Service Accounts")
        sys.exit(1)
    
    if not firebase_admin._apps:
        cred = credentials.Certificate(service_account_key)
        firebase_admin.initialize_app(cred)
    
    return firestore.client()

def convert_timestamps(data: Dict) -> Dict:
    """Convert ISO timestamp strings to Firestore Timestamps."""
    result = data.copy()
    
    for key in ['createdAt', 'updatedAt']:
        if key in result and isinstance(result[key], str):
            try:
                dt = datetime.fromisoformat(result[key].replace('Z', '+00:00'))
                result[key] = dt
            except:
                del result[key]  # Remove invalid timestamps
    
    return result

def upload_collection(db, collection_name: str, data: List[Dict], dry_run: bool = True):
    """Upload data to a Firestore collection."""
    print(f"\n{'[DRY RUN] ' if dry_run else ''}Uploading to {collection_name}...")
    print("=" * 60)
    
    if dry_run:
        print(f"Would upload {len(data)} documents")
        print("\nSample document:")
        print(json.dumps(data[0], indent=2)[:500] + "...")
        return
    
    # Batch upload (Firestore limit: 500 operations per batch)
    batch = db.batch()
    batch_count = 0
    total_uploaded = 0
    skipped = 0
    
    for item in data:
        doc_id = item.get('id')
        if not doc_id:
            print(f"  ⚠️  Skipping item without ID: {item.get('name', 'unknown')}")
            skipped += 1
            continue
        
        # Check if document exists
        doc_ref = db.collection(collection_name).document(doc_id)
        doc = doc_ref.get()
        
        if doc.exists:
            print(f"  ⏭️  Skipping existing: {doc_id}")
            skipped += 1
            continue
        
        # Convert timestamps
        item_data = convert_timestamps(item)
        # Remove 'id' field (it's the document ID)
        item_data.pop('id', None)
        
        batch.set(doc_ref, item_data)
        batch_count += 1
        total_uploaded += 1
        
        # Commit batch every 500 operations
        if batch_count >= 500:
            batch.commit()
            print(f"  ✅ Committed batch of {batch_count} documents")
            batch = db.batch()
            batch_count = 0
    
    # Commit remaining
    if batch_count > 0:
        batch.commit()
        print(f"  ✅ Committed final batch of {batch_count} documents")
    
    print(f"\n📊 Upload Summary for {collection_name}:")
    print(f"  ✅ Uploaded: {total_uploaded}")
    print(f"  ⏭️  Skipped (existing): {skipped}")
    print(f"  📦 Total: {len(data)}")

def validate_data(data: List[Dict], collection_name: str) -> bool:
    """Validate data before upload."""
    print(f"\nValidating {collection_name} data...")
    
    if not data:
        print(f"  ❌ No data to upload")
        return False
    
    # Check all have IDs
    missing_ids = [item.get('name', 'unknown') for item in data if not item.get('id')]
    if missing_ids:
        print(f"  ❌ {len(missing_ids)} items missing IDs: {missing_ids[:5]}")
        return False
    
    # Check for required fields based on collection
    if collection_name == 'rivers':
        required = ['name', 'region', 'country']
    elif collection_name == 'river_runs':
        required = ['riverId', 'name', 'difficultyClass']
    else:
        required = []
    
    for field in required:
        missing = [item['id'] for item in data if not item.get(field)]
        if missing:
            print(f"  ❌ {len(missing)} items missing required field '{field}': {missing[:5]}")
            return False
    
    print(f"  ✅ Validation passed: {len(data)} valid documents")
    return True

def main():
    parser = argparse.ArgumentParser(description='Upload BC Whitewater data to Firestore')
    parser.add_argument('--dry-run', action='store_true', help='Preview without uploading')
    parser.add_argument('--collection', choices=['rivers', 'river_runs'], help='Upload specific collection')
    parser.add_argument('--all', action='store_true', help='Upload all collections')
    
    args = parser.parse_args()
    
    # Default to dry-run if no action specified
    if not args.collection and not args.all:
        args.dry_run = True
        args.all = True
    
    print("🔥 BC Whitewater → Firestore Upload Tool")
    print("=" * 60)
    
    if args.dry_run:
        print("⚠️  DRY RUN MODE - No data will be written")
    else:
        print("⚠️  LIVE MODE - Data will be written to Firestore!")
        response = input("\nAre you sure you want to proceed? (yes/no): ")
        if response.lower() != 'yes':
            print("Upload cancelled.")
            return
    
    # Initialize Firebase
    if not args.dry_run:
        db = init_firebase()
        print("✅ Connected to Firestore")
    else:
        db = None
    
    # Load data
    collections_to_upload = []
    
    if args.collection == 'rivers' or args.all:
        with open(RIVERS_FILE, 'r', encoding='utf-8') as f:
            rivers = json.load(f)
        if validate_data(rivers, 'rivers'):
            collections_to_upload.append(('rivers', rivers))
    
    if args.collection == 'river_runs' or args.all:
        with open(RIVER_RUNS_FILE, 'r', encoding='utf-8') as f:
            river_runs = json.load(f)
        if validate_data(river_runs, 'river_runs'):
            collections_to_upload.append(('river_runs', river_runs))
    
    # Upload
    for collection_name, data in collections_to_upload:
        upload_collection(db, collection_name, data, dry_run=args.dry_run)
    
    print("\n" + "=" * 60)
    if args.dry_run:
        print("✅ DRY RUN COMPLETE")
        print("\nTo actually upload, run:")
        print("  python3 upload_to_firestore.py --collection rivers")
        print("  python3 upload_to_firestore.py --collection river_runs")
        print("  # or")
        print("  python3 upload_to_firestore.py --all")
    else:
        print("✅ UPLOAD COMPLETE")
        print("\nNext steps:")
        print("  1. Verify data in Firebase Console")
        print("  2. Test in Flutter app")
        print("  3. Check that stationId references work with water_stations collection")

if __name__ == "__main__":
    main()
