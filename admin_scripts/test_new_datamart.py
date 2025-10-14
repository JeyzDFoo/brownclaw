#!/usr/bin/env python3
"""
Test the NEW datamart URLs (changed October 7, 2025) for station 08NA011
"""

import requests
from datetime import datetime

def test_new_datamart_urls():
    """Test the updated datamart URLs announced on Oct 7, 2025"""
    station_id = '08NA011'
    
    print("🚨 TESTING NEW DATAMART URLs (Changed Oct 7, 2025)")
    print(f"🧪 Station: {station_id} - Spillimacheen River")
    print("=" * 60)
    
    # New datamart base URL
    new_base = 'https://dd.weather.gc.ca/today/hydrometric'
    
    # Test different paths under the new structure
    test_urls = [
        f"{new_base}/csv/{station_id}_RT.csv",
        f"{new_base}/csv/RT_{station_id}.csv", 
        f"{new_base}/real_time/{station_id}.csv",
        f"{new_base}/stations/{station_id}/data.csv",
        f"{new_base}/{station_id}/realtime.csv",
        f"{new_base}/rt/{station_id}.csv",
    ]
    
    for i, url in enumerate(test_urls, 1):
        print(f"\n🔍 Test {i}: {url}")
        
        try:
            response = requests.get(url, timeout=10)
            print(f"   📊 Status: {response.status_code}")
            
            if response.status_code == 200:
                content = response.text
                lines = content.split('\n')
                
                print(f"   ✅ SUCCESS! {len(lines)} lines received")
                print(f"   📄 Content length: {len(content)} characters")
                
                if len(lines) >= 2:
                    header = lines[0]
                    print(f"   📋 Header: {header}")
                    
                    # Look for recent data
                    for line in lines[1:6]:  # Check first 5 data lines
                        if line.strip():
                            print(f"   📊 Sample data: {line}")
                            
                    return True, url
                    
            elif response.status_code == 404:
                print(f"   ❌ Not Found")
            else:
                print(f"   ❌ HTTP {response.status_code}")
                
        except Exception as e:
            print(f"   ❌ Error: {e}")
    
    print("\n🔍 Trying to browse the new datamart structure...")
    
    # Try to list available files
    browse_urls = [
        f"{new_base}/",
        f"{new_base}/csv/",
        f"{new_base}/real_time/",
    ]
    
    for url in browse_urls:
        try:
            response = requests.get(url, timeout=10)
            if response.status_code == 200:
                print(f"   ✅ {url} - Available")
                content = response.text[:500]
                if '08NA011' in content:
                    print(f"   🎯 Found reference to our station!")
                break
        except:
            continue
    
    return False, None

def test_original_web_service():
    """Test if the original web service works with different parameters"""
    station_id = '08NA011'
    
    print(f"\n🔧 Testing original web service with new parameter formats...")
    
    # Try some different parameter combinations
    base_url = 'https://wateroffice.ec.gc.ca/services/real_time_data'
    
    test_formats = [
        f"{base_url}/csv/inline?station={station_id}",
        f"{base_url}/json?stations={station_id}",
        f"{base_url}/csv?station_number={station_id}",
        f"https://wateroffice.ec.gc.ca/report/real_time_e.html?mode=Table&type=realTime&prm1=47&prm2=-1&stn={station_id}",
    ]
    
    for url in test_formats:
        try:
            response = requests.get(url, timeout=10)
            print(f"   {url} - Status: {response.status_code}")
            if response.status_code == 200 and len(response.text) > 100:
                print(f"   ✅ Got content ({len(response.text)} chars)")
                return True, url
        except:
            continue
    
    return False, None

def main():
    print("🧪 Testing Updated API Endpoints for 08NA011")
    print(f"📅 Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print()
    
    # Test new datamart URLs
    success1, working_url1 = test_new_datamart_urls()
    
    # Test original web service with different formats
    success2, working_url2 = test_original_web_service()
    
    print("\n" + "=" * 60)
    print("📊 RESULTS:")
    
    if success1:
        print(f"🎉 NEW DATAMART: Working URL found!")
        print(f"   URL: {working_url1}")
    elif success2:
        print(f"🎉 WEB SERVICE: Working URL found!")
        print(f"   URL: {working_url2}")
    else:
        print("⚠️  No working URLs found")
        print("💡 Possible reasons:")
        print("   • Station data not available in new format yet")
        print("   • Need different authentication or parameters")
        print("   • API still being updated after URL change")

if __name__ == "__main__":
    main()