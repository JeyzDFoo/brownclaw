#!/usr/bin/env python3
"""
Try different real-time data endpoints based on Environment Canada patterns
"""

import requests
import json
from datetime import datetime, timedelta

def test_comprehensive_api_formats():
    """Test every possible API format for 08NA011"""
    station_id = '08NA011'
    
    print(f"🧪 Comprehensive API Testing for {station_id}")
    print("=" * 60)
    
    # Updated API formats - prioritizing working endpoints
    test_urls = [
        # WORKING: New Government of Canada JSON API (correct parameter name)
        f'https://api.weather.gc.ca/collections/hydrometric-realtime/items?STATION_NUMBER={station_id}&limit=1&f=json',
        
        # For comparison: Legacy formats (these should fail with 422)
        f'https://wateroffice.ec.gc.ca/services/real_time_data/csv/inline?stations[]={station_id}&parameters[]=47',
        f'https://wateroffice.ec.gc.ca/services/real_time_data/csv/inline?stations={station_id}&parameters=47',
        
        # Alternative Government API formats to test
        f'https://geo.weather.gc.ca/geomet/features/collections/hydrometric-realtime/items?STATION_NUMBER={station_id}',
        f'https://api.weather.gc.ca/collections/hydrometric-realtime/items?STATION_NUMBER={station_id}&limit=5&f=json',
    ]
    
    today = datetime.now().strftime('%Y-%m-%d')
    yesterday = (datetime.now() - timedelta(days=1)).strftime('%Y-%m-%d')
    
    # Add date-specific URLs
    dated_urls = [
        f'https://dd.weather.gc.ca/today/hydrometric/csv/{today}/{station_id}.csv',
        f'https://dd.weather.gc.ca/today/hydrometric/csv/{yesterday}/{station_id}.csv',
    ]
    
    all_urls = test_urls + dated_urls
    
    for i, url in enumerate(all_urls, 1):
        print(f"\n🔍 Test {i:2d}: {url}")
        
        try:
            response = requests.get(url, timeout=10)
            status = response.status_code
            content_length = len(response.text)
            
            print(f"        Status: {status}, Length: {content_length}")
            
            if status == 200 and content_length > 50:
                content = response.text
                
                # Handle JSON responses (new Government of Canada API)
                if url.startswith('https://api.weather.gc.ca') or 'json' in response.headers.get('content-type', '').lower():
                    try:
                        json_data = json.loads(content)
                        if 'features' in json_data and json_data['features']:
                            print(f"        ✅ JSON data found!")
                            print(f"        📊 {len(json_data['features'])} features")
                            
                            # Extract flow data from JSON
                            for feature in json_data['features']:
                                properties = feature.get('properties', {})
                                station_name = properties.get('STATION_NAME', 'Unknown')
                                discharge = properties.get('DISCHARGE')
                                level = properties.get('LEVEL')
                                datetime_str = properties.get('DATETIME_LST', properties.get('DATETIME'))
                                
                                print(f"        🏷️  Station: {station_name}")
                                print(f"        📅 Time: {datetime_str}")
                                
                                if discharge is not None:
                                    print(f"        💧 Discharge: {discharge} m³/s")
                                    return True, url, content
                                elif level is not None:
                                    print(f"        📏 Level: {level} m")
                                    return True, url, content
                        else:
                            print(f"        ⚠️  JSON response with no features")
                    except json.JSONDecodeError:
                        print(f"        ⚠️  Invalid JSON response")
                
                # Handle CSV responses (legacy APIs)
                else:
                    lines = content.split('\n')
                    
                    # Check if it looks like CSV data
                    if ',' in content and len(lines) > 1:
                        print(f"        ✅ CSV-like data found!")
                        print(f"        📊 {len(lines)} lines")
                        print(f"        📋 Header: {lines[0]}")
                        
                        if len(lines) > 1:
                            print(f"        📋 Sample: {lines[1]}")
                        
                        # Look for flow data
                        for line in lines[1:6]:
                            if line.strip():
                                parts = line.split(',')
                                for part in parts:
                                    part = part.strip().strip('"')
                                    if part.replace('.', '').replace('-', '').isdigit():
                                        try:
                                            value = float(part)
                                            if 0.1 < value < 10000:  # Reasonable flow range
                                                print(f"        💧 Potential flow: {value} m³/s")
                                        except:
                                            pass
                        
                        return True, url, content
                
            elif status == 404:
                print(f"        ❌ Not Found")
            elif status == 422:
                print(f"        ❌ Unprocessable Entity")
            elif status == 403:
                print(f"        ❌ Forbidden")
            else:
                print(f"        ⚠️  Unexpected status")
                
        except requests.exceptions.Timeout:
            print(f"        ⏰ Timeout")
        except Exception as e:
            print(f"        ❌ Error: {e}")
    
    return False, None, None

def main():
    print("🔍 Comprehensive Real-Time Data API Testing")
    print(f"📅 {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"🎯 Target: Station 08NA011 (Spillimacheen River)")
    print()
    
    success, working_url, data = test_comprehensive_api_formats()
    
    print("\n" + "=" * 60)
    print("📊 FINAL RESULT:")
    
    if success:
        print("🎉 SUCCESS! Found working real-time data URL!")
        print(f"✅ URL: {working_url}")
        print(f"📊 Data length: {len(data)} characters")
        print("🔧 We can now implement this in the Flutter app!")
    else:
        print("❌ No working direct CSV/JSON API found")
        print("💡 Options:")
        print("   1. Use the web report scraping method")  
        print("   2. Contact Environment Canada for API documentation")
        print("   3. Use realistic simulation until API is available")

if __name__ == "__main__":
    main()