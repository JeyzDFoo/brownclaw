#!/usr/bin/env python3
"""
Extract Barrier Dam High Flow Hours

This script fetches TransAlta river flow data and extracts the specific hours
when the Barrier Dam is flowing above a threshold (default 20 m³/s).

It also calculates when water actually arrives downstream by adding the 45-minute
travel time from Barrier Dam to Canoe Meadows.

This is useful for whitewater paddlers planning trips to the Kananaskis River.
"""

import requests
import json
from datetime import datetime, timedelta

# Headers to mimic a browser request
HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
    'Accept': 'application/json, text/javascript, */*; q=0.01',
    'Accept-Language': 'en-US,en;q=0.9',
    'Referer': 'https://transalta.com/river-flows/',
    'X-Requested-With': 'XMLHttpRequest',
}

def fetch_transalta_flows():
    """Fetch flow data from TransAlta API"""
    url = "https://transalta.com/river-flows/?get-riverflow-data=1"
    
    try:
        response = requests.get(url, headers=HEADERS, timeout=15)
        
        if response.status_code == 200:
            return response.json()
        else:
            print(f"❌ HTTP {response.status_code}")
            return None
            
    except Exception as e:
        print(f"❌ Error fetching data: {e}")
        return None

def extract_high_flow_hours(data, threshold=20, travel_time_minutes=45):
    """
    Extract hours when Barrier Dam flow is above threshold
    
    Args:
        data: The API response data
        threshold: Minimum flow in m³/s (default 20)
        travel_time_minutes: Water travel time from dam to downstream (default 45)
    
    Returns:
        Dictionary with high flow hours for each day
    """
    if not data or 'elements' not in data:
        return None
    
    high_flow_schedule = {
        'threshold': threshold,
        'unit': 'm³/s',
        'travel_time_minutes': travel_time_minutes,
        'forecast_days': [],
        'timestamp': datetime.now().isoformat()
    }
    
    for day_data in data['elements']:
        day_num = day_data.get('day', 0)
        entries = day_data.get('entry', [])
        
        if not entries:
            continue
        
        # Extract date from first entry
        first_period = entries[0].get('period', '')
        date = first_period.split()[0] if first_period else 'Unknown'
        
        # Find all hours above threshold
        high_flow_hours = []
        
        for entry in entries:
            barrier_flow = entry.get('barrier', 0)
            period = entry.get('period', '')
            
            if barrier_flow >= threshold:
                # Extract just the hour from period (e.g., "2025-10-17 01" -> "01")
                hour = period.split()[-1] if period else ''
                
                # Calculate when water arrives downstream (add travel time)
                # Period format: "2025-10-17 01" means HE01 (00:00:01 to 01:00:00)
                # Water released at start of hour arrives 45 min later
                try:
                    date_str = period.split()[0]
                    hour_str = period.split()[1]
                    # HE hour means flow ENDS at that hour, so flow STARTS at hour-1
                    flow_start_hour = int(hour_str) - 1
                    if flow_start_hour < 0:
                        flow_start_hour = 0
                    
                    period_datetime = datetime.strptime(f"{date_str} {flow_start_hour:02d}:00", "%Y-%m-%d %H:%M")
                    arrival_datetime = period_datetime + timedelta(minutes=travel_time_minutes)
                    
                    arrival_time = arrival_datetime.strftime("%I:%M%p").lstrip('0').lower()
                    arrival_date = arrival_datetime.strftime("%Y-%m-%d")
                except:
                    arrival_time = "N/A"
                    arrival_date = date
                
                high_flow_hours.append({
                    'period': period,
                    'hour': hour,
                    'flow': barrier_flow,
                    'arrival_time': arrival_time,
                    'arrival_date': arrival_date
                })
        
        day_info = {
            'day': day_num,
            'date': date,
            'high_flow_hours': high_flow_hours,
            'total_hours': len(high_flow_hours),
            'all_hours': []
        }
        
        # Also store all hours with their flows for reference
        for entry in entries:
            day_info['all_hours'].append({
                'hour': entry.get('period', '').split()[-1],
                'flow': entry.get('barrier', 0)
            })
        
        high_flow_schedule['forecast_days'].append(day_info)
    
    return high_flow_schedule

