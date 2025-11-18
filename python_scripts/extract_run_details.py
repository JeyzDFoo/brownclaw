#!/usr/bin/env python3
"""
Extract detailed information from individual BC Whitewater run pages.
Saves each run as a separate JSON file.
"""

import requests
from bs4 import BeautifulSoup
import json
import time
import os
from typing import Dict, Optional, Tuple
import re
from datetime import datetime

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

def parse_difficulty(difficulty_text: str) -> Dict:
    """Parse difficulty rating into structured format."""
    result = {'text': difficulty_text}
    
    # Roman numeral to number mapping
    roman_map = {'I': 1, 'II': 2, 'III': 3, 'IV': 4, 'V': 5, 'VI': 6}
    
    # Extract roman numerals or numbers
    matches = re.findall(r'([IV]+|\d)[+-]?', difficulty_text)
    
    if matches:
        difficulties = []
        for match in matches:
            if match in roman_map:
                difficulties.append(roman_map[match])
            elif match.isdigit():
                difficulties.append(int(match))
        
        if difficulties:
            result['min'] = min(difficulties)
            result['max'] = max(difficulties)
    
    return result

def parse_length(text: str) -> Optional[Dict]:
    """Parse length into structured format with kilometers."""
    match = re.search(r'(\d+\.?\d*)\s*(km|miles?|mi)', text, re.IGNORECASE)
    if match:
        value = float(match.group(1))
        unit = match.group(2).lower()
        
        # Convert to km
        if 'mi' in unit:
            value = value * 1.60934
        
        return {
            'km': round(value, 2),
            'original': match.group(0)
        }
    return None

def parse_time(text: str) -> Optional[Dict]:
    """Parse time into structured format with hours."""
    # Handle day ranges (e.g., "1-2 days")
    day_match = re.search(r'(\d+)(?:\s*-\s*(\d+))?\s*days?', text, re.IGNORECASE)
    if day_match:
        min_days = int(day_match.group(1))
        max_days = int(day_match.group(2)) if day_match.group(2) else min_days
        return {
            'hours_min': min_days * 24,
            'hours_max': max_days * 24,
            'original': text.strip()
        }
    
    # Handle hour ranges (e.g., "1-3 hours")
    hour_match = re.search(r'(\d+)(?:\s*-\s*(\d+))?\s*hours?', text, re.IGNORECASE)
    if hour_match:
        min_hours = int(hour_match.group(1))
        max_hours = int(hour_match.group(2)) if hour_match.group(2) else min_hours
        return {
            'hours_min': min_hours,
            'hours_max': max_hours,
            'original': text.strip()
        }
    
    return {'original': text.strip()}

def parse_flow_range(text: str) -> Optional[Dict]:
    """Extract flow ranges from text (e.g., '10-20cms')."""
    # Look for patterns like "10-20cms", "100 cms", "below 10cms"
    range_match = re.search(r'(\d+\.?\d*)\s*-\s*(\d+\.?\d*)\s*(cms|cfs|m³/s)', text, re.IGNORECASE)
    if range_match:
        return {
            'min': float(range_match.group(1)),
            'max': float(range_match.group(2)),
            'unit': range_match.group(3).lower()
        }
    
    # Single value with comparison (e.g., "below 10cms", "above 100cms")
    single_match = re.search(r'(?:below|above|over|under|less than|more than)\s+(\d+\.?\d*)\s*(cms|cfs|m³/s)', text, re.IGNORECASE)
    if single_match:
        value = float(single_match.group(1))
        unit = single_match.group(2).lower()
        
        if 'below' in text.lower() or 'under' in text.lower() or 'less' in text.lower():
            return {'max': value, 'unit': unit}
        else:
            return {'min': value, 'unit': unit}
    
    return None

