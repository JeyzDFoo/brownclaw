#!/usr/bin/env python3
"""
Extract real flow data from Spillimacheen station HTML response
We found the station returns HTML data - let's parse it for actual values
"""

import requests
import re
from datetime import datetime
from bs4 import BeautifulSoup

def extract_spillimacheen_data():
    """Extract actual flow data from the HTML response"""
    station_id = '08NA011'
    
    # This URL works and returns HTML with station data
    url = f'https://wateroffice.ec.gc.ca/report/real_time_e.html?prm1=47&stn={station_id}'
    
    print(f"🔍 Extracting data from working HTML endpoint:")
    print(f"   URL: {url}")
    print("=" * 60)
    
    try:
        response = requests.get(url, timeout=15)
        
        if response.status_code == 200:
            html = response.text
            print(f"✅ Got HTML response ({len(html)} characters)")
            
            # Try BeautifulSoup for proper parsing
            try:
                soup = BeautifulSoup(html, 'html.parser')
                print("✅ HTML parsed successfully")
                
                # Look for table data
                tables = soup.find_all('table')
                print(f"📊 Found {len(tables)} tables")
                
                flow_data = []
                timestamps = []
                
                for i, table in enumerate(tables):
                    print(f"\n🔍 Examining table {i+1}:")
                    
                    # Get all rows
                    rows = table.find_all('tr')
                    print(f"   Rows: {len(rows)}")
                    
                    # Check headers
                    headers = []
                    if rows:
                        header_row = rows[0]
                        header_cells = header_row.find_all(['th', 'td'])
                        headers = [cell.get_text().strip() for cell in header_cells]
                        print(f"   Headers: {headers}")
                    
                    # Look for data rows
                    for row_idx, row in enumerate(rows[1:], 1):
                        cells = row.find_all(['td', 'th'])
                        cell_texts = [cell.get_text().strip() for cell in cells]
                        
                        if cell_texts:
                            print(f"   Row {row_idx}: {cell_texts}")
                            
                            # Look for flow values
                            for cell_text in cell_texts:
                                # Check if it's a flow rate
                                flow_match = re.match(r'^(\d+\.?\d*)$', cell_text)
                                if flow_match:
                                    try:
                                        flow_value = float(flow_match.group(1))
                                        if 0.1 <= flow_value <= 1000:  # Reasonable range
                                            flow_data.append(flow_value)
                                            print(f"   💧 Found flow: {flow_value} m³/s")
                                    except:
                                        pass
                                
                                # Check if it's a timestamp
                                time_patterns = [
                                    r'\d{4}-\d{2}-\d{2}[\s\w]*\d{2}:\d{2}',
                                    r'\d{2}/\d{2}/\d{4}[\s\w]*\d{2}:\d{2}',
                                    r'(Oct|Nov|Dec|Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep)[\s\w]*\d{1,2}[\s\w]*\d{4}[\s\w]*\d{2}:\d{2}'
                                ]
                                
                                for pattern in time_patterns:
                                    if re.search(pattern, cell_text, re.IGNORECASE):
                                        timestamps.append(cell_text)
                                        print(f"   ⏰ Found timestamp: {cell_text}")
                
                # Also check for any text that mentions "no data" or similar
                page_text = soup.get_text().lower()
                
                if 'no data' in page_text or 'not available' in page_text:
                    print("⚠️  Page contains 'no data' or 'not available' messages")
                
                if 'spillimacheen' in page_text:
                    print("✅ Page confirms this is Spillimacheen River data")
                
                # Look for any embedded JavaScript data
                scripts = soup.find_all('script')
                for script in scripts:
                    if script.string:
                        script_content = script.string
                        # Look for data arrays or objects
                        js_data_pattern = r'data\s*[:=]\s*\[([^\]]+)\]'
                        matches = re.findall(js_data_pattern, script_content)
                        if matches:
                            print(f"📊 Found JS data arrays: {matches}")
                
                # Summary
                print(f"\n📈 EXTRACTION RESULTS:")
                print(f"   Flow values found: {len(flow_data)}")
                print(f"   Timestamps found: {len(timestamps)}")
                
                if flow_data:
                    latest_flow = flow_data[-1]
                    print(f"   🎯 Latest flow: {latest_flow} m³/s")
                    print(f"   📊 All flows: {flow_data}")
                    
                    if timestamps:
                        print(f"   ⏰ Latest time: {timestamps[-1]}")
                    
                    return latest_flow, timestamps[-1] if timestamps else None
                else:
                    print("   ❌ No flow data extracted")
                    
                    # Show some raw content for debugging
                    print(f"\n📄 Sample page content (first 500 chars):")
                    print(page_text[:500])
                
            except Exception as e:
                print(f"❌ BeautifulSoup parsing failed: {e}")
                print("Falling back to regex parsing...")
                
                # Fallback: regex parsing of raw HTML
                return parse_html_with_regex(html)
                
        else:
            print(f"❌ HTTP {response.status_code}")
            
    except Exception as e:
        print(f"❌ Request failed: {e}")
    
    return None, None

def parse_html_with_regex(html):
    """Fallback parsing using regex"""
    print("🔍 Parsing HTML with regex patterns...")
    
    # Look for table data patterns
    table_cell_pattern = r'<td[^>]*>([^<]+)</td>'
    cells = re.findall(table_cell_pattern, html)
    
    print(f"📊 Found {len(cells)} table cells")
    
    flow_values = []
    for cell in cells:
        cell = cell.strip()
        # Look for numeric values that could be flow rates
        if re.match(r'^\d+\.?\d*$', cell):
            try:
                value = float(cell)
                if 0.1 <= value <= 1000:
                    flow_values.append(value)
                    print(f"💧 Potential flow: {value}")
            except:
                pass
    
    if flow_values:
        return flow_values[-1], datetime.now().strftime('%Y-%m-%d %H:%M')
    
    return None, None

def main():
    print("🧪 SPILLIMACHEEN DATA EXTRACTION")
    print(f"📅 {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print()
    
    flow, timestamp = extract_spillimacheen_data()
    
    print("\n" + "=" * 60)
    if flow:
        print("🎉 SUCCESS! Extracted live data from Spillimacheen station!")
        print(f"💧 Flow rate: {flow} m³/s")
        print(f"⏰ Timestamp: {timestamp}")
        print()
        print("✅ We can now implement this HTML parsing method in Flutter!")
        print("🔧 Next step: Update LiveWaterDataService to parse HTML for 08NA011")
    else:
        print("⚠️  Could not extract flow data")
        print("💡 The station page exists but data extraction needs refinement")
        print("🔍 Manual inspection of the HTML might be needed")

if __name__ == "__main__":
    main()