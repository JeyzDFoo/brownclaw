#!/usr/bin/env python3
"""
Explore TransAlta API for Kananaskis River Flow Information

TransAlta operates hydro facilities in Kananaskis:
- Barrier Dam
- Pocaterra Hydro Facility

This script attempts to find and test the API endpoints used by their 
river flows page: https://transalta.com/river-flows/
"""

import requests
import json
import time
from datetime import datetime
from bs4 import BeautifulSoup

# Headers to mimic a browser request
HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'application/json, text/plain, */*',
    'Accept-Language': 'en-US,en;q=0.9',
    'Referer': 'https://transalta.com/river-flows/',
    'Origin': 'https://transalta.com',
}

def fetch_river_flows_page():
    """Fetch the main river flows page and extract embedded data/scripts"""
    print("=" * 80)
    print("📄 Fetching TransAlta River Flows Page")
    print("=" * 80)
    
    url = "https://transalta.com/river-flows/"
    
    try:
        response = requests.get(url, headers=HEADERS, timeout=15)
        print(f"Status Code: {response.status_code}")
        
        if response.status_code == 200:
            # Parse HTML to find API endpoints or embedded data
            soup = BeautifulSoup(response.text, 'html.parser')
            
            # Look for script tags that might contain API URLs or data
            print("\n🔍 Searching for embedded JavaScript/JSON data...")
            
            scripts = soup.find_all('script')
            api_urls = []
            
            for i, script in enumerate(scripts):
                script_text = script.string if script.string else ""
                
                # Look for common API patterns
                if any(keyword in script_text for keyword in ['api', 'fetch', 'xhr', 'ajax', 'data', 'flow']):
                    # Extract potential URLs
                    import re
                    urls_found = re.findall(r'https?://[^\s<>"]+', script_text)
                    if urls_found:
                        print(f"\n   Script {i + 1}: Found {len(urls_found)} URLs")
                        for url in urls_found:
                            if 'transalta' in url or 'flow' in url.lower() or 'river' in url.lower():
                                print(f"      • {url}")
                                api_urls.append(url)
                
                # Look for embedded JSON data
                if 'json' in script_text.lower() or '{' in script_text:
                    # Try to extract JSON objects
                    try:
                        json_matches = re.findall(r'\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}', script_text)
                        for json_str in json_matches[:3]:  # Limit to first 3
                            if len(json_str) < 500 and ('flow' in json_str.lower() or 'barrier' in json_str.lower() or 'pocaterra' in json_str.lower()):
                                print(f"\n   Potential JSON data in script {i + 1}:")
                                print(f"      {json_str[:200]}...")
                    except:
                        pass
            
            # Look for data attributes
            print("\n🔍 Searching for data attributes...")
            elements_with_data = soup.find_all(attrs={'data-flow': True})
            elements_with_data.extend(soup.find_all(attrs={'data-api': True}))
            elements_with_data.extend(soup.find_all(attrs={'data-url': True}))
            
            for elem in elements_with_data:
                print(f"   Element: {elem.name}")
                for attr, value in elem.attrs.items():
                    if attr.startswith('data-'):
                        print(f"      {attr}: {value}")
            
            # Look for iframes that might load external data
            print("\n🔍 Searching for iframes...")
            iframes = soup.find_all('iframe')
            for iframe in iframes:
                src = iframe.get('src', '')
                if src:
                    print(f"   • {src}")
                    api_urls.append(src)
            
            return api_urls, response.text
        else:
            print(f"❌ Failed to fetch page: {response.status_code}")
            return [], None
            
    except Exception as e:
        print(f"❌ Error fetching page: {e}")
        return [], None

def try_common_api_patterns():
    """Try common API endpoint patterns for TransAlta"""
    print("\n" + "=" * 80)
    print("🧪 Testing Common API Patterns")
    print("=" * 80)
    
    # Common API patterns to try
    base_urls = [
        "https://transalta.com/api/river-flows",
        "https://transalta.com/api/riverflows",
        "https://transalta.com/api/flows",
        "https://transalta.com/wp-json/transalta/v1/river-flows",
        "https://transalta.com/wp-json/wp/v2/river-flows",
        "https://api.transalta.com/river-flows",
        "https://data.transalta.com/river-flows",
    ]
    
    facilities = ["barrier", "pocaterra", "kananaskis", "all"]
    
    for base_url in base_urls:
        print(f"\n📍 Testing: {base_url}")
        try:
            response = requests.get(base_url, headers=HEADERS, timeout=10)
            print(f"   Status: {response.status_code}")
            
            if response.status_code == 200:
                print("   ✅ SUCCESS!")
                print(f"   Response preview: {response.text[:300]}")
                
                # Try to parse as JSON
                try:
                    data = response.json()
                    print(f"   📊 JSON Response (keys): {list(data.keys())}")
                    return base_url, data
                except:
                    print("   ℹ️  Not JSON format")
            
            elif response.status_code == 404:
                print("   ❌ Not Found")
            else:
                print(f"   ⚠️  Status: {response.status_code}")
                
        except requests.exceptions.Timeout:
            print("   ⏱️  Timeout")
        except requests.exceptions.RequestException as e:
            print(f"   ❌ Error: {e}")
        
        # Try with facility parameters
        for facility in facilities:
            test_url = f"{base_url}/{facility}"
            try:
                response = requests.get(test_url, headers=HEADERS, timeout=5)
                if response.status_code == 200:
                    print(f"   ✅ SUCCESS with /{facility}: {response.status_code}")
                    print(f"   Response preview: {response.text[:200]}")
            except:
                pass

