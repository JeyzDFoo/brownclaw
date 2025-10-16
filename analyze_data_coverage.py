#!/usr/bin/env python3
"""
Test monthly mean data as a potential bridge between historical daily data and real-time.
Monthly data goes to 2024-12, which is more recent than daily-mean.
"""

import requests
from datetime import datetime

def test_monthly_data_coverage():
    """Test what monthly data is available"""
    station = "08NA011"
    
    print("🔍 Testing Monthly Mean Data Coverage")
    print("=" * 60)
    
    # Get recent monthly data
    url = f"https://api.weather.gc.ca/collections/hydrometric-monthly-mean/items?STATION_NUMBER={station}&limit=50&sortby=-DATE&f=json"
    
    print(f"📡 URL: {url}")
    response = requests.get(url)
    print(f"📊 Response status: {response.status_code}")
    
    if response.status_code == 200:
        data = response.json()
        features = data.get('features', [])
        
        print(f"🔍 Found {len(features)} monthly records")
        
        if features:
            dates = []
            records_by_year = {}
            
            for feature in features:
                props = feature.get('properties', {})
                date_str = props.get('DATE')
                discharge = props.get('MONTHLY_MEAN_DISCHARGE')
                
                if date_str and discharge is not None:
                    year = date_str.split('-')[0]
                    month = date_str.split('-')[1]
                    
                    if year not in records_by_year:
                        records_by_year[year] = {}
                    
                    records_by_year[year][month] = {
                        'discharge': discharge,
                        'date': date_str
                    }
                    dates.append(date_str)
            
            if dates:
                dates.sort()
                print(f"📅 Date range: {dates[0]} to {dates[-1]}")
                
                print(f"\n📊 Recent monthly data:")
                for i, feature in enumerate(features[:12]):  # Show last 12 months
                    props = feature.get('properties', {})
                    date = props.get('DATE')
                    discharge = props.get('MONTHLY_MEAN_DISCHARGE')
                    level = props.get('MONTHLY_MEAN_LEVEL')
                    print(f"  {date}: Discharge={discharge:.2f} m³/s, Level={level:.3f}m" if level else f"  {date}: Discharge={discharge:.2f} m³/s")
                
                # Check 2024 coverage
                print(f"\n📅 2024 Monthly Coverage:")
                if '2024' in records_by_year:
                    year_2024 = records_by_year['2024']
                    months = sorted(year_2024.keys())
                    print(f"  Available months: {', '.join(months)}")
                    print(f"  Missing months: {', '.join([f'{i:02d}' for i in range(1, 13) if f'{i:02d}' not in months])}")
                    
                    # Show 2024 data
                    print(f"\n  2024 Monthly Values:")
                    for month in months:
                        data_point = year_2024[month]
                        print(f"    {data_point['date']}: {data_point['discharge']:.2f} m³/s")
                else:
                    print("  ❌ No 2024 data found")
                
                # Check if we have any 2025 data
                print(f"\n📅 2025 Monthly Coverage:")
                if '2025' in records_by_year:
                    year_2025 = records_by_year['2025']
                    months = sorted(year_2025.keys())
                    print(f"  Available months: {', '.join(months)}")
                    for month in months:
                        data_point = year_2025[month]
                        print(f"    {data_point['date']}: {data_point['discharge']:.2f} m³/s")
                else:
                    print("  ❌ No 2025 monthly data available yet")

def test_daily_mean_2024_coverage():
    """Check exactly what daily data we have for 2024"""
    station = "08NA011"
    
    print(f"\n\n🔍 Testing Daily Mean 2024 Coverage")
    print("=" * 60)
    
    url = f"https://api.weather.gc.ca/collections/hydrometric-daily-mean/items?STATION_NUMBER={station}&datetime=2024-01-01/2024-12-31&limit=1000&sortby=-DATE&f=json"
    
    print(f"📡 URL: {url}")
    response = requests.get(url)
    print(f"📊 Response status: {response.status_code}")
    
    if response.status_code == 200:
        data = response.json()
        features = data.get('features', [])
        
        print(f"🔍 Found {len(features)} daily records for 2024")
        
        if features:
            dates = []
            for feature in features:
                props = feature.get('properties', {})
                date_str = props.get('DATE')
                if date_str:
                    dates.append(date_str)
            
            dates.sort()
            print(f"📅 Date range: {dates[0]} to {dates[-1]}")
            
            # Show the gap
            last_daily = dates[-1] if dates else None
            print(f"\n📊 Daily mean data ends: {last_daily}")
            print(f"📊 Real-time data starts: 2025-09-16 (30-day window)")
            
            if last_daily:
                from datetime import datetime
                last_date = datetime.strptime(last_daily, '%Y-%m-%d')
                gap_start = datetime(2025, 1, 1)
                realtime_start = datetime(2025, 9, 16)
                
                gap_to_2025 = (gap_start - last_date).days
                gap_to_realtime = (realtime_start - last_date).days
                
                print(f"📊 Gap to 2025: {gap_to_2025} days")
                print(f"📊 Gap to real-time data: {gap_to_realtime} days")
                print(f"📊 Missing 2025 period: Jan 1 to Sep 15 (258 days)")

def main():
    test_monthly_data_coverage()
    test_daily_mean_2024_coverage()
    
    print(f"\n\n💡 SOLUTION STRATEGY:")
    print("=" * 60)
    print("1. Historical daily data: Use hydrometric-daily-mean (covers up to 2024-12-31)")
    print("2. Monthly bridge: Use hydrometric-monthly-mean for 2024 summary")  
    print("3. Real-time data: Use hydrometric-realtime (covers last 30 days)")
    print("4. Gap period: 2025-01-01 to 2025-09-15 - No data available")
    print()
    print("🎯 Recommendation: Accept the gap and clearly indicate to users that")
    print("   2025 data from Jan-Sep is not available from government sources.")
    print("   Show historical trends to help users estimate likely conditions.")

if __name__ == "__main__":
    main()