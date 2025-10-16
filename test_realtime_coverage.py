#!/usr/bin/env python3
"""
Test the real-time API to see how much current year data is available
"""
import requests
import json
from datetime import datetime, timedelta

def test_realtime_api():
    station_id = '08NA011'  # Spillimacheen
    base_url = "https://api.weather.gc.ca/collections/hydrometric-realtime/items"
    
    print(f"🔍 Testing real-time API for station {station_id}")
    print(f"📡 Base URL: {base_url}")
    
    # Test different queries to understand data availability
    test_cases = [
        # No date filter - get latest data
        ("Latest data (no filter)", f"{base_url}?STATION_NUMBER={station_id}&limit=100&sortby=-DATETIME&f=json"),
        
        # Last 7 days
        ("Last 7 days", f"{base_url}?STATION_NUMBER={station_id}&limit=1000&sortby=-DATETIME&f=json"),
        
        # Try current year data
        ("2025 data", f"{base_url}?STATION_NUMBER={station_id}&datetime=2025-01-01/2025-12-31&limit=1000&sortby=-DATETIME&f=json"),
        
        # Try last 30 days specifically
        ("Last 30 days", f"{base_url}?STATION_NUMBER={station_id}&datetime=2025-09-16/2025-10-16&limit=1000&sortby=-DATETIME&f=json"),
        
        # Try going back further in 2025
        ("Summer 2025", f"{base_url}?STATION_NUMBER={station_id}&datetime=2025-06-01/2025-09-30&limit=1000&sortby=-DATETIME&f=json"),
    ]
    
    for description, url in test_cases:
        print(f"\n🔍 Testing: {description}")
        print(f"📡 URL: {url}")
        
        try:
            response = requests.get(url, timeout=30)
            print(f"📊 Response status: {response.status_code}")
            
            if response.status_code == 200:
                data = response.json()
                features = data.get('features', [])
                
                print(f"🔍 Found {len(features)} records")
                
                if features:
                    # Get date range
                    datetimes = []
                    for feature in features:
                        props = feature.get('properties', {})
                        dt = props.get('DATETIME')
                        if dt:
                            datetimes.append(dt)
                    
                    if datetimes:
                        print(f"📅 Date range: {min(datetimes)} to {max(datetimes)}")
                    
                    # Show sample records
                    print(f"📊 Sample records:")
                    for i, feature in enumerate(features[:5]):
                        props = feature.get('properties', {})
                        datetime_val = props.get('DATETIME', 'No datetime')
                        discharge = props.get('DISCHARGE', 'No discharge')
                        level = props.get('LEVEL', 'No level')
                        print(f"  [{i}] DateTime: {datetime_val}, Discharge: {discharge}, Level: {level}")
                    
                    # Count records with discharge data
                    valid_discharge = [f for f in features if f.get('properties', {}).get('DISCHARGE') is not None]
                    print(f"✅ Records with discharge: {len(valid_discharge)}/{len(features)}")
                    
                    # Check data frequency (hourly vs daily)
                    if len(features) >= 2:
                        try:
                            dt1 = datetime.fromisoformat(features[0]['properties']['DATETIME'].replace('Z', '+00:00'))
                            dt2 = datetime.fromisoformat(features[1]['properties']['DATETIME'].replace('Z', '+00:00'))
                            interval = abs((dt1 - dt2).total_seconds() / 60)  # minutes
                            print(f"🕐 Data interval: ~{interval:.0f} minutes between records")
                        except:
                            print("🕐 Could not determine data interval")
                    
                else:
                    print("❌ No records found")
                    
            else:
                print(f"❌ HTTP Error: {response.status_code}")
                if response.text:
                    print(f"Response: {response.text[:200]}...")
                    
        except Exception as e:
            print(f"❌ Exception: {e}")
        
        print("-" * 50)

    # Test what happens if we don't specify dates but get more records
    print(f"\n🔍 Final test: Maximum available real-time data")
    try:
        url = f"{base_url}?STATION_NUMBER={station_id}&limit=10000&sortby=DATETIME&f=json"  # Ascending order to see oldest
        response = requests.get(url, timeout=30)
        
        if response.status_code == 200:
            data = response.json()
            features = data.get('features', [])
            
            if features:
                first_dt = features[0]['properties'].get('DATETIME')
                last_dt = features[-1]['properties'].get('DATETIME')
                print(f"📊 Total available real-time records: {len(features)}")
                print(f"📅 Full date range: {first_dt} to {last_dt}")
                
                # Calculate total days of coverage
                if first_dt and last_dt:
                    try:
                        start = datetime.fromisoformat(first_dt.replace('Z', '+00:00'))
                        end = datetime.fromisoformat(last_dt.replace('Z', '+00:00'))
                        days = (end - start).days
                        print(f"🗓️ Total coverage: {days} days")
                    except:
                        print("🗓️ Could not calculate coverage")
            
    except Exception as e:
        print(f"❌ Error in final test: {e}")

if __name__ == "__main__":
    test_realtime_api()