def extract_run_details(url: str) -> Dict:
    """Extract detailed information from a run page."""
    print(f"\nCrawling: {url}")
    soup = fetch_page(url)
    
    if not soup:
        return {'url': url, 'error': 'Failed to fetch page'}
    
    # Generate document ID from URL slug
    doc_id = url.rstrip('/').split('/')[-1]
    
    run_data = {
        'id': doc_id,
        'url': url,
        'source': 'bcwhitewater.org',
        'country': 'Canada',
        'province': 'British Columbia',
        'last_updated': datetime.utcnow().isoformat() + 'Z'
    }
    
    # Extract title
    title = soup.find('h1')
    if title:
        run_data['title'] = title.get_text(strip=True)
        print(f"Title: {run_data['title']}")
    
    # Extract river name (usually before the dash in title)
    if 'title' in run_data:
        # Try to parse "River Name - Section Name"
        if ' - ' in run_data['title']:
            parts = run_data['title'].split(' - ', 1)
            run_data['river_name'] = parts[0].strip()
            run_data['section_name'] = parts[1].strip()
        else:
            run_data['river_name'] = run_data['title']
    
    # Extract contributor
    contributor = soup.find(text=re.compile(r'Contributed by', re.IGNORECASE))
    if contributor:
        contrib_match = re.search(r'Contributed by\s+(.+)', contributor.strip())
        if contrib_match:
            run_data['contributor'] = contrib_match.group(1).strip()
            print(f"Contributor: {run_data['contributor']}")
    
    # Look for metadata in definition lists or labeled sections
    # Common fields: Class/Difficulty, Length, Gradient, Flow, Put-in, Take-out
    
    # Try to find all text content and parse it
    content = soup.find('div', class_=['content', 'reach-content', 'main-content'])
    if not content:
        content = soup.find('main')
    if not content:
        content = soup
    
    text = content.get_text()
    
    # Extract structured fields - these often appear as labeled sections
    
    # What It's Like
    whats_like_match = re.search(r"What It's Like\s*\n\s*(.+?)(?:\n[A-Z]|\Z)", text, re.IGNORECASE | re.DOTALL)
    if whats_like_match:
        run_data['whats_it_like'] = whats_like_match.group(1).strip()
        print(f"What It's Like: {run_data['whats_it_like'][:50]}...")
    
    # Extract difficulty/class
    class_match = re.search(r'Class\s*\n\s*(.+?)(?:\n[A-Z]|\Z)', text, re.DOTALL)
    if not class_match:
        class_match = re.search(r'(?:Class|Grade|Difficulty)[\s:]+([IV]+[+-]?(?:\s+with\s+.+?)?|\d[+-]?(?:\s+with\s+.+?)?)', text, re.IGNORECASE)
    if class_match:
        difficulty_text = class_match.group(1).strip()
        run_data['difficulty'] = parse_difficulty(difficulty_text)
        print(f"Difficulty: {run_data['difficulty']['text']} (min: {run_data['difficulty'].get('min', 'N/A')}, max: {run_data['difficulty'].get('max', 'N/A')})")
    
    # Scouting/Portaging
    scout_match = re.search(r'Scouting\s*/\s*Portaging\s*\n\s*(.+?)(?:\n[A-Z]|\Z)', text, re.IGNORECASE | re.DOTALL)
    if scout_match:
        run_data['scouting_portaging'] = scout_match.group(1).strip()
        print(f"Scouting/Portaging info found")
    
    # Time
    time_match = re.search(r'Time\s*\n\s*(.+?)(?:\n[A-Z]|\Z)', text, re.DOTALL)
    if time_match:
        time_text = time_match.group(1).strip()
        run_data['time'] = parse_time(time_text)
        if 'hours_min' in run_data['time']:
            print(f"Time: {run_data['time']['hours_min']}-{run_data['time']['hours_max']} hours")
        else:
            print(f"Time: {run_data['time']['original']}")
    
    # When to Go / Season
    when_match = re.search(r'When to Go\s*\n\s*(.+?)(?:\n[A-Z]|\Z)', text, re.DOTALL)
    if when_match:
        run_data['when_to_go'] = when_match.group(1).strip()
        print(f"When to Go: {run_data['when_to_go']}")
    
    # Gauge - extract both display text and Environment Canada station ID
    gauge_match = re.search(r'Gauge\s*\n\s*(.+?)(?:\n\n|\Z)', text, re.DOTALL)
    if gauge_match:
        run_data['gauge'] = gauge_match.group(1).strip()
        print(f"Gauge: {run_data['gauge'][:50]}...")
    
    # Extract Environment Canada gauge station ID from links
    # Look for wateroffice.ec.gc.ca links which contain station IDs
    ec_links = soup.find_all('a', href=re.compile(r'wateroffice\.ec\.gc\.ca'))
    if ec_links:
        gauge_stations = {}  # Use dict to deduplicate by station_id
        for link in ec_links:
            # Extract station ID from URL (e.g., stn=08MB006)
            href = link.get('href', '')
            station_match = re.search(r'stn=([A-Z0-9]+)', href)
            if station_match:
                station_id = station_match.group(1)
                station_text = link.get_text(strip=True)
                
                # If we haven't seen this station yet, or this looks like a proper name
                if station_id not in gauge_stations or len(station_text) > len(gauge_stations[station_id]['name']):
                    # Prefer longer text (usually the actual name vs just current reading)
                    if not re.match(r'^\d+\.?\d*\s*cms', station_text, re.IGNORECASE):
                        gauge_stations[station_id] = {
                            'station_id': station_id,
                            'name': station_text,
                            'url': href
                        }
        
        if gauge_stations:
            run_data['gauge_stations'] = list(gauge_stations.values())
            print(f"Found {len(gauge_stations)} Environment Canada gauge station(s)")
            for station in gauge_stations.values():
                print(f"  - {station['station_id']}: {station['name']}")
    
    # Extract flow ranges from all text content
    flow_range = parse_flow_range(text)
    if flow_range:
        run_data['flow_range'] = flow_range
        range_str = f"{flow_range.get('min', '?')}-{flow_range.get('max', '?')} {flow_range.get('unit', '')}" if 'min' in flow_range and 'max' in flow_range else str(flow_range)
        print(f"Flow range: {range_str}")
    
    # Extract length
    length_match = re.search(r'(?:Length|Distance)[\s:]*(\d+\.?\d*\s*(?:km|miles?|mi))', text, re.IGNORECASE)
    if length_match:
        run_data['length'] = parse_length(length_match.group(0))
        if run_data['length']:
            print(f"Length: {run_data['length']['km']} km")
    
    # Extract gradient
    gradient_match = re.search(r'(?:Gradient|Grade)[\s:]*(\d+\.?\d*)\s*(?:m/km|ft/mi|%)?', text, re.IGNORECASE)
    if gradient_match:
        run_data['gradient'] = float(gradient_match.group(1))
        print(f"Gradient: {run_data['gradient']}")
    
    # Extract main description sections (Flows, Shuttle, On the water, etc.)
    # These are typically large text blocks after section headers marked with <strong> tags
    
    # Find all strong tags which often mark section headers
    strong_tags = soup.find_all('strong')
    sections = {}
    
    for strong in strong_tags:
        header_text = strong.get_text(strip=True).lower()
        
        # Get content after this strong tag until next strong tag or end
        current = strong.next_sibling
        section_content = []
        
        while current:
            if hasattr(current, 'name') and current.name == 'strong':
                break
            if hasattr(current, 'get_text'):
                text_content = current.get_text(strip=True)
                if text_content:
                    section_content.append(text_content)
            elif isinstance(current, str):
                text_content = current.strip()
                if text_content:
                    section_content.append(text_content)
            current = current.next_sibling
        
        if section_content:
            sections[header_text] = ' '.join(section_content)
    
    # Extract specific sections
    if 'flows' in sections:
        run_data['flows_description'] = sections['flows']
        print(f"Flows description: {len(run_data['flows_description'])} chars")
    
    if 'shuttle' in sections:
        run_data['shuttle_description'] = sections['shuttle']
        print(f"Shuttle description: {len(run_data['shuttle_description'])} chars")
    
    if 'on the water' in sections:
        run_data['on_the_water_description'] = sections['on the water']
        print(f"On the water description: {len(run_data['on_the_water_description'])} chars")
    
    # Try to find general description paragraphs (first substantial content after title)
    paragraphs = content.find_all('p')
    descriptions = []
    for p in paragraphs:
        p_text = p.get_text(strip=True)
        if len(p_text) > 50:  # Filter out short paragraphs
            descriptions.append(p_text)
    
    if descriptions:
        run_data['description'] = descriptions[0] if descriptions else ''  # First substantial paragraph
        print(f"Main description: {len(run_data['description'])} chars")
    
    # Look for coordinates/location
    coords_match = re.search(r'(-?\d+\.?\d*)\s*,\s*(-?\d+\.?\d*)', text)
    if coords_match:
        run_data['coordinates'] = {
            'latitude': float(coords_match.group(1)),
            'longitude': float(coords_match.group(2))
        }
        print(f"Coordinates: {run_data['coordinates']}")
    
    # Look for permit requirements
    if re.search(r'permit\s+required', text, re.IGNORECASE):
        run_data['permit_required'] = True
        print("Permit required: Yes")
    
    return run_data

