#!/usr/bin/env python3
"""
Fetch TransAlta River Flow Data from API Endpoint

Found the API endpoint! The page uses:
$.getJSON('/river-flows/?get-riverflow-data=1', function(data) {...})

This script fetches the real-time flow data directly from that endpoint.
"""

import requests
import json
from datetime import datetime

# Headers to mimic a browser request
HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'application/json, text/javascript, */*; q=0.01',
    'Accept-Language': 'en-US,en;q=0.9',
    'Referer': 'https://transalta.com/river-flows/',
    'X-Requested-With': 'XMLHttpRequest',  # Important for AJAX requests
}

def fetch_transalta_flows():
    """Fetch real-time flow data from TransAlta API"""
    print("=" * 80)
    print("🌊 TransAlta Kananaskis River Flow Data")
    print("=" * 80)
    print(f"⏰ Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
    
    # The endpoint discovered from the JavaScript
    url = "https://transalta.com/river-flows/?get-riverflow-data=1"
    
    try:
        print(f"📡 Fetching data from: {url}")
        response = requests.get(url, headers=HEADERS, timeout=15)
        
        print(f"📊 HTTP Status: {response.status_code}\n")
        
        if response.status_code != 200:
            print(f"❌ Failed to fetch data")
            return None
        
        # Parse JSON response
        data = response.json()
        
        print("✅ Successfully retrieved flow data!\n")
        print("=" * 80)
        print("📋 RAW DATA STRUCTURE")
        print("=" * 80)
        print(json.dumps(data, indent=2))
        print("\n")
        
        # Parse and display the data in a user-friendly format
        display_flow_data(data)
        
        return data
        
    except json.JSONDecodeError as e:
        print(f"❌ Failed to parse JSON: {e}")
        print(f"Response text: {response.text[:500]}")
        return None
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
        return None

def display_flow_data(data):
    """Display flow data in a readable format"""
    print("=" * 80)
    print("📊 FORMATTED FLOW DATA")
    print("=" * 80)
    
    if 'elements' not in data:
        print("⚠️  Unexpected data structure")
        return
    
    elements = data['elements']
    
    # Display data for each day
    for day_idx, day_data in enumerate(elements):
        print(f"\n📅 DAY {day_idx} (Day {day_idx} forecast)")
        print("-" * 70)
        
        if 'entry' not in day_data:
            print("   ⚠️  No entries found")
            continue
        
        entries = day_data['entry']
        print(f"   Total entries: {len(entries)}")
        
        # Show first few entries as examples
        print(f"\n   {'Hour':<15} {'Barrier (m³/s)':<20} {'Pocaterra (m³/s)':<20}")
        print(f"   {'-'*15} {'-'*20} {'-'*20}")
        
        for i, entry in enumerate(entries[:10]):  # Show first 10 entries
            period = entry.get('period', 'N/A')
            barrier = entry.get('barrier', 0)
            pocaterra = entry.get('pocaterra', 0)
            
            print(f"   {period:<15} {barrier:<20} {pocaterra:<20}")
        
        if len(entries) > 10:
            print(f"   ... ({len(entries) - 10} more entries)")
        
        # Calculate statistics
        barrier_values = [float(e.get('barrier', 0)) for e in entries]
        pocaterra_values = [float(e.get('pocaterra', 0)) for e in entries]
        
        if barrier_values:
            print(f"\n   📊 Barrier Statistics:")
            print(f"      Min:  {min(barrier_values):.2f} m³/s")
            print(f"      Max:  {max(barrier_values):.2f} m³/s")
            print(f"      Avg:  {sum(barrier_values)/len(barrier_values):.2f} m³/s")
        
        if pocaterra_values:
            print(f"\n   📊 Pocaterra Statistics:")
            print(f"      Min:  {min(pocaterra_values):.2f} m³/s")
            print(f"      Max:  {max(pocaterra_values):.2f} m³/s")
            print(f"      Avg:  {sum(pocaterra_values)/len(pocaterra_values):.2f} m³/s")

def get_current_flows(data):
    """Extract current (most recent) flow values"""
    if not data or 'elements' not in data:
        return None
    
    elements = data['elements']
    
    if not elements or not elements[0].get('entry'):
        return None
    
    # Get the first entry of the first day (current)
    current = elements[0]['entry'][0]
    
    return {
        'timestamp': datetime.now().isoformat(),
        'period': current.get('period', 'N/A'),
        'barrier': {
            'flow': float(current.get('barrier', 0)),
            'unit': 'm³/s'
        },
        'pocaterra': {
            'flow': float(current.get('pocaterra', 0)),
            'unit': 'm³/s'
        }
    }

def save_to_json(data, filename='transalta_flows_live.json'):
    """Save data to JSON file"""
    if data:
        filepath = f"/Users/jeyzdfoo/Desktop/code/brownclaw/admin_scripts/{filename}"
        with open(filepath, 'w') as f:
            json.dump(data, f, indent=2)
        print(f"\n💾 Data saved to: {filename}")
        return filepath
    return None

def main():
    """Main function"""
    print("\n" + "=" * 80)
    print("🏔️  TransAlta Kananaskis River Flow Fetcher")
    print("=" * 80)
    print("Source: https://transalta.com/river-flows/\n")
    
    # Fetch the data
    data = fetch_transalta_flows()
    
    if data:
        # Save raw data
        save_to_json(data, 'transalta_flows_raw.json')
        
        # Get and save current flows
        current = get_current_flows(data)
        if current:
            save_to_json(current, 'transalta_flows_current.json')
            
            print("\n" + "=" * 80)
            print("🎯 CURRENT FLOWS")
            print("=" * 80)
            print(f"\n📅 Period: {current['period']}")
            print(f"🏭 Barrier Dam:     {current['barrier']['flow']:.2f} {current['barrier']['unit']}")
            print(f"🏭 Pocaterra:       {current['pocaterra']['flow']:.2f} {current['pocaterra']['unit']}")
            
            # Provide context for whitewater paddlers
            barrier_flow = current['barrier']['flow']
            print(f"\n💧 Flow Context:")
            if barrier_flow == 0:
                print("   ⚠️  Facility offline or not generating")
            elif barrier_flow < 5:
                print("   📉 Very low flow")
            elif barrier_flow < 15:
                print("   💧 Low to moderate flow")
            elif barrier_flow < 30:
                print("   🌊 Moderate to high flow")
            else:
                print("   🌊🌊 High flow!")
        
        print("\n✅ Success! Flow data retrieved and saved.")
    else:
        print("\n❌ Failed to retrieve flow data")
    
    print(f"\n⏰ Completed at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 80)

if __name__ == "__main__":
    main()