def display_high_flow_schedule(schedule):
    """Display the high flow schedule in a readable format"""
    if not schedule:
        print("❌ No schedule data available")
        return
    
    print("=" * 80)
    print("🌊 KANANASKIS RIVER HIGH FLOW SCHEDULE")
    print("=" * 80)
    print(f"Threshold: ≥ {schedule['threshold']} {schedule['unit']} at Barrier Dam")
    print(f"Updated: {datetime.fromisoformat(schedule['timestamp']).strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"Water arrival times shown (+{schedule['travel_time_minutes']} min from dam to downstream)")
    print("=" * 80)
    
    for day_info in schedule['forecast_days']:
        day_num = day_info['day']
        date = day_info['date']
        total_hours = day_info['total_hours']
        high_flow_hours = day_info['high_flow_hours']
        
        print(f"\n📅 Day {day_num}: {date}")
        print("-" * 70)
        
        if total_hours == 0:
            print("   ⚠️  No high flow hours above threshold")
        else:
            print(f"   ✅ {total_hours} hours of high flow")
            print(f"\n   {'Hour':<10} {'Flow':<10} {'Water Arrives':<20} {'Period'}")
            print(f"   {'-'*10} {'-'*10} {'-'*20} {'-'*20}")
            
            for hour_data in high_flow_hours:
                hour = hour_data['hour']
                flow = hour_data['flow']
                period = hour_data['period']
                arrival = hour_data.get('arrival_time', 'N/A')
                
                # Add visual indicator for flow levels
                if flow >= 30:
                    indicator = "🌊🌊"
                elif flow >= 25:
                    indicator = "🌊 "
                else:
                    indicator = "💧 "
                
                print(f"   HE{hour:<8} {flow:<10} {arrival:<20} {period}  {indicator}")
            
            # Show the time range
            if high_flow_hours:
                first_arrival = high_flow_hours[0].get('arrival_time', 'N/A')
                last_arrival = high_flow_hours[-1].get('arrival_time', 'N/A')
                print(f"\n   🚣 Water arrives downstream: {first_arrival} to {last_arrival}")
                print(f"   ⏰ Dam release: HE{high_flow_hours[0]['hour']} to HE{high_flow_hours[-1]['hour']}")

def display_daily_summary(schedule):
    """Display a compact daily summary"""
    print("\n" + "=" * 80)
    print("📊 DAILY SUMMARY - Water Arrival Times Downstream")
    print("=" * 80)
    print(f"(+{schedule['travel_time_minutes']} min travel time from Barrier Dam)")
    
    print(f"\n{'Date':<15} {'Hours':<10} {'Water Arrives':<30} {'Dam Release'}")
    print(f"{'-'*15} {'-'*10} {'-'*30} {'-'*20}")
    
    for day_info in schedule['forecast_days']:
        date = day_info['date']
        total = day_info['total_hours']
        high_flow_hours = day_info['high_flow_hours']
        
        if total > 0:
            first_arrival = high_flow_hours[0].get('arrival_time', 'N/A')
            last_arrival = high_flow_hours[-1].get('arrival_time', 'N/A')
            arrival_range = f"{first_arrival} - {last_arrival}"
            
            first_hour = high_flow_hours[0]['hour']
            last_hour = high_flow_hours[-1]['hour']
            dam_range = f"HE{first_hour} - HE{last_hour}"
            
            hours_str = f"{total}h"
        else:
            hours_str = "None"
            arrival_range = "N/A"
            dam_range = "N/A"
        
        print(f"{date:<15} {hours_str:<10} {arrival_range:<30} {dam_range}")

def he_to_time_range(he):
    """
    Convert Hour Ending to readable time range
    HE01 = 00:00:01 to 01:00:00 = 12:00am-1:00am
    HE17 = 16:00:01 to 17:00:00 = 4:00pm-5:00pm
    """
    he_num = int(he)
    start_hour = he_num - 1
    end_hour = he_num
    
    # Convert to 12-hour format
    def to_12hr(hour):
        if hour == 0:
            return "12:00am"
        elif hour < 12:
            return f"{hour}:00am"
        elif hour == 12:
            return "12:00pm"
        elif hour == 24:
            return "12:00am"
        else:
            return f"{hour-12}:00pm"
    
    return f"{to_12hr(start_hour)}-{to_12hr(end_hour)}"

def create_simple_schedule(schedule):
    """Create a simple text schedule for easy sharing"""
    lines = []
    lines.append("🌊 KANANASKIS RIVER HIGH FLOW SCHEDULE")
    lines.append(f"Threshold: ≥ {schedule['threshold']} m³/s at Barrier Dam")
    lines.append(f"Water arrival times (+{schedule['travel_time_minutes']}min from dam)")
    lines.append("")
    
    for day_info in schedule['forecast_days']:
        date = day_info['date']
        high_flow_hours = day_info['high_flow_hours']
        
        if high_flow_hours:
            # Show water arrival times
            first_arrival = high_flow_hours[0].get('arrival_time', 'N/A')
            last_arrival = high_flow_hours[-1].get('arrival_time', 'N/A')
            
            lines.append(f"{date}: Water arrives {first_arrival} - {last_arrival}")
        else:
            lines.append(f"{date}: No high flow")
    
    return "\n".join(lines)

def save_to_json(schedule, filename='barrier_high_flow_schedule.json'):
    """Save schedule to JSON file"""
    if schedule:
        filepath = f"/Users/jeyzdfoo/Desktop/code/brownclaw/admin_scripts/{filename}"
        with open(filepath, 'w') as f:
            json.dump(schedule, f, indent=2)
        print(f"\n💾 Schedule saved to: {filename}")
        return filepath
    return None

def main():
    """Main function"""
    print("\n" + "=" * 80)
    print("🏔️  Barrier Dam High Flow Hour Extractor")
    print("=" * 80)
    print("Source: https://transalta.com/river-flows/\n")
    
    # Configuration
    THRESHOLD = 20  # m³/s - flows above this are considered "high"
    
    print(f"⚙️  Configuration:")
    print(f"   Threshold: ≥ {THRESHOLD} m³/s\n")
    
    # Fetch data
    print("📡 Fetching flow data...")
    data = fetch_transalta_flows()
    
    if not data:
        print("❌ Failed to fetch data")
        return
    
    print("✅ Data retrieved successfully\n")
    
    # Extract high flow hours
    print(f"🔍 Extracting hours with flow ≥ {THRESHOLD} m³/s...\n")
    schedule = extract_high_flow_hours(data, threshold=THRESHOLD)
    
    if not schedule:
        print("❌ Failed to extract schedule")
        return
    
    # Display results
    display_high_flow_schedule(schedule)
    display_daily_summary(schedule)
    
    # Create simple text version
    print("\n" + "=" * 80)
    print("📋 SIMPLE TEXT VERSION (for sharing)")
    print("=" * 80)
    print(create_simple_schedule(schedule))
    
    # Save to file
    save_to_json(schedule)
    
    # Paddling recommendations
    print("\n" + "=" * 80)
    print("🚣 PADDLING RECOMMENDATIONS")
    print("=" * 80)
    print(f"""
Based on flows ≥ {THRESHOLD} m³/s:

💧 20-25 m³/s: Good flow for intermediate paddlers
🌊 25-30 m³/s: Higher flow, more challenging
🌊 30+ m³/s:   High flow, advanced paddlers only

⏰ UNDERSTANDING HOUR ENDING (HE):
- HE01 = 00:00:01 to 01:00:00 (right after midnight to 1am)
- HE14 = 13:00:01 to 14:00:00 (1pm to 2pm)
- HE24 = 23:00:01 to 24:00:00 (11pm to midnight)
- Flow is for the ENTIRE hour period, not just the end

⚠️  SAFETY NOTES:
- Times shown include 45-minute travel time from dam to downstream
- Flows can change rapidly without notice
- Always check TransAlta website for latest updates before heading out
- Respect all safety signage and barriers around dam facilities
- When flow shows 0, the plant is offline/not generating
- High flows can create hazardous conditions
""")
    
    print(f"\n⏰ Completed at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 80)

if __name__ == "__main__":
    main()
