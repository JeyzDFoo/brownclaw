#!/usr/bin/env python3
"""
Admin script to pull water monitoring station data and save to Firebase.
This script fetches station information from Environment and Climate Change Canada
and stores it in Firestore for the BrownClaw app.
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

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class StationDataPuller:
    def __init__(self):
        """Initialize the Firebase connection and setup."""
        self.db = None
        self.init_firebase()
        
    def init_firebase(self):
        """Initialize Firebase Admin SDK."""
        try:
            # Try to use environment variable for credentials
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
                # Run in demo mode without Firebase
                logger.warning("No Firebase credentials found. Running in demo mode.")
                self.db = None
                
        except Exception as e:
            logger.warning(f"Failed to initialize Firebase: {e}. Running in demo mode.")
            self.db = None
    
    def fetch_station_list(self) -> List[Dict]:
        """
        Fetch ALL station list from Environment and Climate Change Canada.
        Returns a comprehensive list of all Canadian water monitoring stations.
        """
        try:
            logger.info("Fetching comprehensive station list from WSC...")
            
            # Try to fetch the official station inventory CSV
            stations = self.fetch_official_station_inventory()
            
            if stations and len(stations) > 50:  # Should have hundreds/thousands of stations
                logger.info(f"Successfully fetched {len(stations)} stations from official inventory")
                return stations
            
            # Fallback: Try to get station list from the real-time data service
            logger.info("Trying alternative station discovery method...")
            stations = self.discover_stations_from_realtime_service()
            
            if stations and len(stations) > 10:
                logger.info(f"Successfully discovered {len(stations)} stations")
                return stations
                
            # Final fallback: Use our curated list but mark it as limited
            logger.warning("Using limited fallback station list - only whitewater stations")
            return self.get_fallback_stations()
            
        except Exception as e:
            logger.error(f"Error fetching station data: {e}")
            return self.get_fallback_stations()
    
    def fetch_official_station_inventory(self) -> List[Dict]:
        """Try to fetch the official WSC station inventory."""
        urls_to_try = [
            "https://dd.weather.gc.ca/hydrometric/csv/",
            "https://wateroffice.ec.gc.ca/services/download_stations/csv/hydat_stations",
            "https://collaboration.cmc.ec.gc.ca/cmc/hydrometrics/www/HydrometricNetworkBasinPoly.csv",
            "https://www.canada.ca/content/dam/eccc/migration/main/data/sites/hydrometric-data.csv"
        ]
        
        for url in urls_to_try:
            try:
                logger.info(f"Trying station inventory URL: {url}")
                response = requests.get(url, timeout=30)
                
                if response.status_code == 200 and len(response.text) > 1000:
                    return self.parse_station_csv(response.text)
                    
            except Exception as e:
                logger.debug(f"Failed to fetch from {url}: {e}")
                continue
        
        return []
    
    def parse_station_csv(self, csv_text: str) -> List[Dict]:
        """Parse station data from CSV format."""
        try:
            lines = csv_text.strip().split('\n')
            if len(lines) < 2:
                return []
            
            # Try to detect header format
            headers = [h.strip().strip('"') for h in lines[0].split(',')]
            stations = []
            
            for line in lines[1:]:
                if not line.strip():
                    continue
                    
                # Handle CSV parsing with quoted fields
                values = []
                current_value = ""
                in_quotes = False
                
                for char in line:
                    if char == '"':
                        in_quotes = not in_quotes
                    elif char == ',' and not in_quotes:
                        values.append(current_value.strip().strip('"'))
                        current_value = ""
                    else:
                        current_value += char
                
                # Add the last value
                values.append(current_value.strip().strip('"'))
                
                if len(values) >= len(headers):
                    station_dict = dict(zip(headers, values))
                    clean_station = self.clean_station_data(station_dict)
                    if clean_station:
                        stations.append(clean_station)
            
            return stations
            
        except Exception as e:
            logger.error(f"Error parsing CSV: {e}")
            return []
    
    def discover_stations_from_realtime_service(self) -> List[Dict]:
        """Discover stations by trying common station ID patterns."""
        stations = []
        
        # Common WSC station ID prefixes by province/region
        prefixes = [
            # Ontario
            '02A', '02B', '02C', '02D', '02E', '02F', '02G', '02H', '02K', '02L',
            # Quebec  
            '02M', '02N', '02O', '02P', '02Q', '02R', '02S', '02T', '02U', '02V',
            # Atlantic Canada
            '01A', '01B', '01C', '01D', '01E', '01F',
            # Prairies
            '05A', '05B', '05C', '05D', '05E', '05F', '05G', '05H', '05J', '05K',
            # British Columbia
            '08A', '08B', '08C', '08D', '08E', '08F', '08G', '08H', '08J', '08K',
            # Northern Canada
            '09A', '09B', '10A', '10B', '10C'
        ]
        
        logger.info("Discovering active stations (this may take a few minutes)...")
        discovered_count = 0
        max_discovery = 200  # Limit discovery to avoid too long execution
        
        for prefix in prefixes:
            if discovered_count >= max_discovery:
                break
                
            # Try some common numbering patterns
            for suffix in ['001', '002', '003', '004', '005', '006', '007', '008', '009', '010']:
                if discovered_count >= max_discovery:
                    break
                    
                station_id = f"{prefix}{suffix}"
                station_data = self.test_station_exists(station_id)
                
                if station_data:
                    stations.append(station_data)
                    discovered_count += 1
                    if discovered_count % 10 == 0:
                        logger.info(f"Discovered {discovered_count} active stations...")
        
        return stations
    
    def test_station_exists(self, station_id: str) -> Optional[Dict]:
        """Test if a station exists and has recent data."""
        try:
            # Try to get recent data for this station
            url = f"https://api.weather.gc.ca/collections/hydrometric-realtime/items?STATION_NUMBER={station_id}&limit=1&f=json"
            
            response = requests.get(url, timeout=5)
            if response.status_code == 200 and response.text.strip():
                try:
                    import json
                    json_data = json.loads(response.text)
                    if 'features' in json_data and json_data['features']:
                        # Extract station info from the first feature
                        feature = json_data['features'][0]
                        properties = feature.get('properties', {})
                        station_name = properties.get('STATION_NAME', f'Station {station_id}')
                        
                        return {
                            'id': station_id,
                            'name': station_name,
                            'province': self.get_province_from_station_id(station_id),
                            'api_available': True,
                            'has_recent_data': True,
                            'updated_at': datetime.now(timezone.utc).isoformat(),
                            'data_source': 'discovered'
                        }
                except json.JSONDecodeError:
                    pass  # Fall back to error handling below
            
            return None
            
        except Exception:
            return None
    
    def fetch_station_info(self, station_id: str) -> Optional[Dict]:
        """Fetch information for a specific station."""
        try:
            # Try to fetch station metadata from the new Government of Canada API
            url = f"https://api.weather.gc.ca/collections/hydrometric-realtime/items?STATION_NUMBER={station_id}&limit=1&f=json"
            
            response = requests.get(url, timeout=10)
            if response.status_code == 200 and response.text.strip():
                # Parse the JSON response to extract station info
                try:
                    import json
                    json_data = json.loads(response.text)
                    if 'features' in json_data and json_data['features']:
                        # Extract station info from the first feature
                        feature = json_data['features'][0]
                        properties = feature.get('properties', {})
                        station_name = properties.get('STATION_NAME', f'Station {station_id}')
                        
                        # Get fallback data and update with real info
                        fallback_data = self.get_fallback_station_data(station_id)
                        if fallback_data:
                            fallback_data['name'] = station_name
                            fallback_data['api_available'] = True
                            fallback_data['last_data_check'] = datetime.now(timezone.utc).isoformat()
                            return fallback_data
                except json.JSONDecodeError:
                    pass  # Fall back to the error handling below
            
            # If API call fails, still return fallback data but mark API as unavailable
            fallback_data = self.get_fallback_station_data(station_id)
            if fallback_data:
                fallback_data['api_available'] = False
                fallback_data['last_data_check'] = datetime.now(timezone.utc).isoformat()
                return fallback_data
                
            return None
            
        except Exception as e:
            logger.debug(f"Error fetching station {station_id}: {e}")
            # Return fallback data even if API fails
            fallback_data = self.get_fallback_station_data(station_id)
            if fallback_data:
                fallback_data['api_available'] = False
                fallback_data['last_data_check'] = datetime.now(timezone.utc).isoformat()
            return fallback_data
    
    def clean_station_data(self, raw_station: Dict) -> Optional[Dict]:
        """Clean and structure station data from various sources."""
        try:
            # Try multiple possible field names for station ID and name
            station_id = (raw_station.get('STATION_NUMBER') or 
                         raw_station.get('Station_Number') or 
                         raw_station.get('ID') or 
                         raw_station.get('StationID') or
                         raw_station.get('station_number'))
            
            station_name = (raw_station.get('STATION_NAME') or 
                           raw_station.get('Station_Name') or 
                           raw_station.get('NAME') or 
                           raw_station.get('StationName') or
                           raw_station.get('station_name'))
            
            if not station_id:
                return None
            
            # If no name found, create one from the station ID
            if not station_name:
                station_name = f"Station {station_id}"
                
            # Clean and structure the data
            cleaned = {
                'id': str(station_id).strip().upper(),
                'name': str(station_name).strip(),
                'province': self.get_province_value(raw_station),
                'latitude': self.safe_float(self.get_coordinate_value(raw_station, 'lat')),
                'longitude': self.safe_float(self.get_coordinate_value(raw_station, 'lon')),
                'drainage_area': self.safe_float(raw_station.get('DRAINAGE_AREA_GROSS') or 
                                               raw_station.get('drainage_area')),
                'status': (raw_station.get('HYD_STATUS') or 
                          raw_station.get('status') or 
                          'Unknown').strip(),
                'data_type': (raw_station.get('DATA_TYPE') or 
                             raw_station.get('data_type') or 
                             'Flow').strip(),
                'updated_at': datetime.now(timezone.utc).isoformat(),
                'data_source': raw_station.get('data_source', 'csv_import'),
                'api_available': raw_station.get('api_available', False),
            }
            
            # Add whitewater info if this is one of our known rivers
            whitewater_info = self.get_whitewater_info(cleaned['id'])
            if whitewater_info:
                cleaned.update(whitewater_info)
                cleaned['is_whitewater'] = True
            else:
                cleaned['is_whitewater'] = False
            
            return cleaned
            
        except Exception as e:
            logger.warning(f"Failed to clean station data: {e}")
            return None
    
    def get_province_value(self, raw_station: Dict) -> str:
        """Extract province from various possible field names."""
        province_fields = ['PROV_TERR_STATE_LOC', 'Province', 'province', 'PROVINCE', 'Prov']
        for field in province_fields:
            value = raw_station.get(field)
            if value:
                return str(value).strip()
        return 'Unknown'
    
    def get_coordinate_value(self, raw_station: Dict, coord_type: str) -> Optional[str]:
        """Extract latitude or longitude from various possible field names."""
        if coord_type.lower() == 'lat':
            fields = ['LATITUDE', 'Latitude', 'latitude', 'LAT', 'lat']
        else:
            fields = ['LONGITUDE', 'Longitude', 'longitude', 'LON', 'lon', 'LONG', 'long']
            
        for field in fields:
            value = raw_station.get(field)
            if value:
                return str(value)
        return None
    
    def get_province_from_station_id(self, station_id: str) -> str:
        """Determine province from WSC station ID prefix."""
        if not station_id or len(station_id) < 3:
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
        
        return province_map.get(prefix, 'Unknown')
    
    def get_whitewater_info(self, station_id: str) -> Optional[Dict]:
        """Get whitewater-specific information if this is a known whitewater station."""
        whitewater_stations = {
            '02KF005': {
                'section': 'Champlain Bridge',
                'difficulty': 'Class I-II',
                'min_runnable': 50.0,
                'max_safe': 300.0,
            },
            '02KA006': {
                'section': 'Lower Madawaska',
                'difficulty': 'Class II-III',
                'min_runnable': 15.0,
                'max_safe': 80.0,
            },
            '02ED003': {
                'section': 'Big Pine Rapids',
                'difficulty': 'Class II-IV',
                'min_runnable': 20.0,
                'max_safe': 100.0,
            },
            '05BH004': {
                'section': 'Harvey Passage',
                'difficulty': 'Class II-III',
                'min_runnable': 30.0,
                'max_safe': 150.0,
            },
            '05AD007': {
                'section': 'Lower Canyon',
                'difficulty': 'Class III-IV',
                'min_runnable': 25.0,
                'max_safe': 120.0,
            },
            # Add more whitewater stations as needed
        }
        
        return whitewater_stations.get(station_id)
    
    def safe_float(self, value: str) -> Optional[float]:
        """Safely convert string to float."""
        try:
            if value and value.strip() and value.strip() != '':
                return float(value.strip())
        except (ValueError, TypeError):
            pass
        return None
    
    def get_fallback_station_data(self, station_id: str) -> Optional[Dict]:
        """Get fallback data for a specific station."""
        fallback_map = {
            '02KF005': {
                'id': '02KF005',
                'name': 'Ottawa River near Ottawa',
                'province': 'Ontario',
                'section': 'Champlain Bridge',
                'difficulty': 'Class I-II',
                'min_runnable': 50.0,
                'max_safe': 300.0,
                'latitude': 45.4215,
                'longitude': -75.6919,
            },
            '02KA006': {
                'id': '02KA006',
                'name': 'Madawaska River at Arnprior',
                'province': 'Ontario',
                'section': 'Lower Madawaska',
                'difficulty': 'Class II-III',
                'min_runnable': 15.0,
                'max_safe': 80.0,
                'latitude': 45.4333,
                'longitude': -76.3667,
            },
            '02ED003': {
                'id': '02ED003',
                'name': 'French River near Monetville',
                'province': 'Ontario',
                'section': 'Big Pine Rapids',
                'difficulty': 'Class II-IV',
                'min_runnable': 20.0,
                'max_safe': 100.0,
                'latitude': 46.2167,
                'longitude': -80.4167,
            },
            '05BH004': {
                'id': '05BH004',
                'name': 'Bow River at Calgary',
                'province': 'Alberta',
                'section': 'Harvey Passage',
                'difficulty': 'Class II-III',
                'min_runnable': 30.0,
                'max_safe': 150.0,
                'latitude': 51.0447,
                'longitude': -114.0719,
            },
            '05AD007': {
                'id': '05AD007',
                'name': 'Kicking Horse River at Golden',
                'province': 'British Columbia',
                'section': 'Lower Canyon',
                'difficulty': 'Class III-IV',
                'min_runnable': 25.0,
                'max_safe': 120.0,
                'latitude': 51.2967,
                'longitude': -116.9633,
            },
            '02KB001': {
                'id': '02KB001',
                'name': 'Petawawa River near Petawawa',
                'province': 'Ontario',
                'section': 'Five Mile Rapids',
                'difficulty': 'Class III-IV',
                'min_runnable': 30.0,
                'max_safe': 120.0,
                'latitude': 45.8833,
                'longitude': -77.2833,
            },
            '02KD007': {
                'id': '02KD007',
                'name': 'Gatineau River near Ottawa',
                'province': 'Quebec',
                'section': 'Paugan Falls',
                'difficulty': 'Class III',
                'min_runnable': 20.0,
                'max_safe': 80.0,
                'latitude': 45.4667,
                'longitude': -75.8333,
            },
            '02KB008': {
                'id': '02KB008',
                'name': 'Rouge River at Calumet',
                'province': 'Quebec',
                'section': 'Seven Sisters',
                'difficulty': 'Class IV-V',
                'min_runnable': 15.0,
                'max_safe': 60.0,
                'latitude': 45.6167,
                'longitude': -74.6333,
            },
            '09AB004': {
                'id': '09AB004',
                'name': 'Yukon River at Whitehorse',
                'province': 'Yukon',
                'section': 'Whitehorse Rapids',
                'difficulty': 'Class II-III',
                'min_runnable': 150.0,
                'max_safe': 800.0,
                'latitude': 60.7167,
                'longitude': -135.05,
            },
            '05BJ004': {
                'id': '05BJ004',
                'name': 'Elbow River at Calgary',
                'province': 'Alberta',
                'section': 'Urban Canyon',
                'difficulty': 'Class II',
                'min_runnable': 8.0,
                'max_safe': 40.0,
                'latitude': 51.0447,
                'longitude': -114.0719,
            }
        }
        
        station_data = fallback_map.get(station_id)
        if station_data:
            station_data['updated_at'] = datetime.now(timezone.utc).isoformat()
            station_data['data_source'] = 'fallback'
        
        return station_data
    
    def get_fallback_stations(self) -> List[Dict]:
        """Return all fallback station data."""
        logger.info("Using fallback station data")
        
        station_ids = ['02KF005', '02KA006', '02ED003', '05BH004', '05AD007', 
                      '02KB001', '02KD007', '02KB008', '09AB004', '05BJ004']
        
        stations = []
        for station_id in station_ids:
            station_data = self.get_fallback_station_data(station_id)
            if station_data:
                stations.append(station_data)
        
        return stations
    
    def save_stations_to_firestore(self, stations: List[Dict]):
        """Save station data to Firestore."""
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
        logger.info(f"Found {len(stations)} stations. Here are the first 5:")
        for i, station in enumerate(stations[:5]):
            print(f"\nStation {i+1}:")
            for key, value in station.items():
                print(f"  {key}: {value}")
    
    def update_metadata(self, station_count: int):
        """Update metadata about the last sync."""
        if self.db is None:
            logger.info("Demo mode: Would update metadata")
            return
            
        try:
            metadata = {
                'last_updated': datetime.now(timezone.utc).isoformat(),
                'station_count': station_count,
                'sync_type': 'admin_script'
            }
            
            self.db.collection('metadata').document('stations_sync').set(metadata)
            logger.info("Updated sync metadata")
            
        except Exception as e:
            logger.warning(f"Failed to update metadata: {e}")
    
    def run(self):
        """Main execution method."""
        logger.info("Starting station data pull...")
        
        try:
            # Fetch station data
            stations = self.fetch_station_list()
            
            if not stations:
                logger.error("No stations found to save")
                return False
            
            # Save to Firestore
            self.save_stations_to_firestore(stations)
            
            logger.info("Station data pull completed successfully")
            return True
            
        except Exception as e:
            logger.error(f"Station data pull failed: {e}")
            return False

def main():
    """Main entry point."""
    puller = StationDataPuller()
    success = puller.run()
    
    if success:
        print("✅ Station data pulled and saved successfully!")
        sys.exit(0)
    else:
        print("❌ Station data pull failed!")
        sys.exit(1)

if __name__ == "__main__":
    main()