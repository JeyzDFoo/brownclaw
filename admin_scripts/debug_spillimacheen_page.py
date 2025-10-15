#!/usr/bin/env python3
"""
Debug script to examine the Spillimacheen station page in detail
"""

import requests
from bs4 import BeautifulSoup
import re
from datetime import datetime

def debug_spillimacheen_page():
    """Debug the HTML response to find discharge data"""
    station_id = '08NA011'
    
    # This URL works and returns HTML with station data
    url = f'https://wateroffice.ec.gc.ca/report/real_time_e.html?prm1=47&stn={station_id}'
    
    print(f"🔍 Debugging Spillimacheen page:")
    print(f"   URL: {url}")
    print("=" * 60)
    
    try:
        response = requests.get(url, timeout=15)
        
        if response.status_code == 200:
            html = response.text
            soup = BeautifulSoup(html, 'html.parser')
            
            print(f"✅ Got HTML response ({len(html)} characters)")
            
            # Look for any data tables or divs
            print("\n🔍 Looking for data containers...")
            
            # Check for any elements with "data", "flow", "discharge" in class or id
            data_elements = soup.find_all(attrs={'class': re.compile('.*data.*', re.I)})
            flow_elements = soup.find_all(attrs={'class': re.compile('.*flow.*', re.I)})
            discharge_elements = soup.find_all(attrs={'class': re.compile('.*discharge.*', re.I)})
            
            print(f"📊 Elements with 'data' in class: {len(data_elements)}")
            print(f"💧 Elements with 'flow' in class: {len(flow_elements)}")
            print(f"🌊 Elements with 'discharge' in class: {len(discharge_elements)}")
            
            # Check for any tables
            tables = soup.find_all('table')
            print(f"📋 Tables found: {len(tables)}")
            
            # Look for divs that might contain data
            divs = soup.find_all('div')
            print(f"📦 Divs found: {len(divs)}")
            
            # Search for text containing numbers that could be discharge
            text_content = soup.get_text()
            
            # Look for patterns like "Discharge: 123.45" or "Flow: 123.45"
            discharge_patterns = [
                r'discharge[:\s]+(\d+\.?\d*)',
                r'flow[:\s]+(\d+\.?\d*)',
                r'(\d+\.?\d*)\s*m[³3]/s',
                r'(\d+\.?\d*)\s*cms',
                r'(\d+\.?\d*)\s*cubic\s*meters?\s*per\s*second'
            ]
            
            found_values = []
            for pattern in discharge_patterns:
                matches = re.findall(pattern, text_content, re.IGNORECASE)
                if matches:
                    print(f"🎯 Pattern '{pattern}' found: {matches}")
                    found_values.extend(matches)
            
            # Look for any JavaScript data
            scripts = soup.find_all('script')
            print(f"\n📜 Scripts found: {len(scripts)}")
            
            for i, script in enumerate(scripts):
                if script.string and ('data' in script.string or 'value' in script.string):
                    content = script.string[:200]  # First 200 chars
                    print(f"   Script {i+1}: {content}...")
            
            # Check if there are any forms that might load data
            forms = soup.find_all('form')
            print(f"📝 Forms found: {len(forms)}")
            
            # Look for any AJAX endpoints or data URLs
            links = soup.find_all('a', href=True)
            data_links = [link['href'] for link in links if 'data' in link['href'].lower() or 'real' in link['href'].lower()]
            print(f"🔗 Data-related links: {data_links[:5]}")  # Show first 5
            
            # Check for meta tags or hidden inputs with data
            meta_tags = soup.find_all('meta')
            for meta in meta_tags:
                if meta.get('content') and any(word in meta.get('content', '').lower() for word in ['data', 'discharge', 'flow']):
                    print(f"📋 Meta tag: {meta}")
            
            # Look for any error messages or "no data" indicators
            error_indicators = ['no data', 'not available', 'temporarily unavailable', 'error', 'maintenance']
            page_text_lower = text_content.lower()
            
            for indicator in error_indicators:
                if indicator in page_text_lower:
                    print(f"⚠️  Found indicator: '{indicator}' in page text")
            
            # Save a sample of the HTML for manual inspection
            print(f"\n📄 Sample HTML content:")
            print(text_content[:1000])
            
        else:
            print(f"❌ HTTP {response.status_code}")
            
    except Exception as e:
        print(f"❌ Request failed: {e}")

if __name__ == "__main__":
    debug_spillimacheen_page()