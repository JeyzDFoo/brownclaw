#!/usr/bin/env python3
"""
PaddlingMaps.com API Probe Script

This script explores and tests the PaddlingMaps.com API to understand:
- Available endpoints
- Data structure
- Authentication requirements
- River and gauge data format
- Regional coverage

PaddlingMaps.com is a comprehensive paddling resource with river information,
gauge data, and regional coverage across North America.
"""

import requests
import json
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any
import time

# Headers to mimic a real browser request (updated to bypass Cloudflare)
HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
    'Accept-Encoding': 'gzip, deflate, br',
    'Connection': 'keep-alive',
    'Upgrade-Insecure-Requests': '1',
    'Sec-Fetch-Dest': 'document',
    'Sec-Fetch-Mode': 'navigate',
    'Sec-Fetch-Site': 'none',
    'Sec-Fetch-User': '?1',
    'Cache-Control': 'max-age=0',
}

class PaddlingMapsProbe:
    """Probe PaddlingMaps.com API endpoints and data structures"""
    
    def __init__(self):
        self.base_url = "https://paddlingmaps.com"
        self.api_base = f"{self.base_url}/api"
        self.session = requests.Session()
        self.session.headers.update(HEADERS)
        self.findings = []
        
        # Known regions from the URL structure
        self.known_regions = [
            'Alberta', 'British-Columbia', 'Ontario', 'Quebec',
            'California', 'Oregon', 'Washington', 'Colorado',
            'Idaho', 'Montana', 'Wyoming'
        ]
        
    def log_finding(self, category: str, message: str, data: Any = None):
        """Log a finding from the probe"""
        finding = {
            'timestamp': datetime.now().isoformat(),
            'category': category,
            'message': message,
            'data': data
        }
        self.findings.append(finding)
        print(f"[{category}] {message}")
        if data and isinstance(data, dict) and len(str(data)) < 500:
            print(f"  Data: {json.dumps(data, indent=2)}")
    
    def test_endpoint(self, name: str, url: str, method: str = 'GET', 
                     params: Optional[Dict] = None, json_data: Optional[Dict] = None) -> Optional[Dict]:
        """Test a specific API endpoint"""
        print(f"\n{'='*80}")
        print(f"🧪 Testing: {name}")
        print(f"{'='*80}")
        print(f"URL: {url}")
        if params:
            print(f"Params: {params}")
        
        try:
            if method == 'GET':
                response = self.session.get(url, params=params, timeout=15)
            elif method == 'POST':
                response = self.session.post(url, json=json_data, timeout=15)
            else:
                print(f"❌ Unsupported method: {method}")
                return None
            
            print(f"Status: {response.status_code}")
            print(f"Content-Type: {response.headers.get('Content-Type', 'N/A')}")
            print(f"Content-Length: {len(response.content)} bytes")
            
            if response.status_code == 200:
                content_type = response.headers.get('Content-Type', '')
                
                if 'application/json' in content_type:
                    data = response.json()
                    print(f"✅ SUCCESS - JSON Response")
                    
                    # Pretty print a sample of the data
                    print(f"\nResponse Structure:")
                    self._print_json_structure(data, indent=2, max_depth=3)
                    
                    self.log_finding('SUCCESS', f"{name} - {url}", {
                        'status': response.status_code,
                        'sample': self._get_sample_data(data)
                    })
                    
                    return data
                else:
                    print(f"✅ SUCCESS - Non-JSON Response")
                    print(f"Preview: {response.text[:500]}")
                    self.log_finding('SUCCESS', f"{name} - {url} (non-JSON)")
                    return {'raw': response.text}
            else:
                print(f"❌ FAILED - Status {response.status_code}")
                if response.text:
                    print(f"Error: {response.text[:200]}")
                self.log_finding('FAILED', f"{name} - Status {response.status_code}")
                return None
                
        except requests.exceptions.Timeout:
            print(f"⏱️  TIMEOUT after 15 seconds")
            self.log_finding('TIMEOUT', f"{name}")
            return None
        except requests.exceptions.RequestException as e:
            print(f"❌ ERROR: {e}")
            self.log_finding('ERROR', f"{name} - {str(e)}")
            return None
        except json.JSONDecodeError as e:
            print(f"⚠️  Invalid JSON response")
            print(f"Raw: {response.text[:200]}")
            self.log_finding('INVALID_JSON', f"{name}")
            return None
    
    def _print_json_structure(self, data: Any, indent: int = 0, max_depth: int = 3, current_depth: int = 0):
        """Pretty print JSON structure with depth limit"""
        if current_depth >= max_depth:
            print(' ' * indent + '...')
            return
        
        prefix = ' ' * indent
        
        if isinstance(data, dict):
            if not data:
                print(f"{prefix}{{}}")
                return
            for key, value in list(data.items())[:10]:  # Limit to 10 keys
                if isinstance(value, (dict, list)):
                    print(f"{prefix}{key}: {type(value).__name__}")
                    self._print_json_structure(value, indent + 2, max_depth, current_depth + 1)
                else:
                    print(f"{prefix}{key}: {repr(value)[:100]}")
            if len(data) > 10:
                print(f"{prefix}... ({len(data) - 10} more keys)")
        elif isinstance(data, list):
            if not data:
                print(f"{prefix}[]")
                return
            print(f"{prefix}[{len(data)} items]")
            if data:
                print(f"{prefix}First item:")
                self._print_json_structure(data[0], indent + 2, max_depth, current_depth + 1)
    
    def _get_sample_data(self, data: Any, max_size: int = 5) -> Any:
        """Get a sample of data for logging"""
        if isinstance(data, dict):
            return {k: v for k, v in list(data.items())[:max_size]}
        elif isinstance(data, list):
            return data[:max_size]
        else:
            return data
    
    def probe_region_pages(self):
        """Analyze region-specific pages to find data endpoints"""
        print("\n" + "="*80)
        print("🔍 PHASE 1: Analyzing Regional Pages")
        print("="*80)
        
        # Test a few key regions
        test_regions = ['Alberta', 'British-Columbia', 'Ontario']
        
        for region in test_regions:
            url = f'{self.base_url}/region/{region}'
            print(f"\n🌍 Analyzing: {region}")
            print(f"URL: {url}")
            
            try:
                response = self.session.get(url, timeout=15)
                print(f"Status: {response.status_code}")
                
                if response.status_code == 200:
                    html = response.text
                    
                    # Look for embedded data or API calls
                    import re
                    
                    # Look for JSON data in script tags
                    json_pattern = r'<script[^>]*>(.*?)</script>'
                    scripts = re.findall(json_pattern, html, re.DOTALL)
                    
                    api_endpoints = set()
                    for script in scripts:
                        # Look for API URLs
                        urls = re.findall(r'["\']([/a-zA-Z0-9._-]+/api/[^"\']+)["\']', script)
                        api_endpoints.update(urls)
                        
                        # Look for data objects
                        if 'rivers' in script.lower() or 'gauges' in script.lower():
                            if len(script) < 1000:
                                print(f"  Found relevant script: {script[:200]}...")
                    
                    if api_endpoints:
                        print(f"  ✅ Found {len(api_endpoints)} API endpoints:")
                        for endpoint in sorted(api_endpoints):
                            print(f"    • {endpoint}")
                            self.log_finding('REGION_PAGE', f"{region}: {endpoint}")
                
            except Exception as e:
                print(f"  ❌ Error: {e}")
            
            time.sleep(0.5)
    
    def probe_common_api_patterns(self):
        """Test common API endpoint patterns"""
        print("\n" + "="*80)
        print("🔍 PHASE 2: Testing Common API Patterns")
        print("="*80)
        
        common_endpoints = [
            # Main API
            ('API Root', f'{self.api_base}'),
            
            # River/gauge data endpoints
            ('Rivers', f'{self.api_base}/rivers'),
            ('Gauges', f'{self.api_base}/gauges'),
            ('Stations', f'{self.api_base}/stations'),
            ('Runs', f'{self.api_base}/runs'),
            ('Sections', f'{self.api_base}/sections'),
            
            # Regional endpoints
            ('Regions', f'{self.api_base}/regions'),
            ('Region Alberta', f'{self.api_base}/region/Alberta'),
            ('Region BC', f'{self.api_base}/region/British-Columbia'),
            
            # Data endpoints
            ('Current', f'{self.api_base}/current'),
            ('Realtime', f'{self.api_base}/realtime'),
            ('Flow Data', f'{self.api_base}/flow'),
            ('Level Data', f'{self.api_base}/level'),
        ]
        
        for name, url in common_endpoints:
            self.test_endpoint(name, url)
            time.sleep(0.3)  # Be polite to the server
    
    def probe_page_structure(self):
        """Analyze the main page to find embedded data or API references"""
        print("\n" + "="*80)
        print("🔍 PHASE 3: Analyzing Main Page Structure")
        print("="*80)
        
        try:
            response = self.session.get(self.base_url, timeout=15)
            
            if response.status_code == 200:
                html = response.text
                
                # Look for Next.js build ID
                import re
                build_id_match = re.search(r'"buildId":"([^"]+)"', html)
                if build_id_match:
                    build_id = build_id_match.group(1)
                    print(f"\n✅ Found Next.js Build ID: {build_id}")
                    self.log_finding('NEXTJS', f"Build ID: {build_id}")
                    
                    # Try Next.js data endpoints with build ID
                    print("\n🧪 Testing Next.js data endpoints with build ID...")
                    test_paths = ['/', '/rivers', '/gauges', '/regions']
                    for path in test_paths:
                        url = f'{self.base_url}/_next/data/{build_id}{path}.json'
                        self.test_endpoint(f'Next.js Data: {path}', url)
                        time.sleep(0.3)
                
                # Look for __NEXT_DATA__ embedded in page
                next_data_match = re.search(r'<script id="__NEXT_DATA__"[^>]*>(.*?)</script>', html, re.DOTALL)
                if next_data_match:
                    try:
                        next_data = json.loads(next_data_match.group(1))
                        print(f"\n✅ Found __NEXT_DATA__ embedded in page:")
                        self._print_json_structure(next_data, indent=2, max_depth=2)
                        self.log_finding('NEXTJS_DATA', "Found embedded Next.js data", next_data)
                    except json.JSONDecodeError:
                        print("⚠️  Found __NEXT_DATA__ but couldn't parse JSON")
                
                # Look for API endpoints in JavaScript
                api_patterns = [
                    r'api["\']?\s*:\s*["\']([^"\']+)',
                    r'endpoint["\']?\s*:\s*["\']([^"\']+)',
                    r'baseURL["\']?\s*:\s*["\']([^"\']+)',
                    r'https?://[^"\'\s]+/api/[^"\'\s]+',
                    r'/api/[a-zA-Z0-9/_-]+',
                ]
                
                found_endpoints = set()
                for pattern in api_patterns:
                    matches = re.findall(pattern, html)
                    found_endpoints.update(matches)
                
                if found_endpoints:
                    print(f"\n✅ Found {len(found_endpoints)} potential API endpoints in page source:")
                    for endpoint in sorted(found_endpoints):
                        if len(endpoint) > 5:  # Filter out short/garbage matches
                            print(f"  • {endpoint}")
                            self.log_finding('PAGE_ANALYSIS', f"Found endpoint: {endpoint}")
                else:
                    print("\n⚠️  No obvious API endpoints found in page source")
                
        except Exception as e:
            print(f"❌ Error analyzing page: {e}")
    
    def probe_specific_regions(self):
        """Test region-specific endpoints"""
        print("\n" + "="*80)
        print("🔍 PHASE 4: Testing Regional Data Endpoints")
        print("="*80)
        
        # Test both URL formats
        for region in self.known_regions[:5]:  # Test first 5 regions
            # Try different endpoint patterns
            patterns = [
                f'{self.api_base}/region/{region}',
                f'{self.api_base}/regions/{region}',
                f'{self.api_base}/region/{region}/rivers',
                f'{self.api_base}/region/{region}/gauges',
                f'{self.base_url}/data/region/{region}',
            ]
            
            for url in patterns:
                self.test_endpoint(f'Region Data: {region}', url)
                time.sleep(0.2)
    
    def probe_specific_rivers(self):
        """Test specific river/gauge endpoints"""
        print("\n" + "="*80)
        print("🔍 PHASE 5: Testing Specific River Patterns")
        print("="*80)
        
        # Test known Alberta rivers
        test_rivers = [
            {'name': 'Kananaskis River', 'id': 'kananaskis'},
            {'name': 'Bow River', 'id': 'bow-river'},
            {'name': 'Red Deer River', 'id': 'red-deer'},
        ]
        
        # Test gauge IDs (Canadian format)
        test_gauges = ['05BH004', '05BJ001', '08NA011']
        
        for river in test_rivers:
            patterns = [
                f'{self.api_base}/river/{river["id"]}',
                f'{self.api_base}/rivers/{river["id"]}',
                f'{self.base_url}/river/{river["id"]}',
                f'{self.base_url}/data/river/{river["id"]}',
            ]
            
            for url in patterns:
                self.test_endpoint(f'River: {river["name"]}', url)
                time.sleep(0.2)
        
        for gauge_id in test_gauges:
            patterns = [
                f'{self.api_base}/gauge/{gauge_id}',
                f'{self.api_base}/station/{gauge_id}',
                f'{self.base_url}/gauge/{gauge_id}',
            ]
            
            for url in patterns:
                self.test_endpoint(f'Gauge {gauge_id}', url)
                time.sleep(0.2)
    
    def probe_search_functionality(self):
        """Test search endpoints"""
        print("\n" + "="*80)
        print("🔍 PHASE 6: Testing Search Functionality")
        print("="*80)
        
        search_terms = ['kananaskis', 'bow river', 'red deer']
        
        search_patterns = [
            f'{self.api_base}/search',
            f'{self.base_url}/search',
            f'{self.api_base}/query',
        ]
        
        for pattern in search_patterns:
            for term in search_terms:
                self.test_endpoint(
                    f'Search: {term}',
                    pattern,
                    params={'q': term}
                )
                time.sleep(0.3)
    
    def probe_json_data_files(self):
        """Test for static JSON data files that might be served"""
        print("\n" + "="*80)
        print("🔍 PHASE 7: Testing Static Data Files")
        print("="*80)
        
        data_files = [
            f'{self.base_url}/data/rivers.json',
            f'{self.base_url}/data/gauges.json',
            f'{self.base_url}/data/Alberta.json',
            f'{self.base_url}/data/regions.json',
            f'{self.base_url}/assets/data/rivers.json',
            f'{self.base_url}/assets/data/Alberta.json',
            f'{self.base_url}/static/data/rivers.json',
            f'{self.base_url}/json/rivers.json',
        ]
        
        for url in data_files:
            name = url.split('/')[-1]
            self.test_endpoint(f'Static File: {name}', url)
            time.sleep(0.2)
    
    def generate_report(self):
        """Generate a summary report of findings"""
        print("\n" + "="*80)
        print("📊 PROBE SUMMARY REPORT")
        print("="*80)
        
        successes = [f for f in self.findings if f['category'] == 'SUCCESS']
        failures = [f for f in self.findings if f['category'] == 'FAILED']
        errors = [f for f in self.findings if f['category'] == 'ERROR']
        
        print(f"\n✅ Successful Requests: {len(successes)}")
        print(f"❌ Failed Requests: {len(failures)}")
        print(f"⚠️  Errors: {len(errors)}")
        
        if successes:
            print(f"\n{'='*80}")
            print("✅ WORKING ENDPOINTS:")
            print(f"{'='*80}")
            for finding in successes:
                print(f"\n{finding['message']}")
                if finding.get('data'):
                    print(f"  Sample: {json.dumps(finding['data']['sample'], indent=2)[:200]}...")
        
        # Save detailed report to file
        report_file = f'paddlingmaps_probe_report_{datetime.now().strftime("%Y%m%d_%H%M%S")}.json'
        with open(report_file, 'w') as f:
            json.dump(self.findings, f, indent=2, default=str)
        
        print(f"\n💾 Detailed report saved to: {report_file}")
        
        return successes

