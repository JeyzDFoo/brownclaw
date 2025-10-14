#!/usr/bin/env python3
"""
Extract real-time data from the working web report URL
"""

import requests
import re
from datetime import datetime

def extract_flow_data_from_report():
    """Extract flow data from the working web report URL"""
    station_id = '08NA011'
    url = f'https://wateroffice.ec.gc.ca/report/real_time_e.html?mode=Table&type=realTime&prm1=47&prm2=-1&stn={station_id}'
    
    print(f"🔍 Extracting data from working URL:")
    print(f"   {url}")
    print()
    
    try:
        response = requests.get(url, timeout=15)
        
        if response.status_code == 200:
            html_content = response.text
            print(f"✅ Got HTML response ({len(html_content)} characters)")
            
            # Look for flow data in the HTML
            # The data is likely in a table format
            
            # Search for discharge/flow values
            flow_patterns = [
                r'(\d+\.\d+)\s*m³/s',  # Flow rate in m³/s
                r'(\d+\.\d+)\s*cubic metres per second',
                r'>(\d+\.\d+)</td>.*?m³/s',  # Table cell with flow
                r'Discharge.*?(\d+\.\d+)',  # Discharge label followed by number
            ]
            
            # Search for recent timestamps
            time_patterns = [
                r'(\d{4}-\d{2}-\d{2} \d{2}:\d{2})',  # YYYY-MM-DD HH:MM
                r'(\d{2}/\d{2}/\d{4} \d{2}:\d{2})',  # MM/DD/YYYY HH:MM
                r'Oct\s+\d{1,2},?\s+\d{4}.*?\d{1,2}:\d{2}',  # Oct 14, 2024 14:30
            ]
            
            print("🔍 Searching for flow data patterns...")
            
            flows_found = []
            for pattern in flow_patterns:
                matches = re.findall(pattern, html_content, re.IGNORECASE)
                if matches:
                    print(f"   Pattern '{pattern}' found: {matches}")
                    flows_found.extend(matches)
            
            print("\n🔍 Searching for timestamp patterns...")
            times_found = []
            for pattern in time_patterns:
                matches = re.findall(pattern, html_content)
                if matches:
                    print(f"   Pattern '{pattern}' found: {matches[:3]}...")  # Show first 3
                    times_found.extend(matches[:3])
            
            # Look for table data specifically
            print("\n🔍 Looking for HTML table data...")
            table_pattern = r'<td[^>]*>([^<]+)</td>'
            table_cells = re.findall(table_pattern, html_content)
            
            numeric_cells = []
            for cell in table_cells:
                cell = cell.strip()
                if re.match(r'^\d+\.?\d*$', cell):  # Numbers
                    try:
                        num = float(cell)
                        if 0.1 < num < 1000:  # Reasonable flow range
                            numeric_cells.append(num)
                    except:
                        pass
            
            if numeric_cells:
                print(f"   Found numeric values in table: {numeric_cells[:10]}...")
            
            # Look for the station name to confirm we have the right data
            if 'SPILLIMACHEEN' in html_content.upper():
                print("✅ Confirmed: Data is for Spillimacheen River station")
            
            # Extract some sample content to see the structure
            print("\n📋 Sample HTML content (first 500 chars):")
            print(html_content[:500])
            
            print("\n📋 Sample HTML content (around 'flow' or 'discharge'):")
            for keyword in ['flow', 'discharge', 'débit']:
                idx = html_content.lower().find(keyword)
                if idx > 0:
                    print(f"   Around '{keyword}':")
                    print(f"   {html_content[max(0, idx-100):idx+200]}")
                    break
            
            # Try to find the most recent flow value
            if flows_found:
                latest_flow = flows_found[-1]  # Assume last one is most recent
                print(f"\n🎯 EXTRACTED FLOW DATA:")
                print(f"   Latest flow rate: {latest_flow} m³/s")
                print(f"   Station: {station_id} - Spillimacheen River")
                print(f"   Extraction time: {datetime.now().strftime('%H:%M:%S')}")
                return float(latest_flow)
            
            elif numeric_cells:
                # Take a reasonable flow value from the numeric cells
                reasonable_flows = [x for x in numeric_cells if 1 < x < 200]
                if reasonable_flows:
                    latest_flow = reasonable_flows[-1]
                    print(f"\n🎯 EXTRACTED FLOW DATA (from table):")
                    print(f"   Estimated flow rate: {latest_flow} m³/s")
                    print(f"   Station: {station_id} - Spillimacheen River") 
                    print(f"   Extraction time: {datetime.now().strftime('%H:%M:%S')}")
                    return latest_flow
                    
        else:
            print(f"❌ HTTP {response.status_code}")
            
    except Exception as e:
        print(f"❌ Error: {e}")
    
    print("⚠️  Could not extract flow data")
    return None

def main():
    print("🧪 Extracting Real-Time Flow Data for 08NA011")
    print(f"📅 {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 60)
    
    flow_rate = extract_flow_data_from_report()
    
    print("\n" + "=" * 60)
    if flow_rate:
        print("🎉 SUCCESS! We can extract live data from the web report!")
        print(f"💧 Current flow: {flow_rate} m³/s")
        print("✅ We can now update the Flutter app to use this method!")
    else:
        print("⚠️  Need to refine extraction method")
        print("💡 The data is there, we just need to parse it correctly")

if __name__ == "__main__":
    main()