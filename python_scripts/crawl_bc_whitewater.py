#!/usr/bin/env python3
"""
Crawl BC Whitewater website for river run data.
Extracts information about whitewater kayaking runs in British Columbia.
"""

import requests
from bs4 import BeautifulSoup
import json
import time
from typing import List, Dict, Optional
from urllib.parse import urljoin

BASE_URL = "https://www.bcwhitewater.org"
REACHES_URL = f"{BASE_URL}/reaches"

def fetch_page(url: str) -> Optional[BeautifulSoup]:
    """Fetch and parse a webpage."""
    try:
        headers = {
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
        }
        response = requests.get(url, headers=headers, timeout=10)
        response.raise_for_status()
        return BeautifulSoup(response.content, 'html.parser')
    except requests.RequestException as e:
        print(f"Error fetching {url}: {e}")
        return None

def extract_river_runs(soup: BeautifulSoup) -> List[Dict]:
    """Extract river run information from the reaches page."""
    runs = []
    
    # Look for common patterns in river run listings
    # This will need to be adjusted based on actual page structure
    
    # Try to find table rows or list items with run information
    run_elements = soup.find_all(['tr', 'li', 'div'], class_=lambda x: x and ('reach' in x.lower() or 'run' in x.lower()))
    
    if not run_elements:
        # Try alternative: find all links that might be runs
        run_elements = soup.find_all('a', href=lambda x: x and '/reach/' in x)
    
    for element in run_elements:
        run_data = {}
        
        # Extract link
        link = element.find('a') if element.name != 'a' else element
        if link and link.get('href'):
            run_data['url'] = urljoin(BASE_URL, link['href'])
            run_data['name'] = link.get_text(strip=True)
        
        # Try to extract difficulty/class
        text = element.get_text()
        if 'Class' in text or 'Grade' in text:
            # Look for class rating (e.g., "Class IV", "Grade III+")
            import re
            class_match = re.search(r'(?:Class|Grade)\s+([IV]+[+-]?|\d[+-]?)', text)
            if class_match:
                run_data['difficulty'] = class_match.group(1)
        
        if run_data:
            runs.append(run_data)
    
    return runs

def crawl_individual_run(url: str) -> Dict:
    """Crawl an individual run page for detailed information."""
    print(f"Crawling: {url}")
    soup = fetch_page(url)
    
    if not soup:
        return {}
    
    run_details = {'url': url}
    
    # Extract title/name
    title = soup.find('h1')
    if title:
        run_details['name'] = title.get_text(strip=True)
    
    # Look for common metadata fields
    # Difficulty, length, gradient, flow info, etc.
    metadata = soup.find_all(['dt', 'dd', 'span', 'div'], class_=lambda x: x and any(
        keyword in x.lower() for keyword in ['difficulty', 'class', 'length', 'gradient', 'flow', 'putin', 'takeout']
    ))
    
    for element in metadata:
        text = element.get_text(strip=True)
        if text:
            # Try to categorize the data
            if 'class' in text.lower() or 'difficulty' in text.lower():
                run_details['difficulty'] = text
            elif 'length' in text.lower():
                run_details['length'] = text
            elif 'gradient' in text.lower():
                run_details['gradient'] = text
            elif 'flow' in text.lower():
                run_details['flow_info'] = text
    
    # Extract description
    description = soup.find(['div', 'p'], class_=lambda x: x and 'description' in x.lower())
    if description:
        run_details['description'] = description.get_text(strip=True)
    
    # Be polite - delay between requests
    time.sleep(1)
    
    return run_details

def main():
    """Main crawling function."""
    print(f"Crawling BC Whitewater: {REACHES_URL}")
    print("=" * 60)
    
    # Fetch main reaches page
    soup = fetch_page(REACHES_URL)
    
    if not soup:
        print("Failed to fetch main page. Exiting.")
        return
    
    # Extract initial list of runs
    print("\n1. Extracting list of river runs...")
    runs = extract_river_runs(soup)
    print(f"Found {len(runs)} potential runs")
    
    # Optionally crawl individual run pages
    # Uncomment to enable detailed crawling (takes longer)
    """
    detailed_runs = []
    print("\n2. Crawling individual run pages...")
    for i, run in enumerate(runs[:5], 1):  # Limit to first 5 for testing
        if 'url' in run:
            print(f"[{i}/{len(runs[:5])}] {run.get('name', 'Unknown')}")
            details = crawl_individual_run(run['url'])
            detailed_runs.append(details)
    
    runs = detailed_runs
    """
    
    # Save results
    output_file = 'run_data/bc_whitewater_runs.json'
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(runs, f, indent=2, ensure_ascii=False)
    
    print(f"\n✅ Saved {len(runs)} runs to {output_file}")
    print("\nSample data:")
    for run in runs[:3]:
        print(f"  - {run.get('name', 'N/A')}: {run.get('url', 'N/A')}")

if __name__ == "__main__":
    main()