def main():
    """Extract details for all runs."""
    print("BC Whitewater Run Detail Extractor - Processing All Runs")
    print("=" * 60)
    
    # Load the list of runs
    with open('run_data/bc_whitewater_runs.json', 'r', encoding='utf-8') as f:
        runs = json.load(f)
    
    print(f"\nFound {len(runs)} runs to process")
    
    # Create output directory if it doesn't exist
    os.makedirs('run_data/detailed_runs', exist_ok=True)
    
    # Track success/failure
    success_count = 0
    failed_runs = []
    
    # Process each run
    for i, run in enumerate(runs, 1):
        print(f"\n[{i}/{len(runs)}] Processing: {run['url'].split('/')[-1]}")
        
        try:
            # Extract details
            details = extract_run_details(run['url'])
            
            # Check for errors
            if 'error' in details:
                failed_runs.append((run['url'], details['error']))
                print(f"  ❌ Failed: {details['error']}")
                continue
            
            # Generate filename from document ID
            filename = details['id'] + '.json'
            output_path = f'run_data/detailed_runs/{filename}'
            
            # Save to file
            with open(output_path, 'w', encoding='utf-8') as f:
                json.dump(details, f, indent=2, ensure_ascii=False)
            
            success_count += 1
            print(f"  ✅ Saved to {filename}")
            
            # Be polite - delay between requests
            time.sleep(1)
            
        except Exception as e:
            failed_runs.append((run['url'], str(e)))
            print(f"  ❌ Exception: {e}")
            continue
    
    # Summary
    print("\n" + "=" * 60)
    print("EXTRACTION COMPLETE")
    print("=" * 60)
    print(f"✅ Successfully processed: {success_count}/{len(runs)}")
    print(f"❌ Failed: {len(failed_runs)}/{len(runs)}")
    
    if failed_runs:
        print("\nFailed runs:")
        for url, error in failed_runs[:10]:  # Show first 10
            print(f"  - {url.split('/')[-1]}: {error}")
        if len(failed_runs) > 10:
            print(f"  ... and {len(failed_runs) - 10} more")
    
    print(f"\n📁 All data saved to: run_data/detailed_runs/")
    print(f"📊 Total JSON files created: {success_count}")

if __name__ == "__main__":
    main()
