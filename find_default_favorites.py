#!/usr/bin/env python3
"""
Find the correct river run IDs for default favorites.
Searches for Kananaskis River and Harvie Passage in Firestore.
"""

import firebase_admin
from firebase_admin import credentials, firestore

# Initialize Firebase Admin
firebase_admin.initialize_app()

db = firestore.client()

print("=" * 60)
print("Searching for default favorite river runs...")
print("=" * 60)

# Search for Kananaskis River
print("\n🔍 Searching for Kananaskis River...")
kananaskis_runs = []
runs_ref = db.collection('river_runs')

for doc in runs_ref.stream():
    data = doc.to_dict()
    name = (data.get('name') or '').lower()
    river = (data.get('river') or '').lower()
    location = (data.get('location') or '').lower()
    
    if 'kananaskis' in name or 'kananaskis' in river:
        kananaskis_runs.append({
            'id': doc.id,
            'name': data.get('name'),
            'river': data.get('river'),
            'difficulty': data.get('difficulty'),
        })
        print(f"  ✅ Found: {doc.id}")
        print(f"     Name: {data.get('name')}")
        print(f"     River: {data.get('river')}")
        print(f"     Difficulty: {data.get('difficulty')}")
        print()

# Search for Harvie Passage
print("\n🔍 Searching for Harvie Passage...")
harvie_runs = []

for doc in runs_ref.stream():
    data = doc.to_dict()
    name = (data.get('name') or '').lower()
    river = (data.get('river') or '').lower()
    location = (data.get('location') or '').lower()
    
    if 'harvie' in name or 'harvie' in location or ('bow' in river and 'harvie' in name):
        harvie_runs.append({
            'id': doc.id,
            'name': data.get('name'),
            'river': data.get('river'),
            'difficulty': data.get('difficulty'),
        })
        print(f"  ✅ Found: {doc.id}")
        print(f"     Name: {data.get('name')}")
        print(f"     River: {data.get('river')}")
        print(f"     Difficulty: {data.get('difficulty')}")
        print()

# Summary
print("\n" + "=" * 60)
print("SUMMARY")
print("=" * 60)

if kananaskis_runs:
    print(f"\n✅ Kananaskis River runs found: {len(kananaskis_runs)}")
    print("   Recommended ID for default favorite:")
    print(f"   '{kananaskis_runs[0]['id']}'")
else:
    print("\n❌ No Kananaskis River runs found")

if harvie_runs:
    print(f"\n✅ Harvie Passage runs found: {len(harvie_runs)}")
    print("   Recommended ID for default favorite:")
    print(f"   '{harvie_runs[0]['id']}'")
else:
    print("\n❌ No Harvie Passage runs found")

print("\n" + "=" * 60)
print("NEXT STEPS")
print("=" * 60)
print("\n1. Update functions/main.py with the correct IDs:")
print("   default_favorites = [")
if kananaskis_runs:
    print(f"       '{kananaskis_runs[0]['id']}',  # Kananaskis River")
if harvie_runs:
    print(f"       '{harvie_runs[0]['id']}',  # Harvie Passage")
print("   ]")
print("\n2. Deploy the function:")
print("   firebase deploy --only functions:onUserCreated")
print("\n3. Test with a new user account creation")
print()
