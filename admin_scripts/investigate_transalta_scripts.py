#!/usr/bin/env python3
"""
Deep dive into TransAlta JavaScript to find data source

This script examines all script tags and external script URLs to find
where the flow data is coming from.
"""

import requests
from bs4 import BeautifulSoup
import re
import json

HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml',
}

def investigate_scripts():
    """Deep investigation of all scripts on the page"""
    print("🔬 Deep Script Investigation")
    print("=" * 80)
    
    url = "https://transalta.com/river-flows/"
    response = requests.get(url, headers=HEADERS, timeout=15)
    soup = BeautifulSoup(response.text, 'html.parser')
    
    scripts = soup.find_all('script')
    
    print(f"\nFound {len(scripts)} script tags\n")
    
    for i, script in enumerate(scripts, 1):
        print(f"\n{'='*70}")
        print(f"SCRIPT {i}")
        print('='*70)
        
        # Check for external script
        if script.get('src'):
            src = script.get('src')
            print(f"📎 External Script: {src}")
            
            # Try to fetch external scripts
            if src.startswith('http'):
                try:
                    ext_response = requests.get(src, headers=HEADERS, timeout=10)
                    if ext_response.status_code == 200:
                        ext_content = ext_response.text
                        
                        # Check if it contains our data
                        if 'barrier' in ext_content.lower() or 'pocaterra' in ext_content.lower():
                            print("   ✅ Contains barrier/pocaterra references!")
                            
                            # Look for data structures
                            if 'allData' in ext_content or 'flowData' in ext_content:
                                print("   ✅ Contains allData or flowData variable!")
                                
                                # Try to extract the data
                                data_match = re.search(r'(?:allData|flowData)\s*=\s*(\[[\s\S]*?\]);', ext_content)
                                if data_match:
                                    print(f"\n   📊 Found data structure (first 1000 chars):")
                                    print(f"   {data_match.group(1)[:1000]}")
                        
                        # Look for API calls
                        api_patterns = [
                            r'fetch\(["\']([^"\']+)["\']',
                            r'\.get\(["\']([^"\']+)["\']',
                            r'ajax\(["\']([^"\']+)["\']',
                            r'XMLHttpRequest.*?open\([^,]+,\s*["\']([^"\']+)["\']',
                        ]
                        
                        for pattern in api_patterns:
                            matches = re.findall(pattern, ext_content)
                            if matches:
                                print(f"\n   🌐 Found API calls:")
                                for match in matches[:5]:
                                    print(f"      • {match}")
                    
                except Exception as e:
                    print(f"   ⚠️  Could not fetch: {e}")
            
        # Inline script
        else:
            script_text = script.string if script.string else ""
            
            if not script_text:
                print("(Empty inline script)")
                continue
            
            print(f"📝 Inline Script ({len(script_text)} chars)")
            
            # Check for relevant keywords
            keywords = ['barrier', 'pocaterra', 'allData', 'flowData', 'fetch', 'ajax', 'XMLHttpRequest']
            found_keywords = [kw for kw in keywords if kw.lower() in script_text.lower()]
            
            if found_keywords:
                print(f"   🔑 Keywords found: {', '.join(found_keywords)}")
                
                # Show relevant excerpts
                lines = script_text.split('\n')
                relevant_lines = []
                
                for line_num, line in enumerate(lines, 1):
                    line_lower = line.lower()
                    if any(kw.lower() in line_lower for kw in keywords):
                        relevant_lines.append((line_num, line.strip()))
                
                if relevant_lines:
                    print(f"\n   📋 Relevant lines ({len(relevant_lines)} found):")
                    for line_num, line in relevant_lines[:20]:  # Show first 20
                        if line and len(line) < 200:
                            print(f"      L{line_num:3d}: {line}")
                
                # Look for URLs in the script
                urls = re.findall(r'https?://[^\s<>"\']+', script_text)
                if urls:
                    print(f"\n   🔗 URLs found in script:")
                    for url in urls[:10]:
                        print(f"      • {url}")
                
                # Look for object.elements pattern
                if 'object.elements' in script_text:
                    print(f"\n   ⚡ Found object.elements!")
                    # Try to find what populates it
                    elements_context = []
                    for line_num, line in enumerate(lines, 1):
                        if 'object.elements' in line or 'allData' in line:
                            # Get surrounding context
                            start = max(0, line_num - 3)
                            end = min(len(lines), line_num + 3)
                            context = lines[start:end]
                            elements_context.extend([(start + i + 1, l) for i, l in enumerate(context)])
                    
                    if elements_context:
                        print("   Context around object.elements:")
                        for line_num, line in elements_context[:30]:
                            print(f"      L{line_num:3d}: {line.strip()[:150]}")
            else:
                print("   (No relevant keywords found)")

def check_for_data_sources():
    """Check for potential data sources"""
    print("\n\n" + "=" * 80)
    print("🔍 Checking Potential Data Sources")
    print("=" * 80)
    
    potential_endpoints = [
        "https://transalta.com/wp-content/uploads/river-flows-data.json",
        "https://transalta.com/wp-content/uploads/flow-data.json",
        "https://transalta.com/data/river-flows.json",
        "https://transalta.com/api/flows.json",
    ]
    
    for endpoint in potential_endpoints:
        print(f"\n🧪 Testing: {endpoint}")
        try:
            response = requests.get(endpoint, headers=HEADERS, timeout=5)
            print(f"   Status: {response.status_code}")
            if response.status_code == 200:
                print(f"   ✅ SUCCESS!")
                print(f"   Content preview: {response.text[:300]}")
        except Exception as e:
            print(f"   ❌ {e}")

def main():
    investigate_scripts()
    check_for_data_sources()
    
    print("\n\n" + "=" * 80)
    print("💡 Next Steps")
    print("=" * 80)
    print("""
Based on the investigation, the data is likely:
1. Loaded from an external JavaScript file
2. Fetched via AJAX after page load
3. Embedded in a form or object that we haven't found yet

To find the actual data source:
1. Open https://transalta.com/river-flows/ in browser
2. Open DevTools Network tab
3. Refresh and look for XHR/Fetch requests
4. Check requests with 'flow', 'data', 'json', 'barrier', 'pocaterra'
5. Copy the request URL and add it to the script!
""")

if __name__ == "__main__":
    main()
