#!/usr/bin/env python3
"""
Scrape TransAlta River Flow Data from Website

This script extracts flow data directly from the TransAlta river flows page
without relying on an API endpoint. It parses the HTML tables to get current
and forecasted flow data for the Barrier and Pocaterra facilities.

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

def scrape_transalta_flows():
    """Scrape flow data from TransAlta's river flows page"""
    print("=" * 80)
    print("🌊 Scraping TransAlta Kananaskis River Flow Data")
    print("=" * 80)
    print(f"⏰ Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
    
    url = "https://transalta.com/river-flows/"
    
    try:
        response = requests.get(url, headers=HEADERS, timeout=15)
        print(f"📡 HTTP Status: {response.status_code}")
        
        if response.status_code != 200:
            print(f"❌ Failed to fetch page")
            return None
        
        soup = BeautifulSoup(response.text, 'html.parser')
        
        # Extract all flow data
        flow_data = {
            'timestamp': datetime.now().isoformat(),
            'source': url,
            'facilities': {}
        }
        
        # Look for tables containing flow information
        print("\n🔍 Searching for flow data tables...")
        tables = soup.find_all('table')
        print(f"   Found {len(tables)} tables on page\n")
        
        for i, table in enumerate(tables):
            print(f"📊 Table {i + 1}:")
            print("   " + "-" * 70)
            
            # Extract table headers
            headers = []
            header_row = table.find('thead')
            if header_row:
                headers = [th.get_text(strip=True) for th in header_row.find_all(['th', 'td'])]
            else:
                # Try to find headers in first row
                first_row = table.find('tr')
                if first_row:
                    headers = [th.get_text(strip=True) for th in first_row.find_all(['th', 'td'])]
            
            if headers:
                print(f"   Headers: {headers}")
            
            # Extract table rows
            rows = table.find_all('tr')
            table_data = []
            
            for row in rows[1:] if headers else rows:  # Skip header row if we found headers
                cells = row.find_all(['td', 'th'])
                row_data = [cell.get_text(strip=True) for cell in cells]
                
                if row_data and any(row_data):  # Only add non-empty rows
                    table_data.append(row_data)
                    
                    # Print the row
                    row_str = " | ".join(row_data)
                    print(f"   {row_str}")
                    
                    # Try to identify facility and flow data
                    for cell in row_data:
                        # Look for facility names
                        if 'barrier' in cell.lower():
                            facility_name = 'Barrier'
                            print(f"      ✓ Found facility: {facility_name}")
                        elif 'pocaterra' in cell.lower():
                            facility_name = 'Pocaterra'
                            print(f"      ✓ Found facility: {facility_name}")
                        
                        # Look for numeric values (potential flow rates)
                        numbers = re.findall(r'\d+\.?\d*', cell)
                        if numbers:
                            for num in numbers:
                                try:
                                    flow_value = float(num)
                                    if 0 < flow_value < 1000:  # Reasonable flow range
                                        print(f"      → Potential flow: {flow_value} m³/s")
                                except ValueError:
                                    pass
            
            print()  # Blank line between tables
        
        # Look for divs or other elements that might contain flow data
        print("\n🔍 Searching for other data containers...")
        
        # Look for elements with common class names
        data_containers = soup.find_all(['div', 'span', 'p'], class_=re.compile(r'flow|data|river|discharge', re.I))
        
        for container in data_containers[:10]:  # Limit to first 10
            text = container.get_text(strip=True)
            if text and len(text) < 200:  # Only show reasonably short text
                print(f"   📦 {container.name}.{container.get('class', [''])[0]}: {text}")
                
                # Extract numbers
                numbers = re.findall(r'\d+\.?\d*', text)
                if numbers and any(keyword in text.lower() for keyword in ['cms', 'flow', 'discharge', 'barrier', 'pocaterra']):
                    print(f"      → Contains numbers: {numbers}")
        
        # Look for script tags with embedded data
        print("\n\n🔍 Searching for embedded JSON/JavaScript data...")
        scripts = soup.find_all('script')
        
        for i, script in enumerate(scripts):
            script_text = script.string if script.string else ""
            
            # Look for JSON data structures
            if script_text and any(keyword in script_text.lower() for keyword in ['barrier', 'pocaterra', 'flow', 'discharge']):
                print(f"\n   📜 Script {i + 1} contains relevant keywords:")
                
                # Try to find JSON objects
                json_matches = re.findall(r'\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}', script_text)
                
                for j, json_str in enumerate(json_matches[:3]):  # Limit to first 3
                    if any(keyword in json_str.lower() for keyword in ['barrier', 'pocaterra', 'flow']):
                        print(f"\n      JSON Object {j + 1}:")
                        try:
                            # Try to parse it
                            parsed = json.loads(json_str)
                            print(f"      {json.dumps(parsed, indent=6)}")
                        except:
                            # Just show the raw string
                            if len(json_str) < 500:
                                print(f"      {json_str}")
                            else:
                                print(f"      {json_str[:500]}...")
                
                # Look for variable assignments with flow data
                var_matches = re.findall(r'(var|let|const)\s+(\w+)\s*=\s*([^;]+);', script_text)
                for var_type, var_name, var_value in var_matches:
                    if any(keyword in var_name.lower() for keyword in ['flow', 'barrier', 'pocaterra', 'data']):
                        print(f"\n      Variable: {var_name}")
                        print(f"      Value: {var_value[:200]}")
        
        # Look for data attributes
        print("\n\n🔍 Searching for data attributes...")
        elements_with_data = soup.find_all(attrs=lambda attrs: attrs and any(k.startswith('data-') for k in attrs.keys()))
        
        for elem in elements_with_data[:20]:  # Limit to first 20
            data_attrs = {k: v for k, v in elem.attrs.items() if k.startswith('data-')}
            if data_attrs:
                relevant = False
                for key, value in data_attrs.items():
                    if any(keyword in str(value).lower() for keyword in ['flow', 'barrier', 'pocaterra', 'discharge']):
                        relevant = True
                        break
                
                if relevant:
                    print(f"\n   {elem.name}:")
                    for key, value in data_attrs.items():
                        print(f"      {key}: {value}")
        
        return flow_data
        
    except Exception as e:
        print(f"\n❌ Error scraping data: {e}")
        import traceback
        traceback.print_exc()
        return None

def extract_flow_values(text):
    """Extract flow values from text"""
    # Look for patterns like "X.X cms" or "X.X m³/s"
    patterns = [
        r'(\d+\.?\d*)\s*cms',
        r'(\d+\.?\d*)\s*m³/s',
        r'(\d+\.?\d*)\s*cubic\s+meters',
    ]
    
    for pattern in patterns:
        matches = re.findall(pattern, text, re.IGNORECASE)
        if matches:
            return [float(m) for m in matches]
    
    return []

def save_to_json(data, filename='transalta_flows.json'):
    """Save scraped data to JSON file"""
    if data:
        with open(filename, 'w') as f:
            json.dump(data, f, indent=2)
        print(f"\n💾 Data saved to {filename}")

def main():
    """Main function"""
    print("\n" + "=" * 80)
    print("🏔️  TransAlta Kananaskis River Flow Scraper")
    print("=" * 80)
    
    flow_data = scrape_transalta_flows()
    
    if flow_data:
        save_to_json(flow_data)
    
    print("\n" + "=" * 80)
    print("📝 Summary")
    print("=" * 80)
    print("""
The script has analyzed the TransAlta river flows page structure.

If the data is visible in tables on the website, this script will extract it.
If the data is loaded dynamically via JavaScript after page load, you may need:
1. Selenium or Playwright to render JavaScript
2. Find the actual API endpoint (using browser DevTools)
3. Contact TransAlta for official API access

Next steps:
1. Check the output above for any extracted flow data
2. If no data found, use browser DevTools to inspect the live page
3. Look for XHR/Fetch requests in the Network tab
4. The data might be loaded asynchronously after the page loads
""")
    
    print(f"\n⏰ Completed at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

if __name__ == "__main__":
    main()
