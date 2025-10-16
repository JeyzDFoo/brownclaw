#!/usr/bin/env python3
"""
Simulate how the new getCombinedTimeline method would work
for providing unified historical + real-time data to the Flutter UI.
"""

import requests
import json
from datetime import datetime, timedelta

def simulate_get_combined_timeline(station_id):
    """Simulate the getCombinedTimeline method from HistoricalWaterDataService"""
    print(f"🔄 Simulating getCombinedTimeline for station {station_id}")
    print("=" * 60)
    
    results = {
        'historical': [],
        'realtime': [],
        'gap': {},
        'combined': [],
        'availability': {}
    }
    
    # 1. Get historical data (simulated - just get last few days of 2024)
    print("📊 Fetching historical data...")
    hist_url = f"https://api.weather.gc.ca/collections/hydrometric-daily-mean/items?STATION_NUMBER={station_id}&datetime=2024-12-25/2024-12-31&limit=10&sortby=DATE&f=json"
    
    try:
        response = requests.get(hist_url, timeout=10)
        if response.status_code == 200:
            data = response.json()
            features = data.get('features', [])
            
            for feature in features:
                props = feature.get('properties', {})
                results['historical'].append({
                    'date': props.get('DATE'),
                    'discharge': props.get('DISCHARGE'),
                    'level': props.get('LEVEL'),
                    'stationId': station_id,
                    'source': 'historical'
                })
            
            print(f"   ✅ Found {len(results['historical'])} historical records")
    
    except Exception as e:
        print(f"   ❌ Historical data error: {e}")
    
    # 2. Get real-time data and convert to daily averages
    print("🕐 Fetching and converting real-time data...")
    realtime_url = f"https://api.weather.gc.ca/collections/hydrometric-realtime/items?STATION_NUMBER={station_id}&limit=1000&sortby=DATETIME&f=json"
    
    try:
        response = requests.get(realtime_url, timeout=10)
        if response.status_code == 200:
            data = response.json()
            features = data.get('features', [])
            
            # Group by date and calculate daily averages
            daily_data = {}
            for feature in features:
                props = feature.get('properties', {})
                datetime_str = props.get('DATETIME')
                if datetime_str:
                    date = datetime_str.split('T')[0]
                    if date not in daily_data:
                        daily_data[date] = []
                    
                    daily_data[date].append({
                        'discharge': props.get('DISCHARGE'),
                        'level': props.get('LEVEL')
                    })
            
            # Convert to daily averages
            for date in sorted(daily_data.keys()):
                measurements = daily_data[date]
                discharge_vals = [m['discharge'] for m in measurements if m['discharge'] is not None]
                level_vals = [m['level'] for m in measurements if m['level'] is not None]
                
                avg_discharge = sum(discharge_vals) / len(discharge_vals) if discharge_vals else None
                avg_level = sum(level_vals) / len(level_vals) if level_vals else None
                
                if avg_discharge is not None or avg_level is not None:
                    results['realtime'].append({
                        'date': date,
                        'discharge': round(avg_discharge, 2) if avg_discharge else None,
                        'level': round(avg_level, 3) if avg_level else None,
                        'stationId': station_id,
                        'source': 'realtime',
                        'measurementCount': len(measurements)
                    })
            
            print(f"   ✅ Converted {len(results['realtime'])} real-time daily records")
    
    except Exception as e:
        print(f"   ❌ Real-time data error: {e}")
    
    # 3. Create combined timeline
    combined = []
    combined.extend(results['historical'])
    combined.extend(results['realtime'])
    combined.sort(key=lambda x: x['date'])
    results['combined'] = combined
    
    print(f"📈 Combined timeline: {len(combined)} total daily records")
    
    # 4. Calculate gap information
    if results['historical'] and results['realtime']:
        last_historical = results['historical'][-1]['date']
        first_realtime = results['realtime'][0]['date']
        
        last_hist_date = datetime.strptime(last_historical, '%Y-%m-%d')
        first_rt_date = datetime.strptime(first_realtime, '%Y-%m-%d')
        gap_days = (first_rt_date - last_hist_date).days - 1
        
        if gap_days > 0:
            gap_start = (last_hist_date + timedelta(days=1)).strftime('%Y-%m-%d')
            gap_end = (first_rt_date - timedelta(days=1)).strftime('%Y-%m-%d')
            results['gap'] = {
                'exists': True,
                'startDate': gap_start,
                'endDate': gap_end,
                'days': gap_days,
                'description': 'Government data processing gap'
            }
        else:
            results['gap'] = {'exists': False}
    
    # 5. Add availability info
    results['availability'] = {
        'historicalData': {
            'available': True,
            'endDate': '2024-12-31',
            'description': 'Complete historical daily mean data'
        },
        'realtimeData': {
            'available': True,
            'description': 'Last 30 days of 5-minute interval data'
        },
        'currentYearGap': {
            'hasGap': True,
            'description': 'Government daily-mean API has processing lag'
        }
    }
    
    return results

