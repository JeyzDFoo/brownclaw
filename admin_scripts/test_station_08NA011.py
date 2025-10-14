#!/usr/bin/env python3
"""
Test specific station 08NA011 that is known to be online
"""

import requests
from datetime import datetime
import csv
from io import StringIO

def test_specific_station(station_id):
    """Test the specific station that should be online"""
    print(f"🌊 Testing station {station_id}")
    print("=" * 50)
    
    # First, let's check if this station exists in the station list
    print("1️⃣ Checking station in official list...")
    try:
        list_url = 'https://dd.weather.gc.ca/hydrometric/doc/hydrometric_StationList.csv'
        response = requests.get(list_url, timeout=10)
        
        if response.status_code == 200:
            csv_data = StringIO(response.text)
            reader = csv.DictReader(csv_data)
            
            station_found = False
            for row in reader:
                if row.get('STATION_NUMBER', '').strip() == station_id:
                    station_found = True
                    print(f"   ✅ Found station: {row.get('STATION_NAME', 'Unknown')}")
                    print(f"   📍 Location: {row.get('PROV_TERR_STATE_LOC', 'Unknown')}")
                    print(f"   🔴 Real-time: {row.get('REAL_TIME', 'Unknown')}")
                    print(f"   📊 Status: {row.get('HYD_STATUS', 'Unknown')}")
                    break
            
            if not station_found:
                print(f"   ❌ Station {station_id} not found in official list")
                return False
        else:
            print(f"   ❌ Failed to get station list: HTTP {response.status_code}")
    except Exception as e:
        print(f"   ❌ Error checking station list: {e}")
    
    print()
    print("2️⃣ Testing real-time data API...")
    
    # Test different API formats
    api_formats = [
        f'https://wateroffice.ec.gc.ca/services/real_time_data/csv/inline?stations[]={station_id}&parameters[]=47',
        f'https://wateroffice.ec.gc.ca/services/real_time_data/csv/inline?stations={station_id}&parameters=47',
        f'https://wateroffice.ec.gc.ca/services/real_time_data/csv/inline?stations[]={station_id}',
        f'https://wateroffice.ec.gc.ca/services/real_time_data/csv/inline?stations[]={station_id}&parameters[]=46',  # Water level
    ]
    
    for i, url in enumerate(api_formats, 1):
        print(f"   🧪 Format {i}: {url}")
        
        try:
            response = requests.get(url, timeout=15)
            print(f"      Status: {response.status_code}")
            
            if response.status_code == 200:
                content = response.text
                lines = content.split('\\n')
                print(f"      ✅ Success! {len(lines)} lines returned")
                
                if len(lines) >= 2:
                    header = lines[0]
                    print(f"      📋 Header: {header}")
                    
                    # Look for actual data
                    data_found = False
                    for j in range(min(5, len(lines) - 1)):
                        line = lines[j + 1].strip()
                        if line and ',' in line:
                            parts = [p.strip().strip('"') for p in line.split(',')]
                            print(f"      📊 Sample data line {j+1}: {line[:100]}...")
                            
                            # Try to extract flow rate (usually column 2 or 3)
                            if len(parts) >= 3:
                                for col_idx in [2, 3, 4]:
                                    if col_idx < len(parts):
                                        value = parts[col_idx]
                                        try:
                                            flow_rate = float(value)
                                            if flow_rate > 0:
                                                print(f"      🎯 Found flow rate: {flow_rate} m³/s (column {col_idx})")
                                                data_found = True
                                                break
                                        except ValueError:
                                            continue
                            
                            if data_found:
                                break
                    
                    if data_found:
                        print(f"      🎉 SUCCESS! Station {station_id} has real-time data!")
                        return True
                    else:
                        print(f"      ⚠️  No valid flow data found in response")
                else:
                    print(f"      ⚠️  Insufficient data lines")
            elif response.status_code == 422:
                print(f"      ❌ HTTP 422: Unprocessable Entity")
                if response.text:
                    print(f"      💬 Error: {response.text[:200]}")
            else:
                print(f"      ❌ HTTP {response.status_code}")
                
        except Exception as e:
            print(f"      ❌ Error: {e}")
        
        print()
    
    return False

def main():
    station_id = "08NA011"
    
    if test_specific_station(station_id):
        print("🎉 GREAT NEWS!")
        print("✅ The station has real-time data available")
        print("🔧 We can update the Flutter app to use this working format")
    else:
        print("⚠️  Could not retrieve real-time data")
        print("💡 The Flutter app will continue to use realistic simulated data")
        print("🔄 We can retry this station periodically to check if it comes back online")

if __name__ == "__main__":
    main()