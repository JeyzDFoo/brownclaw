#!/usr/bin/env python3
"""
Test specific station 08NA011 - Spillimacheen River near Spillimacheen, BC
This station is confirmed to be online with continuous operation.
"""

import requests
import json
from datetime import datetime

def test_spillimacheen_station():
    """Test the Spillimacheen River station that should be online"""
    station_id = '08NA011'
    station_name = 'SPILLIMACHEEN RIVER NEAR SPILLIMACHEEN'
    
    print(f"🧪 Testing {station_name} ({station_id})")
    print(f"📍 Location: BC, Canada")
    print(f"🔄 Expected: Continuous operation with recent data")
    print("=" * 60)
    
    # Test working Government of Canada API
    formats = [
        # New working Government of Canada JSON API 
        f'https://api.weather.gc.ca/collections/hydrometric-realtime/items?STATION_NUMBER={station_id}&limit=1&f=json',
        
        # Legacy formats (for comparison - these should fail)
        f'https://wateroffice.ec.gc.ca/services/real_time_data/csv/inline?stations[]={station_id}&parameters[]=47',
        f'https://wateroffice.ec.gc.ca/services/real_time_data/csv/inline?stations={station_id}&parameters=47',
    ]
    
    for i, url in enumerate(formats, 1):
        print(f"\n🔍 Format {i}: Testing API endpoint...")
        print(f"   URL: {url}")
        
        try:
            response = requests.get(url, timeout=15)
            print(f"   📊 Status: {response.status_code}")
            
            if response.status_code == 200:
                content = response.text.strip()
                print(f"   ✅ Success! Content length: {len(content)} characters")
                
                # Handle JSON responses (new Government of Canada API)
                if url.startswith('https://api.weather.gc.ca'):
                    try:
                        json_data = json.loads(content)
                        if 'features' in json_data and json_data['features']:
                            print(f"   📊 JSON response with {len(json_data['features'])} features")
                            # Extract flow data from JSON
                            for feature in json_data['features']:
                                properties = feature.get('properties', {})
                                station_name = properties.get('STATION_NAME', 'Unknown')
                                discharge = properties.get('DISCHARGE')
                                level = properties.get('LEVEL')
                                datetime_str = properties.get('DATETIME_LST', properties.get('DATETIME'))
                                
                                print(f"   🏷️  Station: {station_name}")
                                print(f"   📅 Time: {datetime_str}")
                                
                                if discharge is not None:
                                    flow_rate = float(discharge)
                                    print(f"   🌊 Discharge: {flow_rate} m³/s")
                                    
                                    # Determine status
                                    if flow_rate < 5:
                                        status = "Low"
                                    elif flow_rate < 20:
                                        status = "Good"
                                    elif flow_rate < 50:
                                        status = "High"
                                    else:
                                        status = "Very High"
                                    
                                    print(f"   🎯 Flow Status: {status}")
                                    print(f"   🎉 SUCCESS! Station {station_id} is providing live data!")
                                    return True
                                elif level is not None:
                                    water_level = float(level)
                                    print(f"   📏 Water Level: {water_level} m")
                                    print(f"   ℹ️  No discharge data, but level available")
                                else:
                                    print(f"   ⚠️  No discharge or level data in response")
                        else:
                            print(f"   ⚠️  No features in JSON response")
                    except json.JSONDecodeError:
                        print(f"   ⚠️  Invalid JSON response")
                        continue
                
                # Handle CSV responses (legacy wateroffice API)
                else:
                    lines = content.split('\n')
                    print(f"   📄 CSV response has {len(lines)} lines")
                    
                    if len(lines) >= 2:
                        header = lines[0]
                        print(f"   📋 Header: {header}")
                        
                        # Look for data lines
                        data_found = False
                        for line_num, line in enumerate(lines[1:], 1):
                            line = line.strip()
                            if line and not line.startswith('#'):
                                parts = [p.strip().strip('"') for p in line.split(',')]
                                if len(parts) >= 3:
                                    flow_str = parts[2] if len(parts) > 2 else ''
                                    if flow_str and flow_str.lower() not in ['no data', '', 'nan']:
                                        try:
                                            flow_rate = float(flow_str)
                                            print(f"   🌊 Found flow data at line {line_num}: {flow_rate} m³/s")
                                            data_found = True
                                            
                                            # Determine status
                                            if flow_rate < 5:
                                                status = "Low"
                                            elif flow_rate < 20:
                                                status = "Good"
                                            elif flow_rate < 50:
                                                status = "High"
                                            else:
                                                status = "Very High"
                                            
                                            print(f"   🎯 Flow Status: {status}")
                                            print(f"   🎉 SUCCESS! Station {station_id} is providing live data!")
                                            return True
                                        except ValueError:
                                            continue
                        
                        if not data_found:
                            print(f"   ⚠️  No valid flow data found in CSV response")
                    else:
                        print(f"   ⚠️  Response too short, no data lines")
                    
            elif response.status_code == 422:
                print(f"   ❌ Unprocessable Entity - may be API format issue")
            else:
                print(f"   ❌ Failed - HTTP {response.status_code}")
                if response.text:
                    print(f"   💬 Response: {response.text[:200]}")
                    
        except requests.exceptions.Timeout:
            print(f"   ⏰ Request timed out after 15 seconds")
        except Exception as e:
            print(f"   ❌ Error: {e}")
    
    print(f"\n❌ All formats failed for station {station_id}")
    print(f"💡 This might indicate:")
    print(f"   • API service is temporarily down")
    print(f"   • Station is offline despite status page")
    print(f"   • API format has changed")
    return False

def main():
    print("🧪 Testing Spillimacheen River Station (08NA011)")
    print("🕒 " + datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
    print()
    
    success = test_spillimacheen_station()
    
    print("\n" + "=" * 60)
    if success:
        print("🎉 RESULT: Station 08NA011 is working!")
        print("✅ Your Flutter app should now show live data for this station")
    else:
        print("⚠️  RESULT: Unable to retrieve live data")
        print("🔄 Flutter app will show realistic simulated data instead")

if __name__ == "__main__":
    main()