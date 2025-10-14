#!/usr/bin/env python3
"""
Add station 08NA011 to Firebase for testing real-time data
"""

import firebase_admin
from firebase_admin import credentials, firestore
import sys
import os

def add_test_station():
    """Add the test station to Firebase"""
    
    # Initialize Firebase
    try:
        cred = credentials.Certificate('service_account_key.json')
        try:
            app = firebase_admin.get_app()
        except ValueError:
            app = firebase_admin.initialize_app(cred)
    except Exception as e:
        print(f"❌ Firebase initialization failed: {e}")
        return False

    db = firestore.client()
    
    # Station data for 08NA011
    station_data = {
        'id': '08NA011',
        'name': 'TEST STATION 08NA011 (Known Online)',
        'province': 'BC',  # Assuming BC based on ID pattern
        'latitude': 50.0,   # Placeholder coordinates
        'longitude': -120.0,
        'riverName': 'Test River',
        'stationName': 'Test Station - 08NA011',
        'dataSource': 'realtime_test',
        'status': 'active'
    }
    
    try:
        # Add to water_stations collection
        doc_ref = db.collection('water_stations').document('08NA011')
        doc_ref.set(station_data)
        
        print("✅ Successfully added test station 08NA011 to Firebase!")
        print(f"📊 Station data: {station_data}")
        print()
        print("🎯 You can now:")
        print("   1. Search for '08NA011' in the station search")
        print("   2. Add it to your favorites")
        print("   3. Test if real-time data works")
        
        return True
        
    except Exception as e:
        print(f"❌ Failed to add station: {e}")
        return False

def main():
    print("🧪 Adding Test Station 08NA011 to Firebase")
    print("=" * 50)
    
    if not os.path.exists('service_account_key.json'):
        print("❌ service_account_key.json not found")
        print("💡 Make sure you're in the admin_scripts directory")
        return
    
    if add_test_station():
        print("\n🎉 Ready to test!")
        print("🚀 Start your Flutter app and search for station '08NA011'")
    else:
        print("\n❌ Setup failed")

if __name__ == "__main__":
    main()