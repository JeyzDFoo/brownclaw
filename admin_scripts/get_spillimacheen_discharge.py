#!/usr/bin/env python3
"""
Get current Spillimacheen discharge data from CSV endpoint
"""

import requests
import csv
from datetime import datetime, timedelta
import io

def get_spillimacheen_discharge():
    """Get current discharge for Spillimacheen station from CSV data"""
    station_id = '08NA011'
    
    # The working CSV endpoint
    url = f'https://dd.weather.gc.ca/hydrometric/csv/BC/hourly/BC_{station_id}_hourly_hydrometric.csv'
    
    print(f"🌊 SPILLIMACHEEN RIVER DISCHARGE DATA")
    print(f"📍 Station: {station_id} (Spillimacheen River at Spillimacheen)")
    print(f"🔗 URL: {url}")
    print("=" * 70)
    
    try:
        response = requests.get(url, timeout=15)
        
        if response.status_code == 200:
            csv_content = response.text
            print(f"✅ Retrieved CSV data ({len(csv_content)} characters)")
            
            # Parse CSV
            csv_reader = csv.DictReader(io.StringIO(csv_content))
            
            # Get all data points
            data_points = list(csv_reader)
            
            if data_points:
                # Get the most recent data point
                latest = data_points[-1]
                
                # Extract information
                timestamp = latest['Date']
                water_level = latest['Water Level / Niveau d\'eau (m)']
                discharge = latest['Discharge / DÃ©bit (cms)']
                
                print(f"📊 CURRENT CONDITIONS:")
                print(f"   ⏰ Time: {timestamp}")
                print(f"   🌊 Discharge: {discharge} m³/s")
                print(f"   📏 Water Level: {water_level} m")
                
                # Show recent trend (last 12 readings = 1 hour)
                recent_points = data_points[-12:]
                print(f"\n📈 RECENT TREND (Last 12 readings):")
                
                for i, point in enumerate(recent_points):
                    time_str = point['Date'].split('T')[1][:5]  # Just HH:MM
                    discharge_val = point['Discharge / DÃ©bit (cms)']
                    level_val = point['Water Level / Niveau d\'eau (m)']
                    print(f"   {time_str}: {discharge_val} m³/s (Level: {level_val}m)")
                
                # Calculate some statistics
                recent_discharges = [float(p['Discharge / DÃ©bit (cms)']) for p in recent_points if p['Discharge / DÃ©bit (cms)']]
                
                if recent_discharges:
                    avg_discharge = sum(recent_discharges) / len(recent_discharges)
                    min_discharge = min(recent_discharges)
                    max_discharge = max(recent_discharges)
                    
                    print(f"\n📊 HOURLY STATISTICS:")
                    print(f"   📊 Average: {avg_discharge:.2f} m³/s")
                    print(f"   📉 Minimum: {min_discharge:.2f} m³/s")
                    print(f"   📈 Maximum: {max_discharge:.2f} m³/s")
                    print(f"   📏 Range: {max_discharge - min_discharge:.2f} m³/s")
                
                # Show data availability
                total_points = len(data_points)
                print(f"\n📋 DATA AVAILABILITY:")
                print(f"   📊 Total data points: {total_points}")
                
                if total_points > 1:
                    first_time = data_points[0]['Date']
                    last_time = data_points[-1]['Date']
                    print(f"   🕐 First reading: {first_time}")
                    print(f"   🕑 Last reading: {last_time}")
                
                # Return the current discharge value
                return float(discharge), timestamp
                
            else:
                print("❌ No data points found in CSV")
                return None, None
        
        else:
            print(f"❌ HTTP {response.status_code}")
            return None, None
            
    except Exception as e:
        print(f"❌ Error retrieving data: {e}")
        return None, None

def main():
    print(f"📅 Retrieved at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print()
    
    discharge, timestamp = get_spillimacheen_discharge()
    
    print("\n" + "=" * 70)
    if discharge and timestamp:
        print("🎉 SUCCESS!")
        print(f"💧 Current Spillimacheen River discharge: {discharge} m³/s")
        print(f"⏰ As of: {timestamp}")
        print()
        print("✅ This CSV endpoint provides reliable real-time data!")
        print("🔧 Can be integrated into the Flutter app for live updates")
    else:
        print("⚠️  Could not retrieve current discharge data")

if __name__ == "__main__":
    main()