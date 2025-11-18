#!/usr/bin/env python3
"""
Test if a specific station can fetch live water data.
"""

import sys
import os
import requests

# Test station from Cheakamus - Balls to the Wall
STATION_ID = '08GA072'
API_URL = f'https://api.weather.gc.ca/collections/hydrometric-realtime/items?STATION_NUMBER={STATION_ID}'

print(f"🧪 Testing live data fetch for station: {STATION_ID}")
print(f"API URL: {API_URL}")
print("=" * 60)

try:
    response = requests.get(API_URL, timeout=10)
    print(f"Status Code: {response.status_code}")
    
    if response.status_code == 200:
        data = response.json()
        features = data.get('features', [])
        print(f"✅ API Response OK")
        print(f"Features returned: {len(features)}")
        
        if features:
            print("\n📊 Latest readings:")
            for feature in features[:3]:
                props = feature.get('properties', {})
                print(f"  - DateTime: {props.get('DATETIME')}")
                print(f"    Discharge: {props.get('DISCHARGE')} m³/s")
                print(f"    Level: {props.get('LEVEL')} m")
                print()
        else:
            print("⚠️  No features returned (station may be offline or have no recent data)")
    else:
        print(f"❌ API Error: {response.status_code}")
        print(response.text[:500])
        
except Exception as e:
    print(f"❌ Exception: {e}")

print("\n" + "=" * 60)
print("If you see readings above, the API is working.")
print("The issue may be in how the Flutter app is fetching/displaying the data.")
