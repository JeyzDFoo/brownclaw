#!/usr/bin/env python3
"""
Investigate the real-time data gap issue.
Check what's actually available in the real-time API as of October 16, 2025.
"""

import requests
from datetime import datetime, timedelta

def investigate_realtime_gap():
    """Check what real-time data is actually available"""
    station = "08NA011"
    
    print("🔍 Investigating Real-time Data Gap Issue")
    print(f"📅 Current Date: October 16, 2025")
    print("=" * 60)
    
    # Check what's available in real-time API
    url = f"https://api.weather.gc.ca/collections/hydrometric-realtime/items?STATION_NUMBER={station}&limit=10&sortby=-DATETIME&f=json"
    
    print("📡 Checking most recent real-time data...")
    print(f"URL: {url}")
    
    try:
        response = requests.get(url, timeout=10)
        if response.status_code == 200:
            data = response.json()
            features = data.get('features', [])
            
            if features:
                print(f"✅ Real-time API returned {len(features)} records")
                
                # Check the most recent record
                latest = features[0]['properties']
                latest_datetime = latest['DATETIME']
                latest_discharge = latest['DISCHARGE']
                latest_level = latest['LEVEL']
                
                print(f"\n📊 Most Recent Real-time Record:")
                print(f"   DateTime: {latest_datetime}")
                print(f"   Discharge: {latest_discharge} m³/s")
                print(f"   Level: {latest_level} m")
                
                # Parse the datetime to see how old it is
                latest_dt = datetime.fromisoformat(latest_datetime.replace('Z', '+00:00'))
                current_dt = datetime(2025, 10, 16, 12, 0, 0)  # Assume noon on Oct 16
                
                age_hours = (current_dt - latest_dt).total_seconds() / 3600
                age_days = age_hours / 24
                
                print(f"\n⏰ Data Age:")
                print(f"   {age_hours:.1f} hours old")
                print(f"   {age_days:.1f} days old")
                
                if age_days > 1:
                    print(f"   ⚠️  Data is significantly outdated!")
                else:
                    print(f"   ✅ Data is reasonably current")
                
                # Check the full date range available
                print(f"\n📅 Checking full real-time data range...")
                
                oldest = features[-1]['properties']
                oldest_datetime = oldest['DATETIME']
                
                print(f"   Oldest record: {oldest_datetime}")
                print(f"   Latest record: {latest_datetime}")
                
                # Get total count
                count_url = f"https://api.weather.gc.ca/collections/hydrometric-realtime/items?STATION_NUMBER={station}&limit=10000&f=json"
                count_response = requests.get(count_url, timeout=30)
                
                if count_response.status_code == 200:
                    count_data = count_response.json()
                    count_features = count_data.get('features', [])
                    
                    if count_features:
                        print(f"\n📈 Full Real-time Dataset:")
                        print(f"   Total records: {len(count_features)}")
                        
                        # Get actual date range
                        all_dates = [f['properties']['DATETIME'] for f in count_features]
                        all_dates.sort()
                        
                        earliest = all_dates[0]
                        latest_full = all_dates[-1]
                        
                        print(f"   Full range: {earliest} to {latest_full}")
                        
                        # Calculate coverage
                        earliest_dt = datetime.fromisoformat(earliest.replace('Z', '+00:00'))
                        latest_full_dt = datetime.fromisoformat(latest_full.replace('Z', '+00:00'))
                        
                        coverage_days = (latest_full_dt - earliest_dt).days
                        gap_to_today = (current_dt - latest_full_dt).days
                        
                        print(f"   Coverage period: {coverage_days} days")
                        print(f"   Gap to today: {gap_to_today} days")
                        
                        if gap_to_today > 0:
                            print(f"\n❌ ISSUE IDENTIFIED:")
                            print(f"   Real-time data stops on {latest_full[:10]}")
                            print(f"   Missing {gap_to_today} days of recent data")
                            print(f"   This explains why charts show Sept 19th as most recent")
                        else:
                            print(f"\n✅ Real-time data appears current")
                
            else:
                print("❌ No real-time data found")
                
        else:
            print(f"❌ HTTP Error: {response.status_code}")
            print(f"Response: {response.text[:200]}")
            
    except Exception as e:
        print(f"❌ Error: {e}")

def check_station_status():
    """Check if the station is active or if there are known issues"""
    station = "08NA011"
    
    print(f"\n\n🏛️ Checking Station Status")
    print("=" * 60)
    
    # Check station metadata
    station_url = f"https://api.weather.gc.ca/collections/hydrometric-stations/items?STATION_NUMBER={station}&f=json"
    
    try:
        response = requests.get(station_url, timeout=10)
        if response.status_code == 200:
            data = response.json()
            features = data.get('features', [])
            
            if features:
                station_info = features[0]['properties']
                print(f"📍 Station: {station_info.get('STATION_NAME', 'Unknown')}")
                print(f"🏛️ Status: {station_info.get('STATUS', 'Unknown')}")
                print(f"📅 First Year: {station_info.get('FIRST_YEAR', 'Unknown')}")
                print(f"📅 Last Year: {station_info.get('LAST_YEAR', 'Unknown')}")
                
                # Check if station is marked as inactive
                status = station_info.get('STATUS', '').upper()
                last_year = station_info.get('LAST_YEAR')
                
                if 'INACTIVE' in status or (last_year and int(last_year) < 2025):
                    print(f"⚠️  Station appears to be inactive or discontinued")
                else:
                    print(f"✅ Station appears to be active")
                    
            else:
                print("❌ Station not found in metadata")
        else:
            print(f"❌ Station metadata error: {response.status_code}")
            
    except Exception as e:
        print(f"❌ Station check error: {e}")

def suggest_solutions():
    """Suggest solutions for the data gap issue"""
    print(f"\n\n💡 POTENTIAL SOLUTIONS")
    print("=" * 60)
    
    print("1. 📊 Update UI Messaging:")
    print("   • Show 'Last Updated: Sept 19' in data availability card")
    print("   • Add warning when real-time data is > 3 days old")
    print("   • Clearly indicate data staleness to users")
    print()
    
    print("2. 🔄 Implement Data Staleness Detection:")
    print("   • Check age of most recent real-time data")
    print("   • Show warning badges for stale data")
    print("   • Adjust time range recommendations based on freshness")
    print()
    
    print("3. 🚨 Fallback Strategy:")
    print("   • For short ranges, show historical data if real-time is stale")
    print("   • Add 'estimated' or 'historical pattern' indicators")
    print("   • Guide users to historical trends when current data unavailable")
    print()
    
    print("4. 🔍 Station-Specific Handling:")
    print("   • Check if this station has seasonal monitoring")
    print("   • Some stations only operate during ice-free periods")
    print("   • May resume data collection in spring")

def main():
    investigate_realtime_gap()
    check_station_status()
    suggest_solutions()

if __name__ == "__main__":
    main()