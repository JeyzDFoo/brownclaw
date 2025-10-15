#!/usr/bin/env python3
"""
Try multiple endpoints to get Spillimacheen discharge data
"""

import requests
from bs4 import BeautifulSoup
import json
from datetime import datetime

def try_spillimacheen_endpoints():
    """Try different endpoints to get Spillimacheen data"""
    station_id = '08NA011'
    
    endpoints = [
        # Original endpoint
        f'https://wateroffice.ec.gc.ca/report/real_time_e.html?prm1=47&stn={station_id}',
        
        # Alternative endpoints
        f'https://wateroffice.ec.gc.ca/report/real_time_e.html?stn={station_id}&prm1=47&mode=Table',
        f'https://wateroffice.ec.gc.ca/report/real_time_e.html?stn={station_id}&prm1=47&mode=Graph',
        
        # API-style endpoints
        f'https://wateroffice.ec.gc.ca/services/real_time_data/csv/inline?stations[]={station_id}&parameters[]=47',
        f'https://wateroffice.ec.gc.ca/services/real_time_data/json?stations[]={station_id}&parameters[]=47',
        
        # Direct CSV
        f'https://dd.weather.gc.ca/hydrometric/csv/BC/hourly/BC_{station_id}_hourly_hydrometric.csv',
        
        # Another format
        f'https://wateroffice.ec.gc.ca/mainmenu/real_time_data_index_e.html?mode=Table&stn={station_id}&prm1=47',
    ]
    
    print(f"🔍 Trying multiple endpoints for Spillimacheen ({station_id}):")
    print("=" * 80)
    
    for i, url in enumerate(endpoints, 1):
        print(f"\n{i}. {url}")
        print("-" * 60)
        
        try:
            response = requests.get(url, timeout=15)
            print(f"   Status: {response.status_code}")
            print(f"   Content-Type: {response.headers.get('content-type', 'unknown')}")
            print(f"   Content-Length: {len(response.text)}")
            
            if response.status_code == 200:
                content = response.text
                
                # Check if it's JSON
                if 'application/json' in response.headers.get('content-type', ''):
                    try:
                        data = response.json()
                        print(f"   ✅ JSON data: {data}")
                        return data
                    except:
                        print("   ❌ Invalid JSON")
                
                # Check if it's CSV
                elif 'text/csv' in response.headers.get('content-type', '') or url.endswith('.csv'):
                    lines = content.split('\n')[:5]  # First 5 lines
                    print(f"   📊 CSV preview:")
                    for line in lines:
                        if line.strip():
                            print(f"      {line}")
                    
                    # Look for discharge data in CSV
                    if 'discharge' in content.lower() or 'flow' in content.lower():
                        print("   🎯 CSV contains discharge/flow data!")
                        return parse_csv_data(content)
                
                # Check HTML content
                else:
                    # Look for actual data vs disclaimer page
                    if 'disclaimer' in content.lower() and len(content) < 20000:
                        print("   ⚠️  Disclaimer page")
                    else:
                        print("   📄 HTML content")
                        
                        # Try to find discharge values
                        soup = BeautifulSoup(content, 'html.parser')
                        text = soup.get_text()
                        
                        # Look for numerical values that could be discharge
                        import re
                        numbers = re.findall(r'\b\d+\.?\d*\b', text)
                        if numbers:
                            print(f"   🔢 Found numbers: {numbers[:10]}")  # First 10 numbers
                        
                        # Look for specific discharge mentions
                        if any(word in text.lower() for word in ['discharge', 'flow rate', 'm³/s', 'cms']):
                            print("   🎯 Contains discharge-related terms!")
                            return parse_html_discharge(content)
                        
                        # Show a sample of the content
                        sample = text[:200].replace('\n', ' ').replace('\t', ' ')
                        print(f"   Sample: {sample}...")
            
            else:
                print(f"   ❌ HTTP {response.status_code}")
                
        except requests.exceptions.Timeout:
            print("   ⏱️  Timeout")
        except Exception as e:
            print(f"   ❌ Error: {e}")
    
    print(f"\n❌ No discharge data found from any endpoint")
    return None

def parse_csv_data(csv_content):
    """Parse CSV content for discharge data"""
    lines = csv_content.split('\n')
    for line in lines[:20]:  # Check first 20 lines
        if line.strip():
            print(f"CSV Line: {line}")
    return None

def parse_html_discharge(html_content):
    """Parse HTML for discharge values"""
    soup = BeautifulSoup(html_content, 'html.parser')
    text = soup.get_text()
    
    # Look for patterns
    import re
    patterns = [
        r'discharge[:\s]+(\d+\.?\d*)',
        r'flow[:\s]+(\d+\.?\d*)',
        r'(\d+\.?\d*)\s*m[³3]/s',
        r'(\d+\.?\d*)\s*cms'
    ]
    
    for pattern in patterns:
        matches = re.findall(pattern, text, re.IGNORECASE)
        if matches:
            print(f"🎯 Found discharge pattern: {matches}")
            return float(matches[0])
    
    return None

if __name__ == "__main__":
    print("🧪 SPILLIMACHEEN DISCHARGE DATA SEARCH")
    print(f"📅 {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    
    result = try_spillimacheen_endpoints()
    
    if result:
        print(f"\n🎉 SUCCESS! Found discharge data: {result}")
    else:
        print(f"\n⚠️  No discharge data found. The station might be:")
        print("   • Temporarily offline")
        print("   • Moved to a different URL structure") 
        print("   • Requiring authentication")
        print("   • Only available through a different API")