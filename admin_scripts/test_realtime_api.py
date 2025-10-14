#!/usr/bin/env python3
"""
Test real-time data fetching for favorite stations
"""

import requests
from datetime import datetime
import csv
from io import StringIO

# Test with some popular whitewater stations
test_stations = [
    {'id': '05BH004', 'name': 'Bow River at Calgary'},
    {'id': '05AD007', 'name': 'Kicking Horse River at Golden'},
    {'id': '02KF005', 'name': 'Ottawa River near Ottawa'},
    {'id': '08MF005', 'name': 'Fraser River at Hope'},
]

def test_station_data(station_id, station_name):
    """Test fetching real-time data for a specific station"""
    print(f"\n🌊 Testing {station_name} ({station_id})")
    
    url = f'https://wateroffice.ec.gc.ca/services/real_time_data/csv/inline?stations[]={station_id}&parameters[]=47'
    
    try:
        response = requests.get(url, timeout=15)
        
        if response.status_code == 200:
            csv_data = response.text
            lines = csv_data.strip().split('\n')
            
            print(f"   📄 CSV response has {len(lines)} lines")
            
            if len(lines) >= 2:
                # Parse the header
                header = lines[0]
                print(f"   📋 Header: {header[:100]}...")
                
                # Find the latest data
                for i in range(len(lines) - 1, 0, -1):
                    line = lines[i].strip()
                    if line:
                        parts = [p.strip().strip('"') for p in line.split(',')]
                        if len(parts) >= 3:
                            flow_str = parts[2]
                            if flow_str and flow_str.lower() not in ['no data', '']:
                                try:
                                    flow_rate = float(flow_str)
                                    print(f"   ✅ Latest flow rate: {flow_rate} m³/s")
                                    
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
                                    
                                    print(f"   🎯 Status: {status}")
                                    return True
                                except ValueError:
                                    continue
                
                print(f"   ⚠️  No valid flow data found")
            else:
                print(f"   ⚠️  Insufficient data lines")
        else:
            print(f"   ❌ HTTP {response.status_code}")
    
    except requests.RequestException as e:
        print(f"   ❌ Request failed: {e}")
    
    except Exception as e:
        print(f"   ❌ Error: {e}")
    
    return False

def main():
    print("🧪 Testing Real-Time Water Data API")
    print("=" * 50)
    
    success_count = 0
    total_count = len(test_stations)
    
    for station in test_stations:
        if test_station_data(station['id'], station['name']):
            success_count += 1
    
    print(f"\n📊 Results: {success_count}/{total_count} stations returned data")
    
    if success_count > 0:
        print("✅ Real-time data API is working!")
        print("🎉 Your favorite stations should now show live flow rates!")
    else:
        print("⚠️  No stations returned data - API may be down or stations inactive")
        print("💡 The app will fall back to demo data")

if __name__ == "__main__":
    main()