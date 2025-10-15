#!/usr/bin/env python3
"""
Test real-time data fetching for favorite stations
"""

import requests
from datetime import datetime
import csv
import json
from io import StringIO

# Test with some popular whitewater stations
test_stations = [
    {'id': '05BH004', 'name': 'Bow River at Calgary'},
    {'id': '05AD007', 'name': 'Kicking Horse River at Golden'},
    {'id': '02KF005', 'name': 'Ottawa River near Ottawa'},
    {'id': '08MF005', 'name': 'Fraser River at Hope'},
]

def test_station_data(station_id, station_name):
    """Test fetching real-time data for a specific station using multiple API formats"""
    print(f"\n🌊 Testing {station_name} ({station_id})")
    
    # Try multiple API formats based on research from other scripts
    api_formats = [
        # Original format that was working before
        f'https://wateroffice.ec.gc.ca/services/real_time_data/csv/inline?stations[]={station_id}&parameters[]=47',
        
        # Alternative parameter formats
        f'https://wateroffice.ec.gc.ca/services/real_time_data/csv/inline?stations={station_id}&parameters=47',
        f'https://wateroffice.ec.gc.ca/services/real_time_data/csv/inline?stations[]={station_id}',
        f'https://wateroffice.ec.gc.ca/services/real_time_data/csv/inline?stations[]={station_id}&parameters[]=46', # water level
        
        # New Government of Canada JSON API (correct parameter name found!)
        f'https://api.weather.gc.ca/collections/hydrometric-realtime/items?STATION_NUMBER={station_id}&limit=1&f=json',
        
        # MSC Datamart formats
        f'https://dd.weather.gc.ca/today/hydrometric/csv/{station_id}_hourly.csv',
        f'https://dd.weather.gc.ca/today/hydrometric/csv/{station_id}.csv',
    ]
    
    for i, url in enumerate(api_formats, 1):
        try:
            print(f"   🧪 Format {i}: {url}")
            response = requests.get(url, timeout=15, headers={'User-Agent': 'BrownClaw-Water-App/1.0'})
            
            print(f"      Status: {response.status_code}")
            
            if response.status_code == 200:
                content = response.text.strip()
                if not content:
                    print(f"      ⚠️  Empty response")
                    continue
                    
                # Handle JSON responses
                if url.startswith('https://api.weather.gc.ca'):
                    try:
                        json_data = json.loads(content)
                        if 'features' in json_data and json_data['features']:
                            print(f"      ✅ JSON response with {len(json_data['features'])} features")
                            # Extract flow data from JSON
                            for feature in json_data['features']:
                                properties = feature.get('properties', {})
                                station_name = properties.get('STATION_NAME', 'Unknown')
                                discharge = properties.get('DISCHARGE')
                                level = properties.get('LEVEL')
                                datetime_str = properties.get('DATETIME_LST', properties.get('DATETIME'))
                                
                                print(f"      🏷️  Station: {station_name}")
                                print(f"      📅 Time: {datetime_str}")
                                
                                if discharge is not None:
                                    flow_rate = float(discharge)
                                    print(f"      🌊 Discharge: {flow_rate} m³/s")
                                    
                                    # Determine status
                                    if flow_rate < 10:
                                        status = "Too Low"
                                    elif flow_rate < 30:
                                        status = "Low"
                                    elif flow_rate < 100:
                                        status = "Good"
                                    elif flow_rate < 200:
                                        status = "High"
                                    else:
                                        status = "Too High"
                                    
                                    print(f"      🎯 Status: {status}")
                                    print(f"      � SUCCESS! Found working Government of Canada API!")
                                    return True
                                elif level is not None:
                                    water_level = float(level)
                                    print(f"      📏 Water Level: {water_level} m")
                                    print(f"      ℹ️  No discharge data, but level available")
                                else:
                                    print(f"      ⚠️  No discharge or level data in response")
                        else:
                            print(f"      ⚠️  No features in JSON response")
                        continue
                    except json.JSONDecodeError:
                        print(f"      ⚠️  Invalid JSON response")
                        continue
                
                # Handle CSV responses
                lines = content.split('\n')
                print(f"      📄 CSV response has {len(lines)} lines")
                
                if len(lines) >= 2:
                    # Parse the header
                    header = lines[0]
                    print(f"      📋 Header: {header[:80]}...")
                    
                    # Find the latest data
                    for j in range(len(lines) - 1, 0, -1):
                        line = lines[j].strip()
                        if line and not line.startswith('#'):
                            parts = [p.strip().strip('"') for p in line.split(',')]
                            if len(parts) >= 3:
                                flow_str = parts[2]
                                if flow_str and flow_str.lower() not in ['no data', '', 'nan']:
                                    try:
                                        flow_rate = float(flow_str)
                                        print(f"      ✅ Latest flow rate: {flow_rate} m³/s")
                                        
                                        # Determine status
                                        if flow_rate < 10:
                                            status = "Too Low"
                                        elif flow_rate < 30:
                                            status = "Low"
                                        elif flow_rate < 100:
                                            status = "Good"
                                        elif flow_rate < 200:
                                            status = "High"
                                        else:
                                            status = "Too High"
                                        
                                        print(f"      🎯 Status: {status}")
                                        print(f"      🎉 SUCCESS! Found working API format!")
                                        return True
                                    except ValueError:
                                        continue
                    
                    print(f"      ⚠️  No valid flow data found in CSV")
                else:
                    print(f"      ⚠️  Insufficient data lines in CSV")
                    
            elif response.status_code == 422:
                print(f"      ❌ HTTP 422 - Unprocessable Entity (API format/parameter issue)")
            elif response.status_code == 404:
                print(f"      ❌ HTTP 404 - Endpoint not found")
            else:
                print(f"      ❌ HTTP {response.status_code}")
                if response.text and len(response.text) < 500:
                    print(f"      💬 Response: {response.text}")
        
        except requests.RequestException as e:
            print(f"      ❌ Request failed: {e}")
        
        except Exception as e:
            print(f"      ❌ Error: {e}")
    
    return False

def main():
    print("🧪 Testing Real-Time Water Data API - Enhanced Version")
    print("🕒 " + datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
    print("=" * 60)
    print("🔍 Testing multiple API formats per station:")
    print("   • Original wateroffice.ec.gc.ca CSV API")
    print("   • New Government of Canada JSON API") 
    print("   • MSC Datamart CSV endpoints")
    print("=" * 60)
    
    success_count = 0
    total_count = len(test_stations)
    
    for station in test_stations:
        if test_station_data(station['id'], station['name']):
            success_count += 1
    
    print(f"\n📊 Results: {success_count}/{total_count} stations returned data")
    print("=" * 60)
    
    if success_count > 0:
        print("✅ Real-time data API is working!")
        print("🎉 Your favorite stations should now show live flow rates!")
        print("🔧 Update your Flutter app to use the working API format")
    else:
        print("⚠️  No stations returned data from any API format")
        print("💡 Possible issues:")
        print("   • All API endpoints may be temporarily down")
        print("   • Station IDs may be inactive or changed")
        print("   • API authentication may now be required")
        print("   • Service may have moved to a new endpoint")
        print("� The app will fall back to demo data")
        print("\n💭 Next steps:")
        print("   1. Check Environment Canada service status")
        print("   2. Look for updated API documentation")
        print("   3. Consider implementing web scraping fallback")
        print("   4. Contact Environment Canada for API support")

if __name__ == "__main__":
    main()