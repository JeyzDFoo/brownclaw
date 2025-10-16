#!/usr/bin/env python3
"""
Parse the available collections and test promising ones for recent data.
"""

import requests
import json

def get_collections():
    """Get all available collections and analyze them"""
    print("🔍 Getting all available collections...")
    response = requests.get("https://api.weather.gc.ca/collections?f=json")
    
    if response.status_code == 200:
        data = response.json()
        collections = data.get('collections', [])
        
        print(f"📊 Found {len(collections)} collections:")
        print()
        
        hydrometric_collections = []
        for collection in collections:
            if 'hydrometric' in collection['id'].lower():
                hydrometric_collections.append(collection)
                print(f"🌊 {collection['id']}")
                print(f"   📝 {collection.get('title', 'No title')}")
                print(f"   📄 {collection.get('description', 'No description')}")
                print()
        
        return hydrometric_collections
    
    return []

def test_collection_for_recent_data(collection_id):
    """Test a collection for recent data"""
    station = "08NA011"
    print(f"\n🔍 Testing {collection_id} for recent data...")
    
    # Try different approaches
    urls_to_try = [
        f"https://api.weather.gc.ca/collections/{collection_id}/items?STATION_NUMBER={station}&limit=10&sortby=-DATE&f=json",
        f"https://api.weather.gc.ca/collections/{collection_id}/items?STATION_NUMBER={station}&limit=10&sortby=-DATETIME&f=json", 
        f"https://api.weather.gc.ca/collections/{collection_id}/items?STATION_NUMBER={station}&datetime=2024-01-01/2025-12-31&limit=10&f=json",
        f"https://api.weather.gc.ca/collections/{collection_id}/items?STATION_NUMBER={station}&limit=10&f=json"
    ]
    
    for i, url in enumerate(urls_to_try):
        try:
            print(f"  📡 Attempt {i+1}: {url}")
            response = requests.get(url, timeout=10)
            
            if response.status_code == 200:
                data = response.json()
                if 'features' in data:
                    features = data['features']
                    if features:
                        print(f"  ✅ Found {len(features)} records")
                        
                        # Extract dates
                        dates = []
                        for feature in features:
                            props = feature.get('properties', {})
                            date_val = props.get('DATE') or props.get('DATETIME') or props.get('date')
                            if date_val:
                                dates.append(date_val)
                        
                        if dates:
                            dates.sort()
                            print(f"  📅 Date range: {dates[0]} to {dates[-1]}")
                            
                            # Show most recent record
                            latest_feature = features[0]
                            props = latest_feature.get('properties', {})
                            print(f"  📊 Latest record: {props}")
                            return True
                        break
                    else:
                        print(f"  ⚠️ No records found")
                else:
                    print(f"  ❓ Unexpected response structure")
            else:
                print(f"  ❌ HTTP {response.status_code}")
                
        except Exception as e:
            print(f"  ❌ Error: {e}")
    
    return False

def main():
    print("🌊 Comprehensive Analysis of Government of Canada Hydrometric APIs")
    print("=" * 80)
    
    # Get all collections
    collections = get_collections()
    
    if not collections:
        print("❌ Could not retrieve collections")
        return
    
    print("\n" + "="*60)
    print("🔍 Testing each hydrometric collection for recent data...")
    print("="*60)
    
    promising_collections = []
    for collection in collections:
        collection_id = collection['id']
        if test_collection_for_recent_data(collection_id):
            promising_collections.append(collection_id)
    
    print(f"\n📋 Summary of promising collections:")
    for collection_id in promising_collections:
        print(f"  ✅ {collection_id}")
    
    if not promising_collections:
        print("  ❌ No collections found with recent data")
    
    # Let's also try the official Water Office API directly
    print(f"\n🔍 Testing official Water Office API...")
    try:
        # This is the API that the government's own website uses
        url = "https://wateroffice.ec.gc.ca/services/real_time_data/csv/inline?stations[]=08NA011"
        print(f"📡 URL: {url}")
        response = requests.get(url, timeout=10)
        print(f"📊 Response status: {response.status_code}")
        
        if response.status_code == 200:
            # This returns CSV data
            lines = response.text.split('\n')[:10]
            print(f"📄 CSV Response (first 10 lines):")
            for i, line in enumerate(lines):
                print(f"  [{i}] {line}")
        else:
            print(f"❌ Failed: {response.text[:200]}")
    except Exception as e:
        print(f"❌ Error testing Water Office API: {e}")

if __name__ == "__main__":
    main()