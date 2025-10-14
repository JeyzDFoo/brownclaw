#!/usr/bin/env python3
"""
Try different real-time data endpoints based on Environment Canada patterns
"""

import requests
from datetime import datetime, timedelta

def test_comprehensive_api_formats():
    """Test every possible API format for 08NA011"""
    station_id = '08NA011'
    
    print(f"🧪 Comprehensive API Testing for {station_id}")
    print("=" * 60)
    
    # Based on Environment Canada documentation and common patterns
    test_urls = [
        # Original wateroffice API formats
        f'https://wateroffice.ec.gc.ca/services/real_time_data/csv/inline/{station_id}',
        f'https://wateroffice.ec.gc.ca/services/real_time_data/csv/{station_id}',
        f'https://wateroffice.ec.gc.ca/services/real_time_data/{station_id}/csv',
        f'https://wateroffice.ec.gc.ca/services/download_stats.html?station_id={station_id}&format=csv&parameter_type=47',
        
        # New datamart structure (after Oct 7 change)
        f'https://dd.weather.gc.ca/today/hydrometric/csv/{station_id}_hourly.csv',
        f'https://dd.weather.gc.ca/today/hydrometric/csv/{station_id}_daily.csv',
        f'https://dd.weather.gc.ca/today/hydrometric/csv/{station_id}.csv',
        f'https://dd.weather.gc.ca/today/hydrometric/realtime/{station_id}.csv',
        
        # Government of Canada open data formats
        f'https://api.weather.gc.ca/collections/hydrometric-realtime/items?station_number={station_id}',
        f'https://geo.weather.gc.ca/geomet/features/collections/hydrometric-realtime/items?station_number={station_id}',
        
        # Try different parameter formats
        f'https://wateroffice.ec.gc.ca/services/real_time_data/csv/inline?stations%5B%5D={station_id}&parameters%5B%5D=47',
        
        # Alternative service endpoints
        f'https://wateroffice.ec.gc.ca/data/real_time/{station_id}.csv',
        f'https://wateroffice.ec.gc.ca/api/realtime?station={station_id}',
        
        # Try the MSC Datamart direct paths
        f'https://dd.weather.gc.ca/today/hydrometric/bc/{station_id}_RT.csv',
        f'https://dd.weather.gc.ca/today/hydrometric/BC/{station_id}_hourly.csv',
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
            
            if status == 200 and content_length > 100:
                content = response.text
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
                                if part.replace('.', '').isdigit():
                                    try:
                                        value = float(part)
                                        if 0.1 < value < 1000:  # Reasonable flow range
                                            print(f"        💧 Potential flow: {value} m³/s")
                                    except:
                                        pass
                    
                    return True, url, content
                    
                elif 'json' in response.headers.get('content-type', '').lower():
                    print(f"        ✅ JSON data found!")
                    print(f"        📄 Sample: {content[:200]}...")
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