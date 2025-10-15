#!/usr/bin/env python3
"""
Debug script to understand what data we're actually receiving from the Canadian Water Office API
and why some stations still have generic names.
"""

import requests
import json
import logging
from datetime import datetime

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def test_station_metadata_apis():
    """Test different APIs to see what station metadata we can get."""
    
    # Test a few known station IDs
    test_stations = ['01AD003', '05BH004', '07AA001', '08HB002', '02KB001']
    
    print("🔍 Testing different Canadian Water Office APIs for station metadata...\n")
    
    # API 1: Try to get station list/metadata
    print("=" * 60)
    print("API 1: Station List from wateroffice.ec.gc.ca")
    print("=" * 60)
    
    try:
        # Try different endpoints for station metadata
        metadata_urls = [
            'https://wateroffice.ec.gc.ca/services/stations',
            'https://wateroffice.ec.gc.ca/services/real_time_data/stations',
            'https://wateroffice.ec.gc.ca/api/stations',
            'https://wateroffice.ec.gc.ca/services/station_list',
        ]
        
        for url in metadata_urls:
            print(f"\n🌐 Trying: {url}")
            try:
                response = requests.get(url, timeout=10)
                print(f"   Status: {response.status_code}")
                print(f"   Content-Type: {response.headers.get('content-type', 'unknown')}")
                print(f"   Content length: {len(response.text)} chars")
                
                if response.status_code == 200:
                    # Try to parse as JSON
                    try:
                        data = response.json()
                        print(f"   ✅ JSON data with {len(data) if isinstance(data, list) else 'object'} items")
                        if isinstance(data, list) and len(data) > 0:
                            print(f"   Sample item: {json.dumps(data[0], indent=2)[:200]}...")
                        elif isinstance(data, dict):
                            print(f"   Keys: {list(data.keys())}")
                    except json.JSONDecodeError:
                        # Try as text/CSV
                        lines = response.text.split('\n')
                        print(f"   📄 Text data with {len(lines)} lines")
                        if len(lines) > 0:
                            print(f"   First line: {lines[0][:100]}...")
                        if len(lines) > 1:
                            print(f"   Second line: {lines[1][:100]}...")
                            
            except Exception as e:
                print(f"   ❌ Error: {e}")
                
    except Exception as e:
        print(f"❌ Failed to test station metadata APIs: {e}")
    
    # API 2: Test real-time data API for specific stations
    print("\n" + "=" * 60)
    print("API 2: Real-time Data API (what we currently use)")
    print("=" * 60)
    
    for station_id in test_stations:
        print(f"\n🔍 Testing station {station_id}:")
        
        try:
            url = "https://api.weather.gc.ca/collections/hydrometric-realtime/items?STATION_NUMBER={}&limit=1&f=json".format(station_id)
            params = {
                'stations[]': station_id,
                'parameters[]': '47',  # Flow parameter
                'start_date': '2025-10-10',
                'end_date': '2025-10-14'
            }
            
            response = requests.get(url, params=params, timeout=10)
            print(f"   Status: {response.status_code}")
            print(f"   Content length: {len(response.text)} chars")
            
            if response.status_code == 200 and len(response.text) > 50:
                lines = response.text.split('\n')
                print(f"   Lines: {len(lines)}")
                
                # Look at headers and first few lines for metadata
                if len(lines) > 0:
                    print(f"   Header: {lines[0]}")
                    
                # Look for station name in the data
                for i, line in enumerate(lines[:10]):  # Check first 10 lines
                    if station_id in line and 'Station' not in line:
                        print(f"   Line {i}: {line}")
                        
        except Exception as e:
            print(f"   ❌ Error: {e}")
    
    # API 3: Try Environment Canada open data
    print("\n" + "=" * 60)
    print("API 3: Environment Canada Open Data")
    print("=" * 60)
    
    try:
        open_data_urls = [
            'https://dd.weather.gc.ca/hydrometric/doc/hydrometric_StationList.csv',
            'https://collaboration.cmc.ec.gc.ca/cmc/hydrometrics/www/HydrometricNetworkBasinPoly.csv',
            'https://dd.weather.gc.ca/hydrometric/csv/',
        ]
        
        for url in open_data_urls:
            print(f"\n🌐 Trying: {url}")
            try:
                response = requests.get(url, timeout=15)
                print(f"   Status: {response.status_code}")
                print(f"   Content-Type: {response.headers.get('content-type', 'unknown')}")
                print(f"   Content length: {len(response.text)} chars")
                
                if response.status_code == 200:
                    lines = response.text.split('\n')
                    print(f"   Lines: {len(lines)}")
                    if len(lines) > 0:
                        print(f"   Header: {lines[0][:150]}...")
                    if len(lines) > 1:
                        print(f"   Sample: {lines[1][:150]}...")
                        
                    # Look for our test stations
                    found_stations = []
                    for line in lines[:50]:  # Check first 50 lines
                        for station_id in test_stations:
                            if station_id in line:
                                found_stations.append((station_id, line[:200]))
                                
                    if found_stations:
                        print(f"   ✅ Found {len(found_stations)} test stations:")
                        for station_id, line in found_stations:
                            print(f"      {station_id}: {line}")
                            
            except Exception as e:
                print(f"   ❌ Error: {e}")
                
    except Exception as e:
        print(f"❌ Failed to test open data APIs: {e}")

    # API 4: Check individual station info pages
    print("\n" + "=" * 60)
    print("API 4: Individual Station Pages")
    print("=" * 60)
    
    for station_id in test_stations[:3]:  # Test just a few
        print(f"\n🔍 Testing station page for {station_id}:")
        
        try:
            # Try different URL patterns for station info
            station_urls = [
                f'https://wateroffice.ec.gc.ca/report/station_info?station={station_id}',
                f'https://wateroffice.ec.gc.ca/station_info/{station_id}',
                f'https://wateroffice.ec.gc.ca/services/station/{station_id}',
                f'https://wateroffice.ec.gc.ca/api/station/{station_id}/info',
            ]
            
            for url in station_urls:
                try:
                    response = requests.get(url, timeout=10)
                    print(f"   {url}: {response.status_code}")
                    
                    if response.status_code == 200:
                        content = response.text
                        print(f"   Content length: {len(content)} chars")
                        
                        # Look for station name patterns in HTML/JSON
                        import re
                        
                        # Look for common patterns that might contain river names
                        patterns = [
                            r'"name":\s*"([^"]+)"',
                            r'"station_name":\s*"([^"]+)"',
                            r'<title>([^<]+)</title>',
                            r'Station Name:\s*([^\n\r<]+)',
                            r'River[^:]*:\s*([^\n\r<]+)',
                        ]
                        
                        for pattern in patterns:
                            matches = re.findall(pattern, content, re.IGNORECASE)
                            if matches:
                                print(f"   Found names: {matches[:3]}")  # Show first 3 matches
                                break
                                
                except Exception as e:
                    continue
                    
        except Exception as e:
            print(f"   ❌ Error: {e}")

if __name__ == "__main__":
    print("🚀 Starting Canadian Water Office API debugging session...")
    test_station_metadata_apis()
    print("\n✅ Debugging session complete!")