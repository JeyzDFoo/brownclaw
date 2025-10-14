#!/usr/bin/env python3
"""
Comprehensive station discovery script for Canadian water monitoring stations.
This script attempts to discover and catalog ALL active water monitoring stations in Canada.
"""

import os
import sys
import json
import logging
import requests
from datetime import datetime, timezone
from typing import Dict, List, Optional
import firebase_admin
from firebase_admin import credentials, firestore
from dotenv import load_dotenv
import time
import concurrent.futures
from threading import Lock

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class ComprehensiveStationDiscovery:
    def __init__(self):
        """Initialize the comprehensive station discovery system."""
        self.db = None
        self.init_firebase()
        self.discovered_stations = []
        self.lock = Lock()
        
    def init_firebase(self):
        """Initialize Firebase Admin SDK."""
        try:
            cred_path = os.getenv('FIREBASE_CREDENTIALS_PATH')
            project_id = os.getenv('FIREBASE_PROJECT_ID', 'brownclaw')
            
            if cred_path and os.path.exists(cred_path):
                cred = credentials.Certificate(cred_path)
                firebase_admin.initialize_app(cred, {
                    'projectId': project_id
                })
                self.db = firestore.client()
                logger.info("Firebase initialized successfully")
            else:
                logger.warning("No Firebase credentials found. Running in demo mode.")
                self.db = None
        except Exception as e:
            logger.warning(f"Failed to initialize Firebase: {e}. Running in demo mode.")
            self.db = None
    
    def discover_all_stations(self) -> List[Dict]:
        """Discover all active water monitoring stations in Canada."""
        logger.info("Starting comprehensive station discovery...")
        
        # Method 1: Try official data sources
        stations = self.fetch_from_official_sources()
        
        # Method 2: If official sources fail, use systematic discovery
        if len(stations) < 100:  # Expect hundreds of stations
            logger.info("Official sources yielded limited results, starting systematic discovery...")
            discovered = self.systematic_station_discovery()
            stations.extend(discovered)
        
        # Remove duplicates
        unique_stations = self.remove_duplicates(stations)
        
        logger.info(f"Total unique stations discovered: {len(unique_stations)}")
        return unique_stations
    
    def fetch_from_official_sources(self) -> List[Dict]:
        """Attempt to fetch station data from official government sources."""
        stations = []
        
        # Known official data sources
        sources = [
            {
                'name': 'Environment Canada Open Data',
                'url': 'https://dd.weather.gc.ca/hydrometric/doc/hydrometric_StationList.csv'
            },
            {
                'name': 'WSC Real-time Station List',
                'url': 'https://wateroffice.ec.gc.ca/services/real_time_data/stations'
            },
            {
                'name': 'HYDAT Station Inventory',
                'url': 'https://collaboration.cmc.ec.gc.ca/cmc/hydrometrics/www/HydrometricNetworkBasinPoly.csv'
            }
        ]
        
        for source in sources:
            try:
                logger.info(f"Trying {source['name']}: {source['url']}")
                response = requests.get(source['url'], timeout=30)
                
                if response.status_code == 200:
                    parsed = self.parse_station_data(response.text, source['name'])
                    if parsed:
                        logger.info(f"Found {len(parsed)} stations from {source['name']}")
                        stations.extend(parsed)
                        break  # Use the first successful source
                        
            except Exception as e:
                logger.debug(f"Failed to fetch from {source['name']}: {e}")
                continue
        
        return stations
    
    def parse_station_data(self, data: str, source_name: str) -> List[Dict]:
        """Parse station data from various formats."""
        try:
            # Try CSV format first
            if ',' in data and '\n' in data:
                return self.parse_csv_data(data, source_name)
            
            # Try JSON format
            try:
                json_data = json.loads(data)
                return self.parse_json_data(json_data, source_name)
            except json.JSONDecodeError:
                pass
            
            return []
            
        except Exception as e:
            logger.error(f"Error parsing data from {source_name}: {e}")
            return []
    
    def parse_csv_data(self, csv_text: str, source_name: str) -> List[Dict]:
        """Parse CSV format station data."""
        stations = []
        lines = csv_text.strip().split('\n')
        
        if len(lines) < 2:
            return []
        
        headers = [h.strip().strip('"') for h in lines[0].split(',')]
        
        for line in lines[1:]:
            if not line.strip():
                continue
            
            # Simple CSV parsing
            values = [v.strip().strip('"') for v in line.split(',')]
            
            if len(values) >= len(headers):
                row_dict = dict(zip(headers, values))
                station = self.standardize_station_data(row_dict, source_name)
                if station:
                    stations.append(station)
        
        return stations
    
    def parse_json_data(self, json_data: Dict, source_name: str) -> List[Dict]:
        """Parse JSON format station data."""
        stations = []
        
        # Handle different JSON structures
        if isinstance(json_data, list):
            for item in json_data:
                station = self.standardize_station_data(item, source_name)
                if station:
                    stations.append(station)
        
        elif isinstance(json_data, dict):
            # Look for arrays in the JSON
            for key, value in json_data.items():
                if isinstance(value, list) and len(value) > 0:
                    for item in value:
                        if isinstance(item, dict):
                            station = self.standardize_station_data(item, source_name)
                            if station:
                                stations.append(station)
        
        return stations
    
    def standardize_station_data(self, raw_data: Dict, source: str) -> Optional[Dict]:
        """Convert raw station data to standardized format."""
        try:
            # Try different field name variations
            station_id = self.extract_field(raw_data, [
                'STATION_NUMBER', 'Station_Number', 'station_number', 'ID', 'id', 'StationID'
            ])
            
            station_name = self.extract_field(raw_data, [
                'STATION_NAME', 'Station_Name', 'station_name', 'NAME', 'name', 'StationName'
            ])
            
            if not station_id:
                return None
            
            # Create standardized station record
            station = {
                'id': str(station_id).strip().upper(),
                'name': str(station_name or f"Station {station_id}").strip(),
                'province': self.extract_field(raw_data, [
                    'PROV_TERR_STATE_LOC', 'Province', 'province', 'PROVINCE'
                ]) or self.get_province_from_id(station_id),
                'latitude': self.safe_float(self.extract_field(raw_data, [
                    'LATITUDE', 'Latitude', 'latitude', 'LAT', 'lat'
                ])),
                'longitude': self.safe_float(self.extract_field(raw_data, [
                    'LONGITUDE', 'Longitude', 'longitude', 'LON', 'lon'
                ])),
                'drainage_area': self.safe_float(self.extract_field(raw_data, [
                    'DRAINAGE_AREA_GROSS', 'drainage_area', 'DrainageArea'
                ])),
                'status': self.extract_field(raw_data, [
                    'HYD_STATUS', 'status', 'Status'
                ]) or 'Unknown',
                'data_source': source,
                'updated_at': datetime.now(timezone.utc).isoformat(),
                'is_whitewater': False,  # Will be updated later if applicable
            }
            
            return station
            
        except Exception as e:
            logger.debug(f"Error standardizing station data: {e}")
            return None
    
    def extract_field(self, data: Dict, field_names: List[str]) -> Optional[str]:
        """Extract a field from data using multiple possible field names."""
        for field in field_names:
            value = data.get(field)
            if value and str(value).strip():
                return str(value).strip()
        return None
    
    def safe_float(self, value: str) -> Optional[float]:
        """Safely convert string to float."""
        try:
            if value and str(value).strip():
                return float(str(value).strip())
        except (ValueError, TypeError):
            pass
        return None
    
    def get_province_from_id(self, station_id: str) -> str:
        """Determine province from WSC station ID."""
        if not station_id or len(station_id) < 2:
            return 'Unknown'
            
        prefix = station_id[:2]
        province_map = {
            '01': 'Atlantic Canada',
            '02': 'Ontario/Quebec',
            '03': 'Ontario/Quebec',
            '04': 'Ontario/Quebec',
            '05': 'Prairie Provinces',
            '06': 'Prairie Provinces',
            '07': 'Prairie Provinces',
            '08': 'British Columbia',
            '09': 'Northern Canada',
            '10': 'Northern Canada'
        }
        
        return province_map.get(prefix, 'Canada')
    
    def systematic_station_discovery(self) -> List[Dict]:
        """Systematically discover stations by testing ID patterns."""
        logger.info("Starting systematic station discovery (this may take 10-20 minutes)...")
        
        # WSC station ID patterns
        prefixes = []
        
        # Generate all possible 2-digit prefixes
        for first_digit in range(1, 11):  # 01-10
            prefix = f"{first_digit:02d}"
            
            # Add letter suffixes A-Z
            for letter in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ':
                prefixes.append(f"{prefix}{letter}")
        
        # Use threading to speed up discovery
        logger.info(f"Testing {len(prefixes)} station prefixes...")
        
        with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
            futures = []
            
            for prefix in prefixes:
                future = executor.submit(self.test_station_prefix, prefix)
                futures.append(future)
            
            # Collect results
            for future in concurrent.futures.as_completed(futures):
                try:
                    stations = future.result()
                    if stations:
                        with self.lock:
                            self.discovered_stations.extend(stations)
                            if len(self.discovered_stations) % 50 == 0:
                                logger.info(f"Discovered {len(self.discovered_stations)} active stations...")
                except Exception as e:
                    logger.debug(f"Error in station discovery thread: {e}")
        
        logger.info(f"Systematic discovery found {len(self.discovered_stations)} stations")
        return self.discovered_stations
    
    def test_station_prefix(self, prefix: str) -> List[Dict]:
        """Test a station prefix for active stations."""
        stations = []
        
        # Test common suffix patterns
        suffixes = ['001', '002', '003', '004', '005', '006', '007', '008', '009', '010',
                   '011', '012', '013', '014', '015', '016', '017', '018', '019', '020']
        
        for suffix in suffixes:
            station_id = f"{prefix}{suffix}"
            
            try:
                # Test if station has recent data
                url = f"https://wateroffice.ec.gc.ca/services/real_time_data/csv/inline"
                params = {
                    'stations[]': station_id,
                    'parameters[]': '47',  # Flow parameter
                    'start_date': '2025-10-01',
                    'end_date': '2025-10-14'
                }
                
                response = requests.get(url, params=params, timeout=5)
                
                if response.status_code == 200 and len(response.text) > 100:
                    lines = response.text.strip().split('\n')
                    if len(lines) > 1:  # Has data
                        station = {
                            'id': station_id,
                            'name': f"Station {station_id}",
                            'province': self.get_province_from_id(station_id),
                            'data_source': 'systematic_discovery',
                            'api_available': True,
                            'has_recent_data': True,
                            'updated_at': datetime.now(timezone.utc).isoformat(),
                            'is_whitewater': False,
                        }
                        stations.append(station)
                
                # Small delay to avoid overwhelming the API
                time.sleep(0.1)
                
            except Exception:
                continue  # Station doesn't exist or API error
        
        return stations
    
    def remove_duplicates(self, stations: List[Dict]) -> List[Dict]:
        """Remove duplicate stations based on station ID."""
        seen = set()
        unique_stations = []
        
        for station in stations:
            station_id = station.get('id')
            if station_id and station_id not in seen:
                seen.add(station_id)
                unique_stations.append(station)
        
        return unique_stations
    
    def save_stations_to_firestore(self, stations: List[Dict]):
        """Save all discovered stations to Firestore."""
        if self.db is None:
            logger.info("Demo mode: Would save stations to Firestore")
            self.print_sample_stations(stations)
            return
        
        try:
            collection_ref = self.db.collection('water_stations')
            batch = self.db.batch()
            
            batch_count = 0
            total_saved = 0
            
            for station in stations:
                station_id = station.get('id')
                if not station_id:
                    continue
                
                doc_ref = collection_ref.document(station_id)
                batch.set(doc_ref, station)
                batch_count += 1
                
                # Firestore batch limit is 500
                if batch_count >= 500:
                    batch.commit()
                    total_saved += batch_count
                    logger.info(f"Saved batch of {batch_count} stations (total: {total_saved})")
                    batch = self.db.batch()
                    batch_count = 0
            
            # Commit remaining documents
            if batch_count > 0:
                batch.commit()
                total_saved += batch_count
            
            logger.info(f"Successfully saved {total_saved} stations to Firestore")
            
            # Update metadata
            self.update_metadata(total_saved)
            
        except Exception as e:
            logger.error(f"Failed to save stations to Firestore: {e}")
            raise
    
    def print_sample_stations(self, stations: List[Dict]):
        """Print sample station data for demo mode."""
        logger.info(f"Found {len(stations)} total stations. Here are samples by province:")
        
        # Group by province for display
        by_province = {}
        for station in stations:
            province = station.get('province', 'Unknown')
            if province not in by_province:
                by_province[province] = []
            by_province[province].append(station)
        
        for province, province_stations in by_province.items():
            print(f"\n{province}: {len(province_stations)} stations")
            # Show first 2 stations from each province
            for station in province_stations[:2]:
                print(f"  {station['id']}: {station['name']}")
    
    def update_metadata(self, station_count: int):
        """Update metadata about the comprehensive sync."""
        if self.db is None:
            return
        
        try:
            metadata = {
                'last_updated': datetime.now(timezone.utc).isoformat(),
                'station_count': station_count,
                'sync_type': 'comprehensive_discovery'
            }
            
            self.db.collection('metadata').document('comprehensive_sync').set(metadata)
            logger.info("Updated comprehensive sync metadata")
            
        except Exception as e:
            logger.warning(f"Failed to update metadata: {e}")
    
    def run(self):
        """Main execution method."""
        logger.info("Starting comprehensive Canadian water station discovery...")
        
        try:
            stations = self.discover_all_stations()
            
            if not stations:
                logger.error("No stations discovered")
                return False
            
            self.save_stations_to_firestore(stations)
            
            logger.info("Comprehensive station discovery completed successfully")
            return True
            
        except Exception as e:
            logger.error(f"Comprehensive discovery failed: {e}")
            return False

def main():
    """Main entry point."""
    print("🌊 Comprehensive Canadian Water Station Discovery")
    print("=" * 50)
    print("This will attempt to discover ALL water monitoring stations in Canada.")
    print("This process may take 10-20 minutes depending on API response times.")
    print()
    
    confirm = input("Do you want to proceed? (y/N): ")
    if confirm.lower() != 'y':
        print("Discovery cancelled.")
        return
    
    discovery = ComprehensiveStationDiscovery()
    success = discovery.run()
    
    if success:
        print("✅ Comprehensive station discovery completed successfully!")
        sys.exit(0)
    else:
        print("❌ Comprehensive station discovery failed!")
        sys.exit(1)

if __name__ == "__main__":
    main()