#!/usr/bin/env python3
"""
Test format options for the working Spillimacheen station endpoint
"""

import requests
import re

def test_format_options():
    """Test different format parameters for station 08NA011"""
    base_url = 'https://wateroffice.ec.gc.ca/report/real_time_e.html'
    station_id = '08NA011'

    print(f'🔍 Testing format options for station {station_id}...')
    print('=' * 50)

    # Try different format parameters
    format_tests = [
        ('prm1=47&stn=08NA011', 'Standard HTML'),
        ('prm1=47&stn=08NA011&mode=csv', 'Try CSV mode'),
        ('prm1=47&stn=08NA011&format=csv', 'Try CSV format'),
        ('prm1=47&stn=08NA011&output=csv', 'Try CSV output'),
        ('prm1=47&stn=08NA011&type=csv', 'Try CSV type'),
        ('prm1=47&stn=08NA011&mode=Table&type=realTime', 'Table mode'),
        ('prm1=47&stn=08NA011&mode=download', 'Download mode'),
        ('prm1=47&stn=08NA011&mode=Graph', 'Graph mode'),
    ]

    working_responses = []

    for params, description in format_tests:
        url = f'{base_url}?{params}'
        print(f'\n📡 {description}')
        print(f'   URL: {url}')
        
        try:
            response = requests.get(url, timeout=10)
            status = response.status_code
            content_type = response.headers.get('content-type', 'unknown')
            size = len(response.text)
            
            print(f'   Status: {status}')
            print(f'   Content-Type: {content_type}')
            print(f'   Size: {size} chars')
            
            if status == 200:
                content = response.text
                
                # Check what kind of content we got
                if content.startswith('<!DOCTYPE html') or '<html' in content[:100]:
                    print(f'   📄 HTML response')
                    
                    # Look for embedded data or tables
                    if 'spillimacheen' in content.lower():
                        print(f'   ✅ Contains Spillimacheen data')
                        
                        # Look for data tables
                        table_pattern = r'<table[^>]*>.*?</table>'
                        tables = re.findall(table_pattern, content, re.DOTALL | re.IGNORECASE)
                        print(f'   📊 Found {len(tables)} tables')
                        
                        # Look for numeric data that could be flow rates
                        number_pattern = r'>\\s*(\\d+\\.?\\d*)\\s*</td>'
                        numbers = re.findall(number_pattern, content)
                        if numbers:
                            # Filter for reasonable flow values (0.1 to 1000 m³/s)
                            flow_candidates = []
                            for n in numbers:
                                try:
                                    val = float(n)
                                    if 0.1 <= val <= 1000:
                                        flow_candidates.append(val)
                                except:
                                    continue
                            
                            if flow_candidates:
                                print(f'   💧 Potential flows: {flow_candidates[:5]}')
                                working_responses.append((url, content, flow_candidates))
                    
                    # Also look for "No Data" messages
                    if 'no data' in content.lower() or 'not available' in content.lower():
                        print(f'   ⚠️  Contains "no data" message')
                            
                elif content.startswith('{') or content.strip().startswith('['):
                    print(f'   📊 JSON response!')
                    working_responses.append((url, content, 'JSON'))
                    
                elif ',' in content and content.count('\n') > 5:
                    print(f'   📊 CSV-like response!')
                    lines = content.split('\n')[:5]
                    for i, line in enumerate(lines):
                        if line.strip():
                            print(f'      Line {i}: {line[:60]}...')
                    working_responses.append((url, content, 'CSV'))
                    
            elif status == 404:
                print(f'   ❌ Not Found')
            elif status == 422:
                print(f'   ❌ Unprocessable Entity')
            else:
                print(f'   ⚠️  Unexpected status')
                
        except Exception as e:
            print(f'   ❌ Error: {e}')

    return working_responses

def extract_flow_from_html(html_content):
    """Try to extract flow data from HTML response"""
    print('\n🔍 Attempting to extract flow data from HTML...')
    
    # Look for table data with flow values
    patterns = [
        r'<td[^>]*>\\s*(\\d+\\.\\d+)\\s*</td>',  # Decimal numbers in table cells
        r'Discharge[^>]*>([^<]*\\d+[^<]*)',      # Discharge labels
        r'Flow[^>]*>([^<]*\\d+[^<]*)',           # Flow labels  
        r'(\\d+\\.\\d+)\\s*m³/s',                # Numbers followed by m³/s
        r'(\\d+\\.\\d+)\\s*cubic',               # Numbers followed by cubic
    ]
    
    all_matches = []
    
    for pattern in patterns:
        matches = re.findall(pattern, html_content, re.IGNORECASE)
        if matches:
            print(f'   Pattern "{pattern}" found: {matches[:3]}')
            all_matches.extend(matches)
    
    # Try to find the most recent/relevant flow value
    flow_values = []
    for match in all_matches:
        try:
            # Extract just the numeric part
            num_match = re.search(r'(\\d+\\.\\d+)', str(match))
            if num_match:
                val = float(num_match.group(1))
                if 0.01 <= val <= 1000:  # Reasonable range for flow
                    flow_values.append(val)
        except:
            continue
    
    if flow_values:
        print(f'   💧 Extracted flow values: {flow_values}')
        return flow_values[-1]  # Return the last (most recent) value
    
    return None

def main():
    print('🧪 TESTING SPILLIMACHEEN STATION FORMAT OPTIONS')
    print(f'📅 {requests.__name__} version testing')
    print()
    
    working_responses = test_format_options()
    
    print('\n' + '=' * 50)
    print('📊 SUMMARY OF WORKING RESPONSES:')

    if working_responses:
        for i, (url, content, data_type) in enumerate(working_responses, 1):
            print(f'\n{i}. {url}')
            if isinstance(data_type, list):
                print(f'   💧 Flow values found: {data_type[:3]}')
            else:
                print(f'   📊 Data type: {data_type}')
            print(f'   📏 Size: {len(content)} characters')
            
            # Try to extract flow from HTML
            if 'html' in url.lower() and len(content) > 1000:
                flow = extract_flow_from_html(content)
                if flow:
                    print(f'   🎯 EXTRACTED FLOW: {flow} m³/s')
        
        print(f'\n✅ Found {len(working_responses)} working endpoints!')
        print('🔧 We can extract real-time data from these!')
    else:
        print('\n❌ No working data endpoints found')
        print('💡 The station may be online but data not accessible via these URLs')

if __name__ == "__main__":
    main()