#!/usr/bin/env python3
"""
Explore alternative Government of Canada APIs for water data
to bridge the gap between historical daily-mean and real-time data.
"""

import requests
import json
from datetime import datetime, timedelta

# Test station
STATION = "08NA011"

def test_api_endpoint(name, url, description):
    """Test an API endpoint and report findings"""
    print(f"\n🔍 Testing: {name}")
    print(f"📝 Description: {description}")
    print(f"📡 URL: {url}")
    
    try:
        response = requests.get(url, timeout=10)
        print(f"📊 Response status: {response.status_code}")
        
        if response.status_code == 200:
            try:
                data = response.json()
                if 'features' in data:
                    features = data['features']
                    print(f"🔍 Found {len(features)} records")
                    
                    if features:
                        # Show date range
                        dates = []
                        for feature in features:
                            props = feature.get('properties', {})
                            date_field = props.get('DATE') or props.get('DATETIME') or props.get('date')
                            if date_field:
                                dates.append(date_field)
                        
                        if dates:
                            dates.sort()
                            print(f"📅 Date range: {dates[0]} to {dates[-1]}")
                        
                        # Show sample data
                        print("📊 Sample records:")
                        for i, feature in enumerate(features[:5]):
                            props = feature.get('properties', {})
                            print(f"  [{i}] {props}")
                            
                elif 'items' in data:
                    items = data['items']
                    print(f"🔍 Found {len(items)} records")
                    
                    if items:
                        # Show sample data
                        print("📊 Sample records:")
                        for i, item in enumerate(items[:5]):
                            print(f"  [{i}] {item}")
                else:
                    print(f"📄 Response keys: {list(data.keys())}")
                    print(f"📊 Sample data: {str(data)[:500]}...")
                    
            except json.JSONDecodeError:
                print(f"📄 Non-JSON response: {response.text[:500]}...")
                
        else:
            print(f"❌ HTTP Error: {response.status_code}")
            print(f"📄 Response: {response.text[:200]}...")
            
    except Exception as e:
        print(f"❌ Request failed: {str(e)}")
    
    print("-" * 60)

def main():
    print("🌊 Exploring Alternative Government of Canada Water Data APIs")
    print("=" * 80)
    
    # 1. Try monthly mean data
    test_api_endpoint(
        "Monthly Mean Data",
        f"https://api.weather.gc.ca/collections/hydrometric-monthly-mean/items?STATION_NUMBER={STATION}&limit=100&f=json",
        "Monthly mean discharge values - might have more recent data than daily-mean"
    )
    
    # 2. Try annual statistics  
    test_api_endpoint(
        "Annual Statistics",
        f"https://api.weather.gc.ca/collections/hydrometric-annual-statistics/items?STATION_NUMBER={STATION}&limit=100&f=json",
        "Annual statistics - might have 2024 summary data"
    )
    
    # 3. Try historical data collection (different endpoint)
    test_api_endpoint(
        "Historical Collection",
        f"https://api.weather.gc.ca/collections/hydrometric-historical/items?STATION_NUMBER={STATION}&limit=100&f=json",
        "Historical collection - might be different from daily-mean"
    )
    
    # 4. Try archive collection
    test_api_endpoint(
        "Archive Collection", 
        f"https://api.weather.gc.ca/collections/hydrometric-archive/items?STATION_NUMBER={STATION}&limit=100&f=json",
        "Archive collection - might have more recent archived data"
    )
    
    # 5. Try different date range on daily-mean to see if 2025 data exists
    test_api_endpoint(
        "Daily Mean 2025 Test",
        f"https://api.weather.gc.ca/collections/hydrometric-daily-mean/items?STATION_NUMBER={STATION}&datetime=2025-01-01/2025-12-31&limit=100&f=json",
        "Testing if daily-mean has any 2025 data we missed"
    )
    
    # 6. Try recent daily-mean data (last 90 days)
    end_date = datetime.now().strftime('%Y-%m-%d')
    start_date = (datetime.now() - timedelta(days=90)).strftime('%Y-%m-%d')
    test_api_endpoint(
        "Recent Daily Mean (90 days)",
        f"https://api.weather.gc.ca/collections/hydrometric-daily-mean/items?STATION_NUMBER={STATION}&datetime={start_date}/{end_date}&limit=100&sortby=-DATE&f=json",
        "Testing for very recent daily-mean data"
    )
    
    # 7. Try different real-time parameters to see if we can get more data
    test_api_endpoint(
        "Real-time with different params",
        f"https://api.weather.gc.ca/collections/hydrometric-realtime/items?STATION_NUMBER={STATION}&limit=10000&sortby=DATETIME&f=json",
        "Testing real-time with more records and ascending sort"
    )
    
    # 8. Check what collections are available
    test_api_endpoint(
        "Available Collections",
        "https://api.weather.gc.ca/collections?f=json",
        "List all available hydrometric collections"
    )

if __name__ == "__main__":
    main()