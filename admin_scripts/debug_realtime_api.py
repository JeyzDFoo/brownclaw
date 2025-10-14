#!/usr/bin/env python3
"""
Debug the real-time water data API to understand the correct format
"""

import requests
from datetime import datetime, timedelta

def test_api_formats():
    """Test different API formats to find what works"""
    
    # Test station that we know exists from our database
    test_station = '05BH004'  # Bow River at Calgary
    
    print("🔍 Testing different API request formats...")
    
    formats_to_try = [
        # Original format
        f'https://wateroffice.ec.gc.ca/services/real_time_data/csv/inline?stations[]={test_station}&parameters[]=47',
        
        # Alternative formats
        f'https://wateroffice.ec.gc.ca/services/real_time_data/csv/inline?stations={test_station}&parameters=47',
        f'https://wateroffice.ec.gc.ca/services/real_time_data/csv/inline?stations[]={test_station}&parameters[]=46', # water level
        f'https://wateroffice.ec.gc.ca/services/real_time_data/csv/inline?stations[]={test_station}', # all parameters
        
        # Try without parameters
        f'https://wateroffice.ec.gc.ca/services/real_time_data/csv/inline?stations[]={test_station}&start_date=2024-10-13&end_date=2024-10-14',
    ]
    
    for i, url in enumerate(formats_to_try, 1):
        print(f"\n🧪 Test {i}: {url}")
        
        try:
            response = requests.get(url, timeout=10)
            print(f"   Status: {response.status_code}")
            
            if response.status_code == 200:
                content = response.text[:500]  # First 500 chars
                lines = response.text.split('\n')
                print(f"   ✅ Success! {len(lines)} lines returned")
                print(f"   📄 First 200 chars: {content[:200]}...")
                
                # Try to find data
                if len(lines) >= 2:
                    header = lines[0]
                    print(f"   📋 Header: {header}")
                    
                    if len(lines) >= 3:
                        sample_data = lines[1]
                        print(f"   📊 Sample data: {sample_data}")
                
                return True, url
            else:
                print(f"   ❌ Failed with status {response.status_code}")
                if response.text:
                    error_msg = response.text[:200]
                    print(f"   💬 Response: {error_msg}")
                    
        except Exception as e:
            print(f"   ❌ Exception: {e}")
    
    return False, None

def test_station_availability():
    """Check if our test stations are actually active"""
    print("\n🔍 Checking station availability...")
    
    # Try the main real-time data service
    url = 'https://wateroffice.ec.gc.ca/services/real_time_data/csv/inline'
    
    print(f"📡 Testing base URL: {url}")
    
    try:
        response = requests.get(url, timeout=10)
        print(f"Status: {response.status_code}")
        print(f"Response length: {len(response.text)} chars")
        
        if response.text:
            print(f"First 300 chars: {response.text[:300]}")
            
    except Exception as e:
        print(f"❌ Error: {e}")

def main():
    print("🧪 Debugging Real-Time Water Data API")
    print("=" * 50)
    
    # Test base service
    test_station_availability()
    
    # Test different formats
    success, working_url = test_api_formats()
    
    if success:
        print(f"\n🎉 Found working format: {working_url}")
        print("✅ We can update the Flutter service to use this format!")
    else:
        print("\n⚠️  No working format found")
        print("💡 The API might be temporarily down or require authentication")
        print("🔄 The Flutter app will use demo data as fallback")

if __name__ == "__main__":
    main()