def check_network_requests():
    """Instructions for using browser developer tools"""
    print("\n" + "=" * 80)
    print("🔧 Manual Investigation Instructions")
    print("=" * 80)
    print("""
To find the actual API endpoint used by TransAlta:

1. Open https://transalta.com/river-flows/ in Chrome/Firefox
2. Open Developer Tools (F12 or Cmd+Option+I on Mac)
3. Go to the "Network" tab
4. Refresh the page
5. Look for XHR/Fetch requests that contain flow data
6. Filter by:
   - XHR
   - JSON
   - Keywords: "flow", "barrier", "pocaterra", "api"

7. Click on the request and check:
   - Request URL
   - Response data
   - Headers

Common patterns to look for:
- WordPress REST API: /wp-json/
- Custom API: /api/
- External services: Third-party data providers
- WebSocket connections for real-time data
""")

def explore_wateroffice_integration():
    """Check if TransAlta data might be available through Government of Canada APIs"""
    print("\n" + "=" * 80)
    print("🏛️  Checking Government of Canada Hydrometric Data")
    print("=" * 80)
    
    # Kananaskis area hydrometric stations
    kananaskis_stations = [
        {'id': '05BJ001', 'name': 'Kananaskis River Below Barrier Lake'},
        {'id': '05BJ004', 'name': 'Kananaskis River at Seebe'},
        {'id': '05BJ010', 'name': 'Barrier Lake near Seebe'},
        {'id': '05BH004', 'name': 'Bow River at Calgary (reference)'},
    ]
    
    print("\nKananaskis River stations that might show TransAlta operations impact:")
    
    for station in kananaskis_stations:
        print(f"\n🏷️  {station['name']} ({station['id']})")
        
        # Try the newer API
        url = f"https://api.weather.gc.ca/collections/hydrometric-realtime/items?STATION_NUMBER={station['id']}&limit=1&f=json"
        
        try:
            response = requests.get(url, timeout=10, headers={'User-Agent': 'BrownClaw/1.0'})
            
            if response.status_code == 200:
                data = response.json()
                
                if 'features' in data and data['features']:
                    feature = data['features'][0]
                    props = feature.get('properties', {})
                    
                    discharge = props.get('DISCHARGE')
                    level = props.get('LEVEL')
                    timestamp = props.get('DATETIME_LST', props.get('DATETIME', 'N/A'))
                    
                    print(f"   📅 Last Update: {timestamp}")
                    if discharge is not None:
                        print(f"   🌊 Discharge: {discharge} m³/s")
                    if level is not None:
                        print(f"   📏 Water Level: {level} m")
                    
                    print(f"   ✅ Data available from Government API")
                else:
                    print("   ⚠️  No recent data")
            else:
                print(f"   ❌ Status: {response.status_code}")
                
        except Exception as e:
            print(f"   ❌ Error: {e}")

def main():
    """Main exploration function"""
    print("\n" + "=" * 80)
    print("🌊 TransAlta Kananaskis River Flow API Explorer")
    print("=" * 80)
    print(f"⏰ Started at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    
    # Step 1: Fetch and analyze the main page
    api_urls, page_html = fetch_river_flows_page()
    
    if api_urls:
        print(f"\n✅ Found {len(api_urls)} potential API URLs to investigate")
        for url in api_urls:
            print(f"   • {url}")
    
    # Step 2: Try common API patterns
    try_common_api_patterns()
    
    # Step 3: Check Government data sources
    explore_wateroffice_integration()
    
    # Step 4: Provide manual investigation instructions
    check_network_requests()
    
    print("\n" + "=" * 80)
    print("📝 Summary")
    print("=" * 80)
    print("""
TransAlta's river flow page likely uses one of these approaches:
1. Custom API endpoint (needs browser dev tools to find)
2. Embedded data in the HTML/JavaScript
3. Third-party data service
4. Government of Canada hydrometric data

Next steps:
1. Use browser developer tools to capture the actual API calls
2. Check if data is embedded in page source
3. Use Government hydrometric stations for downstream impacts
4. Contact TransAlta for official API documentation
""")
    
    print(f"\n⏰ Completed at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

if __name__ == "__main__":
    main()