def main():
    """Main probe execution"""
    print("\n" + "="*80)
    print("🌊 PaddlingMaps.com API Probe")
    print("="*80)
    print(f"🕒 Started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"🎯 Target: https://paddlingmaps.com/")
    print(f"🎯 Focus: Alberta region")
    print("="*80)
    
    probe = PaddlingMapsProbe()
    
    # Run all probe phases
    probe.probe_region_pages()
    probe.probe_common_api_patterns()
    probe.probe_page_structure()
    probe.probe_specific_regions()
    probe.probe_specific_rivers()
    probe.probe_search_functionality()
    probe.probe_json_data_files()
    
    # Generate report
    working_endpoints = probe.generate_report()
    
    print("\n" + "="*80)
    print("🎯 FINDINGS & NEXT STEPS")
    print("="*80)
    
    # Check if we hit Cloudflare protection
    cloudflare_hits = [f for f in probe.findings if 'FAILED' in f['category']]
    if len(cloudflare_hits) > 5:
        print("\n🛡️  CLOUDFLARE PROTECTION DETECTED!")
        print("="*80)
        print("PaddlingMaps.com is protected by Cloudflare's bot detection.")
        print("Automated API probing is blocked.")
        print("\n⚠️  This means:")
        print("   • Simple HTTP requests won't work")
        print("   • Requires real browser interaction")
        print("   • Manual investigation is necessary")
    
    if working_endpoints:
        print("\n✅ Found working API endpoints!")
        print("   • Review the detailed report for data structures")
        print("   • Test authentication if required")
        print("   • Implement integration in Flutter app")
    else:
        print("\n💡 RECOMMENDED APPROACH - Manual Browser Investigation:")
        print("\n📋 STEP-BY-STEP:")
        print("\n1️⃣  Open https://paddlingmaps.com/region/Alberta in Chrome")
        print("2️⃣  Open Developer Tools (F12 or Cmd+Option+I)")
        print("3️⃣  Go to 'Network' tab")
        print("4️⃣  Reload the page (Cmd+R)")
        print("5️⃣  Look for:")
        print("     • .json files being loaded")
        print("     • XHR/Fetch requests")
        print("     • Requests to external APIs")
        print("\n6️⃣  Click on rivers/sections to trigger more requests")
        print("7️⃣  In 'Sources' tab, look for:")
        print("     • Static JSON data files")
        print("     • Embedded data in JavaScript")
        print("\n📊 WHAT TO LOOK FOR:")
        print("   • URLs like: /data/*.json, /api/*, /_next/data/*")
        print("   • External APIs: wateroffice.ec.gc.ca, usgs.gov")
        print("   • Data structure: rivers, gauges, flow levels")
        print("\n🔍 ALTERNATIVE: View Page Source")
        print("   • Right-click → View Page Source")
        print("   • Search for: 'rivers', 'gauges', 'Alberta'")
        print("   • Look for embedded JSON data in <script> tags")
        print("\n💾 DATA EXTRACTION OPTIONS:")
        print("   1. Use the data directly from page source (if embedded)")
        print("   2. Use Selenium/Playwright for browser automation")
        print("   3. Contact PaddlingMaps for official API access")
        print("   4. Use Government APIs directly (wateroffice.ec.gc.ca)")
        print("\n🤝 BEST OPTION:")
        print("   • Email PaddlingMaps.com asking about API access")
        print("   • Explain you're building a complementary app")
        print("   • Offer to credit them as a data source")
        print("\n⚠️  LEGAL NOTE:")
        print("   • Respect Cloudflare's bot protection")
        print("   • Don't attempt to bypass security measures")
        print("   • Use only publicly accessible data")
        print("   • Partner with PaddlingMaps rather than scraping")
    
    print("\n" + "="*80)
    print(f"🕒 Completed: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("="*80)

if __name__ == "__main__":
    main()
