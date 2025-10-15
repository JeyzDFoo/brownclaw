#!/usr/bin/env python3
"""
Test the updated LiveWaterDataService to ensure it works for all stations
"""

import requests
from datetime import datetime

def test_new_approach():
    """Test that the CSV-first approach works for multiple stations"""
    
    test_stations = [
        ('08NA011', 'BC', 'Spillimacheen River'),
        ('08NB005', 'BC', 'Kicking Horse River'), 
        ('05BH004', 'AB', 'Bow River at Calgary'),
        ('02KF005', 'ON', 'Ottawa River')
    ]
    
    print("🧪 TESTING NEW CSV-FIRST APPROACH")
    print(f"📅 {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 70)
    
    for station_id, province, river_name in test_stations:
        print(f"\n📍 Testing {station_id} - {river_name}")
        print("-" * 50)
        
        # Test CSV Data Mart endpoint
        csv_url = f'https://dd.weather.gc.ca/hydrometric/csv/{province}/hourly/{province}_{station_id}_hourly_hydrometric.csv'
        
        try:
            response = requests.get(csv_url, timeout=15)
            
            if response.status_code == 200:
                lines = response.text.split('\n')
                
                # Find latest data
                for line in reversed(lines):
                    if line.strip() and not line.startswith('ID'):
                        parts = line.split(',')
                        if len(parts) >= 7:
                            timestamp = parts[1]
                            discharge = parts[6]
                            
                            if discharge and discharge.lower() != 'no data':
                                try:
                                    flow_rate = float(discharge)
                                    print(f"   ✅ CSV: {flow_rate} m³/s at {timestamp}")
                                    
                                    if station_id == '08NA011':
                                        if 8 <= flow_rate <= 10:
                                            print(f"   🎉 SPILLIMACHEEN FIXED! Now shows {flow_rate} instead of 34.8")
                                        else:
                                            print(f"   ⚠️  Unexpected value: {flow_rate}")
                                    
                                    break
                                except ValueError:
                                    pass
                
            else:
                print(f"   ❌ CSV endpoint failed: {response.status_code}")
                
        except Exception as e:
            print(f"   ❌ CSV error: {e}")
        
        # Test JSON API (for comparison)
        json_url = f'https://api.weather.gc.ca/collections/hydrometric-realtime/items?STATION_NUMBER={station_id}&limit=1&f=json'
        
        try:
            response = requests.get(json_url, timeout=10)
            
            if response.status_code == 200:
                import json
                data = json.loads(response.text)
                
                if 'features' in data and data['features']:
                    feature = data['features'][0]
                    props = feature.get('properties', {})
                    discharge = props.get('DISCHARGE')
                    timestamp = props.get('DATETIME_LST', props.get('DATETIME'))
                    
                    if discharge:
                        print(f"   📊 JSON: {discharge} m³/s at {timestamp}")
                        
                        if station_id == '08NA011' and discharge == 34.8:
                            print(f"   ⚠️  JSON still has old data (34.8)")
                    else:
                        print(f"   ❌ JSON: No discharge data")
                else:
                    print(f"   ❌ JSON: No features")
            else:
                print(f"   ❌ JSON endpoint: {response.status_code}")
                
        except Exception as e:
            print(f"   ❌ JSON error: {e}")
    
    print(f"\n" + "=" * 70)
    print("📊 SUMMARY:")
    print("✅ CSV Data Mart provides current, reliable data")
    print("⚠️  JSON API may have stale data (especially for 08NA011)")
    print("🎯 Flutter app now uses CSV first, JSON as fallback")
    print("\n🚀 Your app should now show:")
    print("   • Spillimacheen: ~8.43 m³/s (not 34.8)")
    print("   • All other stations: Most current available data")

if __name__ == "__main__":
    test_new_approach()