def display_results(results):
    """Display the results in a user-friendly format"""
    print(f"\n📋 COMBINED TIMELINE RESULTS")
    print("=" * 60)
    
    # Historical data summary
    hist_count = len(results['historical'])
    print(f"📊 Historical Data: {hist_count} records")
    if hist_count > 0:
        first_hist = results['historical'][0]['date']
        last_hist = results['historical'][-1]['date']
        print(f"   Range: {first_hist} to {last_hist}")
        print(f"   Sample: {results['historical'][-1]['date']} = {results['historical'][-1]['discharge']:.1f} m³/s")
    
    # Gap information
    gap = results['gap']
    if gap.get('exists', False):
        print(f"\n⚠️  Data Gap: {gap['days']} days")
        print(f"   Period: {gap['startDate']} to {gap['endDate']}")
        print(f"   Reason: {gap['description']}")
    else:
        print(f"\n✅ No data gap detected")
    
    # Real-time data summary  
    rt_count = len(results['realtime'])
    print(f"\n🕐 Real-time Data: {rt_count} records")
    if rt_count > 0:
        first_rt = results['realtime'][0]['date'] 
        last_rt = results['realtime'][-1]['date']
        print(f"   Range: {first_rt} to {last_rt}")
        print(f"   Sample: {results['realtime'][-1]['date']} = {results['realtime'][-1]['discharge']:.1f} m³/s")
        print(f"   Measurements per day: ~{results['realtime'][-1].get('measurementCount', 'N/A')}")
    
    # Combined timeline
    combined_count = len(results['combined'])
    print(f"\n📈 Combined Timeline: {combined_count} total records")
    if combined_count > 0:
        first_combined = results['combined'][0]['date']
        last_combined = results['combined'][-1]['date']
        print(f"   Full range: {first_combined} to {last_combined}")
        
        # Show source breakdown
        hist_in_combined = len([r for r in results['combined'] if r['source'] == 'historical'])
        rt_in_combined = len([r for r in results['combined'] if r['source'] == 'realtime'])
        print(f"   Sources: {hist_in_combined} historical + {rt_in_combined} real-time")

def main():
    station = "08NA011"
    
    print("🧪 Testing Combined Timeline Integration")
    print("=" * 80)
    
    # Simulate the new method
    results = simulate_get_combined_timeline(station)
    
    # Display results
    display_results(results)
    
    print(f"\n\n💡 UI INTEGRATION BENEFITS:")
    print("=" * 60)
    print("✅ Single method call provides complete timeline")
    print("✅ Automatic gap detection and quantification")  
    print("✅ Source tracking for transparency")
    print("✅ Consistent data format (daily averages)")
    print("✅ Ready for chart visualization")
    print("✅ Clear availability information")
    
    print(f"\n🎯 Flutter Implementation:")
    print("   • Call getCombinedTimeline() instead of separate services")
    print("   • Get historical + real-time in one response")
    print("   • Show gap information to users")
    print("   • Build charts from combined data")
    print("   • Display source indicators where helpful")

if __name__ == "__main__":
    main()