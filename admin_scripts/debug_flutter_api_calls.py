#!/usr/bin/env python3
"""
Test what the Flutter app is actually getting for station 08NA011
"""

import requests
import json
from datetime import datetime

def test_flutter_api_calls():
    """Test the same API calls that the Flutter app makes"""
    station_id = '08NA011'
    
    print(f"🧪 TESTING FLUTTER APP API CALLS")
    print(f"📍 Station: {station_id}")
    print(f"⏰ Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 70)
    
    # Test the exact API calls the Flutter app makes
    endpoints = [
        # Primary API (Government of Canada JSON)
        f'https://api.weather.gc.ca/collections/hydrometric-realtime/items?STATION_NUMBER={station_id}&limit=1&f=json',
        
        # Legacy CSV API (used as fallback)
        f'https://wateroffice.ec.gc.ca/services/real_time_data/csv/inline?stations[]={station_id}&parameters[]=47',
    ]
    
    for i, endpoint in enumerate(endpoints, 1):
        print(f"\n{i}. Testing: {endpoint}")
        print("-" * 60)
        
        try:
            response = requests.get(endpoint, timeout=15)
            print(f"   Status: {response.status_code}")
            print(f"   Content-Type: {response.headers.get('content-type', 'unknown')}")
            print(f"   Content-Length: {len(response.text)}")
            
            if response.status_code == 200:
                content = response.text
                
                # Check if it's JSON
                if 'application/json' in response.headers.get('content-type', ''):
                    try:
                        data = json.loads(content)
                        
                        if 'features' in data and data['features']:
                            features = data['features']
                            print(f"   📊 Features found: {len(features)}")
                            
                            for j, feature in enumerate(features[:3]):  # Show first 3
                                props = feature.get('properties', {})
                                discharge = props.get('DISCHARGE')
                                level = props.get('LEVEL')
                                station_name = props.get('STATION_NAME', 'Unknown')
                                datetime_str = props.get('DATETIME_LST', props.get('DATETIME'))
                                
                                print(f"   Feature {j+1}:")
                                print(f"     Station: {station_name}")
                                print(f"     Time: {datetime_str}")
                                print(f"     Discharge: {discharge}")
                                print(f"     Level: {level}")
                                
                                if discharge is not None:
                                    print(f"   🎯 FOUND DISCHARGE: {discharge} m³/s")
                                    return float(discharge)
                        else:
                            print("   ⚠️  No features in JSON response")
                            
                    except json.JSONDecodeError as e:
                        print(f"   ❌ JSON decode error: {e}")
                
                # Check if it's CSV
                elif 'text/csv' in response.headers.get('content-type', '') or endpoint.endswith('csv'):
                    lines = content.split('\n')
                    print(f"   📄 CSV lines: {len(lines)}")
                    
                    for k, line in enumerate(lines[:10]):  # Show first 10 lines
                        if line.strip():
                            print(f"   Line {k}: {line}")
                            
                            if k > 0:  # Skip header
                                parts = line.split(',')
                                if len(parts) >= 3:
                                    flow_str = parts[2].strip().strip('"')
                                    if flow_str and flow_str.lower() not in ['no data', '']:
                                        try:
                                            flow_value = float(flow_str)
                                            print(f"   🎯 FOUND DISCHARGE: {flow_value} m³/s")
                                            return flow_value
                                        except ValueError:
                                            pass
                
                # Check for HTML (like disclaimer page)
                else:
                    if 'disclaimer' in content.lower():
                        print("   ⚠️  Got disclaimer page")
                    else:
                        sample = content[:200].replace('\n', ' ')
                        print(f"   Sample: {sample}...")
                        
            else:
                print(f"   ❌ HTTP error: {response.status_code}")
                
        except Exception as e:
            print(f"   ❌ Request failed: {e}")
    
    print(f"\n❌ No discharge data found from Flutter app endpoints")
    return None

def compare_with_working_endpoint():
    """Compare with the working CSV endpoint we found"""
    station_id = '08NA011'
    working_url = f'https://dd.weather.gc.ca/hydrometric/csv/BC/hourly/BC_{station_id}_hourly_hydrometric.csv'
    
    print(f"\n🔍 COMPARISON WITH WORKING ENDPOINT:")
    print(f"URL: {working_url}")
    print("-" * 60)
    
    try:
        response = requests.get(working_url, timeout=15)
        
        if response.status_code == 200:
            lines = response.text.split('\n')
            
            # Find the latest data
            for line in reversed(lines):
                if line.strip() and not line.startswith('ID'):
                    parts = line.split(',')
                    if len(parts) >= 7:
                        timestamp = parts[1]
                        discharge = parts[6]
                        
                        print(f"   ✅ Working endpoint data:")
                        print(f"      Time: {timestamp}")
                        print(f"      Discharge: {discharge} m³/s")
                        
                        try:
                            return float(discharge)
                        except ValueError:
                            pass
                        
    except Exception as e:
        print(f"   ❌ Error: {e}")
    
    return None

def main():
    # Test Flutter endpoints
    flutter_discharge = test_flutter_api_calls()
    
    # Test working endpoint
    working_discharge = compare_with_working_endpoint()
    
    print(f"\n" + "=" * 70)
    print(f"📊 RESULTS SUMMARY:")
    
    if flutter_discharge:
        print(f"   🚀 Flutter API: {flutter_discharge} m³/s")
    else:
        print(f"   ❌ Flutter API: No data")
        
    if working_discharge:
        print(f"   ✅ Working CSV: {working_discharge} m³/s")
    else:
        print(f"   ❌ Working CSV: No data")
        
    if flutter_discharge and working_discharge:
        if abs(flutter_discharge - working_discharge) < 0.1:
            print(f"   🎉 Values match! The APIs are in sync")
        else:
            print(f"   ⚠️  Values differ: {abs(flutter_discharge - working_discharge):.2f} m³/s difference")
            print(f"   💡 Flutter app might be using cached or different data")
    
    elif working_discharge and not flutter_discharge:
        print(f"   🔧 ISSUE: Working endpoint has data but Flutter APIs don't")
        print(f"   💡 Flutter app needs to use the working CSV endpoint")
        
if __name__ == "__main__":
    main()