#!/usr/bin/env python3
"""
Deep investigation into why Spillimacheen (08NA011) shows online but isn't in APIs
Let's find the REAL endpoint the website uses
"""

import requests
from datetime import datetime
import re

def investigate_website_endpoints():
    """Try to find what endpoints the website actually uses"""
    station_id = '08NA011'
    
    print("🔍 DEEP INVESTIGATION: Spillimacheen River Station")
    print("=" * 60)
    print(f"🎯 Target: {station_id} - Shows ONLINE on website")
    print(f"❌ Problem: Not appearing in JSON API")
    print(f"🤔 Question: What endpoint does the website actually use?")
    print()
    
    # Try to access the station's direct page
    station_urls = [
        f'https://wateroffice.ec.gc.ca/real_time_data/station_report_e.html?station={station_id}',
        f'https://wateroffice.ec.gc.ca/report/real_time_e.html?station={station_id}',
        f'https://wateroffice.ec.gc.ca/station_search/station_search_e.html?search_type=station_number&station_number={station_id}',
        f'https://wateroffice.ec.gc.ca/mainmenu/real_time_data_index_e.html?station={station_id}',
    ]
    
    print("🌐 Trying to access station web pages...")
    
    for url in station_urls:
        try:
            print(f"\n📡 Testing: {url}")
            response = requests.get(url, timeout=10)
            print(f"   Status: {response.status_code}")
            
            if response.status_code == 200:
                content = response.text
                print(f"   Content length: {len(content)} chars")
                
                # Look for API calls or data endpoints in the HTML
                api_patterns = [
                    r'ajax[^"\']*["\']([^"\']*csv[^"\']*)',
                    r'fetch[^"\']*["\']([^"\']*api[^"\']*)',
                    r'XMLHttpRequest[^"\']*["\']([^"\']*)',
                    r'services/[^"\']*',
                    r'api\.[^"\']*',
                    r'real_time_data[^"\']*',
                ]
                
                print("   🔍 Looking for API endpoints in HTML...")
                endpoints_found = set()
                
                for pattern in api_patterns:
                    matches = re.findall(pattern, content, re.IGNORECASE)
                    for match in matches:
                        if match and len(match) > 10:
                            endpoints_found.add(match)
                
                if endpoints_found:
                    print("   📍 Found potential endpoints:")
                    for endpoint in list(endpoints_found)[:5]:
                        print(f"      {endpoint}")
                
                # Look for JavaScript files that might contain API calls
                js_pattern = r'<script[^>]*src=["\']([^"\']*\.js[^"\']*)["\']'
                js_files = re.findall(js_pattern, content)
                
                if js_files:
                    print("   📜 Found JavaScript files:")
                    for js_file in js_files[:3]:
                        if not js_file.startswith('http'):
                            js_file = 'https://wateroffice.ec.gc.ca' + js_file
                        print(f"      {js_file}")
                        
                        # Try to fetch and examine JS file for API endpoints
                        try:
                            js_response = requests.get(js_file, timeout=5)
                            if js_response.status_code == 200:
                                js_content = js_response.text
                                
                                # Look for API URLs in JavaScript
                                api_in_js = re.findall(r'["\']https?://[^"\']*(?:api|service|csv|json)[^"\']*["\']', js_content)
                                if api_in_js:
                                    print(f"      📍 APIs in {js_file}:")
                                    for api_url in api_in_js[:3]:
                                        print(f"         {api_url.strip('\"\'')}")
                        except:
                            pass
                
                # Check if station data is embedded in the page
                if station_id in content:
                    print(f"   ✅ Station {station_id} found in page content!")
                    
                    # Look for flow/discharge data
                    flow_patterns = [
                        r'(\d+\.?\d*)\s*m³/s',
                        r'discharge[^>]*>([^<]*\d+[^<]*)',
                        r'flow[^>]*>([^<]*\d+[^<]*)',
                    ]
                    
                    for pattern in flow_patterns:
                        matches = re.findall(pattern, content, re.IGNORECASE)
                        if matches:
                            print(f"   💧 Found flow data: {matches[:3]}")
                
                return True, url, content
                
        except Exception as e:
            print(f"   ❌ Error: {e}")
    
    return False, None, None

def test_undocumented_endpoints():
    """Test various undocumented endpoint patterns"""
    station_id = '08NA011'
    
    print("\n🔬 Testing undocumented API patterns...")
    
    # Based on common government API patterns
    test_endpoints = [
        f'https://wateroffice.ec.gc.ca/services/real_time/{station_id}.json',
        f'https://wateroffice.ec.gc.ca/api/stations/{station_id}/realtime',
        f'https://wateroffice.ec.gc.ca/data/realtime/{station_id}',
        f'https://wateroffice.ec.gc.ca/services/station/{station_id}/data',
        f'https://dd.weather.gc.ca/hydrometric/realtime/{station_id}.csv',
        f'https://dd.weather.gc.ca/hydrometric/csv/bc/{station_id}.csv',
        f'https://collaboration.cmc.ec.gc.ca/cmc/hydrometrics/realtime/{station_id}.csv',
        
        # Try with different date formats
        f'https://wateroffice.ec.gc.ca/services/real_time_data/csv/inline?station={station_id}',
        f'https://wateroffice.ec.gc.ca/services/real_time_data/csv/inline?station_id={station_id}',
        f'https://wateroffice.ec.gc.ca/services/real_time_data/csv/inline?stn={station_id}',
    ]
    
    for url in test_endpoints:
        try:
            response = requests.get(url, timeout=10)
            print(f"📡 {url}")
            print(f"   Status: {response.status_code}, Size: {len(response.text)}")
            
            if response.status_code == 200 and len(response.text) > 100:
                content = response.text
                
                # Check if it looks like real data
                if ',' in content or '{' in content:  # CSV or JSON
                    print(f"   ✅ Got structured data!")
                    print(f"   📄 Sample: {content[:200]}...")
                    
                    # Look for our station ID
                    if station_id in content:
                        print(f"   🎯 Contains station {station_id}!")
                        return True, url, content
                        
        except Exception as e:
            print(f"   ❌ {url} - Error: {e}")
    
    return False, None, None

def main():
    print("🕵️ FORENSIC ANALYSIS: Finding Spillimacheen's Real Data Source")
    print(f"📅 {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print()
    
    # Check website endpoints
    web_success, web_url, web_content = investigate_website_endpoints()
    
    # Check undocumented APIs
    api_success, api_url, api_content = test_undocumented_endpoints()
    
    print("\n" + "=" * 60)
    print("📊 INVESTIGATION RESULTS:")
    
    if api_success:
        print(f"🎉 BREAKTHROUGH! Found working API:")
        print(f"✅ URL: {api_url}")
        print(f"📊 We can implement this in Flutter!")
    elif web_success:
        print(f"🌐 Found station web page:")
        print(f"✅ URL: {web_url}")
        print(f"💡 We can scrape this page for data")
    else:
        print("❌ No direct data access found")
        print("🤔 Possible explanations:")
        print("   • Station data is loaded via JavaScript after page load")
        print("   • Requires session/authentication")
        print("   • Uses WebSocket or real-time streaming")
        print("   • Different API key or parameters needed")
        print()
        print("💡 Next steps:")
        print("   • Check browser network tab on actual website")
        print("   • Contact Environment Canada for API documentation")
        print("   • Use realistic simulation until resolved")

if __name__ == "__main__":
    main()