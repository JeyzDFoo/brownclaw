#!/usr/bin/env python3
"""
Extract TransAlta River Flow Data from Embedded JavaScript

The TransAlta website embeds flow data in JavaScript variables that are then
used to populate the tables dynamically. This script extracts that data.

Website: https://transalta.com/river-flows/
"""

import requests
from bs4 import BeautifulSoup
from datetime import datetime
import json
import re

# Headers to mimic a browser request
HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
}

def extract_transalta_data():
    """Extract flow data from TransAlta's embedded JavaScript"""
    print("=" * 80)
    print("🌊 Extracting TransAlta Kananaskis River Flow Data")
    print("=" * 80)
    print(f"⏰ Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
    
    url = "https://transalta.com/river-flows/"
    
    try:
        response = requests.get(url, headers=HEADERS, timeout=15)
        print(f"📡 HTTP Status: {response.status_code}\n")
        
        if response.status_code != 200:
            print(f"❌ Failed to fetch page")
            return None
        
        soup = BeautifulSoup(response.text, 'html.parser')
        
        # Find all script tags
        scripts = soup.find_all('script')
        
        print("🔍 Searching for embedded flow data...\n")
        
        flow_data = {
            'timestamp': datetime.now().isoformat(),
            'source': url,
            'facilities': {},
            'forecast': []
        }
        
        for i, script in enumerate(scripts):
            script_text = script.string if script.string else ""
            
            if not script_text:
                continue
            
            # Look for the allData variable or similar data structures
            if 'barrier' in script_text.lower() and 'pocaterra' in script_text.lower():
                print(f"📜 Found relevant script (Script {i + 1}):")
                print("-" * 70)
                
                # Try to extract JSON data embedded in the script
                # Look for patterns like: var data = {...}; or allData = {...};
                
                # Pattern 1: Look for object literals
                json_pattern = r'(?:var|let|const)?\s*(?:allData|data|flowData)\s*=\s*(\[[\s\S]*?\]);'
                matches = re.findall(json_pattern, script_text, re.MULTILINE)
                
                if matches:
                    print(f"✅ Found {len(matches)} data structure(s)\n")
                    
                    for j, match in enumerate(matches):
                        print(f"Data Structure {j + 1}:")
                        try:
                            # Try to parse as JSON
                            data = json.loads(match)
                            print(json.dumps(data, indent=2))
                            
                            # Parse the data structure
                            if isinstance(data, list):
                                for day_idx, day_data in enumerate(data):
                                    print(f"\n   📅 Day {day_idx}:")
                                    
                                    if isinstance(day_data, dict):
                                        # Check for entries
                                        if 'entry' in day_data:
                                            entries = day_data['entry']
                                            print(f"      Found {len(entries)} hourly entries")
                                            
                                            for entry in entries[:3]:  # Show first 3 as examples
                                                period = entry.get('period', 'N/A')
                                                barrier = entry.get('barrier', 'N/A')
                                                pocaterra = entry.get('pocaterra', 'N/A')
                                                
                                                print(f"         {period}: Barrier={barrier} m³/s, Pocaterra={pocaterra} m³/s")
                                        
                                        # Store in our data structure
                                        if day_idx == 0:  # Current day
                                            if 'entry' in day_data and day_data['entry']:
                                                latest = day_data['entry'][0]
                                                flow_data['facilities']['Barrier'] = {
                                                    'flow': latest.get('barrier', 0),
                                                    'unit': 'm³/s',
                                                    'period': latest.get('period', 'N/A')
                                                }
                                                flow_data['facilities']['Pocaterra'] = {
                                                    'flow': latest.get('pocaterra', 0),
                                                    'unit': 'm³/s',
                                                    'period': latest.get('period', 'N/A')
                                                }
                                        
                                        # Add to forecast
                                        flow_data['forecast'].append({
                                            'day': day_idx,
                                            'data': day_data
                                        })
                            
                            return flow_data
                            
                        except json.JSONDecodeError as e:
                            print(f"⚠️  Could not parse as JSON: {e}")
                            print(f"Raw data (first 500 chars):\n{match[:500]}\n")
                
                # Pattern 2: Look for simpler assignments
                # Try to find lines with barrier and pocaterra values
                lines_with_data = [line for line in script_text.split('\n') 
                                  if 'barrier' in line.lower() or 'pocaterra' in line.lower()]
                
                if lines_with_data:
                    print("\n📋 Lines with flow data references:")
                    for line in lines_with_data[:10]:  # Show first 10
                        line = line.strip()
                        if line and len(line) < 200:
                            print(f"   {line}")
                
                # Pattern 3: Extract from form.elements or similar
                elements_pattern = r'(?:form|object)\.elements\s*=\s*(\{[\s\S]*?\});'
                elements_matches = re.findall(elements_pattern, script_text)
                
                if elements_matches:
                    print(f"\n✅ Found elements structure")
                    for match in elements_matches:
                        try:
                            data = json.loads(match)
                            print(json.dumps(data, indent=2))
                        except:
                            print(f"Raw (first 500 chars): {match[:500]}")
                
                print("\n" + "=" * 70 + "\n")
        
        # If we didn't find structured data, try to extract from the raw HTML
        if not flow_data['facilities']:
            print("⚠️  No structured data found. Trying alternative extraction...\n")
            
            # Look for specific patterns in the entire page source
            page_text = response.text
            
            # Pattern: Looking for direct assignments like barrier = "XX.X"
            barrier_pattern = r'barrier["\s]*[:=]["\s]*([0-9.]+)'
            pocaterra_pattern = r'pocaterra["\s]*[:=]["\s]*([0-9.]+)'
            
            barrier_matches = re.findall(barrier_pattern, page_text, re.IGNORECASE)
            pocaterra_matches = re.findall(pocaterra_pattern, page_text, re.IGNORECASE)
            
            if barrier_matches:
                print(f"🔍 Found Barrier flow values: {barrier_matches}")
            if pocaterra_matches:
                print(f"🔍 Found Pocaterra flow values: {pocaterra_matches}")
        
        return flow_data
        
    except Exception as e:
        print(f"\n❌ Error extracting data: {e}")
        import traceback
        traceback.print_exc()
        return None

def save_to_json(data, filename='transalta_flows_extracted.json'):
    """Save extracted data to JSON file"""
    if data:
        filepath = f"/Users/jeyzdfoo/Desktop/code/brownclaw/admin_scripts/{filename}"
        with open(filepath, 'w') as f:
            json.dump(data, f, indent=2)
        print(f"\n💾 Data saved to {filepath}")
        return filepath
    return None

def display_summary(data):
    """Display a summary of the extracted data"""
    if not data:
        return
    
    print("\n" + "=" * 80)
    print("📊 EXTRACTED DATA SUMMARY")
    print("=" * 80)
    
    if data.get('facilities'):
        print("\n🏭 CURRENT FLOWS:")
        for facility, info in data['facilities'].items():
            flow = info.get('flow', 'N/A')
            unit = info.get('unit', '')
            period = info.get('period', 'N/A')
            print(f"   {facility:12s}: {flow} {unit} @ {period}")
    else:
        print("\n⚠️  No current flow data extracted")
    
    if data.get('forecast'):
        print(f"\n📅 FORECAST DATA: {len(data['forecast'])} days available")
    
    print("\n" + "=" * 80)

def main():
    """Main function"""
    print("\n" + "=" * 80)
    print("🏔️  TransAlta Kananaskis River Flow Data Extractor")
    print("=" * 80)
    
    data = extract_transalta_data()
    
    if data:
        display_summary(data)
        json_file = save_to_json(data)
        
        if json_file:
            print(f"\n✅ Success! Flow data has been extracted.")
    else:
        print("\n❌ Failed to extract flow data")
        print("\nℹ️  The website may load data dynamically with JavaScript after page load.")
        print("   Consider using Selenium or Playwright to render the JavaScript first.")
    
    print(f"\n⏰ Completed at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

if __name__ == "__main__":
    main()
