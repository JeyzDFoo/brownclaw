#!/usr/bin/env python3
"""
Enhanced station name discovery script.
This script fetches proper station names from the Canadian Water Office API
and updates existing Firestore records with meaningful names.
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

class StationNameEnhancer:
    def __init__(self):
        """Initialize the station name enhancer."""
        self.db = None
        self.init_firebase()
        self.session = requests.Session()
        
    def init_firebase(self):
        """Initialize Firebase Admin SDK."""
        try:
            cred_path = os.getenv('FIREBASE_CREDENTIALS_PATH')
            project_id = os.getenv('FIREBASE_PROJECT_ID', 'brownclaw')
            
            if cred_path and os.path.exists(cred_path):
                cred = credentials.Certificate(cred_path)
                if not firebase_admin._apps:
                    firebase_admin.initialize_app(cred, {
                        'projectId': project_id
                    })
                self.db = firestore.client()
                logger.info("✅ Firebase initialized successfully")
            else:
                logger.error("❌ Firebase credentials not found")
                sys.exit(1)
                
        except Exception as e:
            logger.error(f"❌ Firebase initialization error: {e}")
            sys.exit(1)
    
    def get_station_info_from_api(self, station_id: str) -> Optional[Dict]:
        """Get detailed station information from Canadian Water Office real-time API."""
        try:
            # Try the real-time data API which includes station metadata
            # Parameters: 46 = Water Level, 47 = Flow
            for param in ['46', '47']:  # Try both water level and flow
                realtime_url = f"https://wateroffice.ec.gc.ca/services/real_time_data/csv/inline?stations[]={station_id}&parameters[]={param}"
                
                logger.debug(f"Trying API: {realtime_url}")
                response = self.session.get(realtime_url, timeout=15)
                
                if response.status_code == 200 and response.text.strip():
                    csv_content = response.text.strip()
                    
                    # Parse the CSV content - the header often contains station info
                    lines = csv_content.split('\n')
                    
                    if len(lines) >= 2:
                        # The first line contains headers with station information
                        header_line = lines[0]
                        
                        # Try to find station name patterns in the header
                        station_info = self.parse_station_from_csv_header(header_line, station_id)
                        if station_info:
                            return station_info
                        
                        # Also check if there are data rows with station info
                        if len(lines) > 1:
                            # Parse the actual CSV data to get station information
                            headers = [h.strip().strip('"') for h in header_line.split(',')]
                            
                            # Look for station name in headers or data
                            for i, header in enumerate(headers):
                                if 'STATION' in header.upper() and 'NAME' in header.upper():
                                    # Found station name column
                                    for data_line in lines[1:3]:  # Check first couple data rows
                                        if data_line.strip():
                                            data_parts = [d.strip().strip('"') for d in data_line.split(',')]
                                            if i < len(data_parts) and data_parts[i]:
                                                station_name = data_parts[i]
                                                if station_name != station_id and len(station_name) > 5:
                                                    return {'name': station_name}
                        
                        # Try alternative approach - look for station info in the raw response
                        return self.extract_station_from_response(csv_content, station_id)
            
            return None
            
        except Exception as e:
            logger.debug(f"Error getting station info for {station_id}: {e}")
            return None
    
    def parse_station_from_csv_header(self, header_line: str, station_id: str) -> Optional[Dict]:
        """Parse station information from CSV header line."""
        try:
            # Sometimes station names are embedded in the header comments
            if '#' in header_line:
                comment_parts = header_line.split('#')
                for part in comment_parts:
                    if station_id in part:
                        # Extract text around the station ID that might be the name
                        words = part.replace(station_id, '').strip().split()
                        potential_name = ' '.join(words).strip()
                        if len(potential_name) > 5 and any(w in potential_name.upper() for w in ['RIVER', 'CREEK', 'LAKE', 'AT', 'NEAR']):
                            return {'name': potential_name}
            
            # Try parsing as CSV to find station name column
            headers = [h.strip().strip('"') for h in header_line.split(',')]
            for header in headers:
                if 'STATION' in header.upper() and ('NAME' in header.upper() or 'DESCRIPTION' in header.upper()):
                    return {'has_name_column': True}
            
            return None
        except Exception as e:
            logger.debug(f"Error parsing header for {station_id}: {e}")
            return None
    
    def extract_station_from_response(self, csv_content: str, station_id: str) -> Optional[Dict]:
        """Extract station information from the full CSV response."""
        try:
            lines = csv_content.split('\n')
            
            # Look through all lines for patterns that might contain station names
            for line in lines[:10]:  # Check first 10 lines
                if station_id in line:
                    # Clean up the line and look for meaningful text
                    cleaned_line = line.replace('"', '').replace(',', ' ')
                    words = cleaned_line.split()
                    
                    # Find the station ID and extract surrounding context
                    try:
                        station_index = words.index(station_id)
                        
                        # Look for descriptive text before or after the station ID
                        context_words = []
                        
                        # Check words before the station ID
                        start_idx = max(0, station_index - 5)
                        context_words.extend(words[start_idx:station_index])
                        
                        # Check words after the station ID
                        end_idx = min(len(words), station_index + 6)
                        context_words.extend(words[station_index + 1:end_idx])
                        
                        # Filter for meaningful words that could be part of a station name
                        meaningful_words = []
                        for word in context_words:
                            if (len(word) > 2 and 
                                word.upper() not in ['CSV', 'DATA', 'LEVEL', 'FLOW', 'DISCHARGE', 'UTC', 'EST'] and
                                not word.isdigit() and
                                word not in station_id):
                                meaningful_words.append(word)
                        
                        if meaningful_words:
                            potential_name = ' '.join(meaningful_words).strip()
                            if len(potential_name) > 8:  # Reasonable minimum length for station name
                                return {'name': potential_name}
                    
                    except ValueError:
                        continue
            
            return None
            
        except Exception as e:
            logger.debug(f"Error extracting from response for {station_id}: {e}")
            return None
    
    def safe_float(self, value: str) -> Optional[float]:
        """Safely convert string to float."""
        try:
            if value and str(value).strip():
                return float(str(value).strip())
        except (ValueError, TypeError):
            pass
        return None
    
    def enhance_station_names(self):
        """Enhance all station names in Firestore."""
        try:
            # Get all stations from Firestore
            stations_ref = self.db.collection('water_stations')
            docs = stations_ref.stream()
            
            updated_count = 0
            total_count = 0
            
            for doc in docs:
                total_count += 1
                station_data = doc.to_dict()
                station_id = station_data.get('id')
                current_name = station_data.get('name', '')
                
                # Skip if already has a good name (not just "Station XXXXX")
                if current_name and not current_name.startswith('Station '):
                    continue
                
                logger.info(f"📡 Enhancing station {station_id} (currently: {current_name})")
                
                # Get enhanced info from API
                enhanced_info = self.get_station_info_from_api(station_id)
                
                if enhanced_info and enhanced_info.get('name'):
                    updates = {}
                    
                    # Update name
                    new_name = enhanced_info['name']
                    if new_name != current_name:
                        updates['name'] = new_name
                        logger.info(f"  ✅ Updated name: {current_name} → {new_name}")
                    
                    # Update other fields if available
                    for field in ['province', 'latitude', 'longitude', 'drainage_area', 'status']:
                        if enhanced_info.get(field) is not None:
                            if field not in station_data or station_data[field] != enhanced_info[field]:
                                updates[field] = enhanced_info[field]
                    
                    # Update timestamp
                    updates['updated_at'] = datetime.now(timezone.utc).isoformat()
                    
                    if updates:
                        # Update in Firestore
                        stations_ref.document(doc.id).update(updates)
                        updated_count += 1
                        logger.info(f"  💾 Updated {len(updates)} fields")
                    
                else:
                    logger.info(f"  ❌ No enhanced info found for {station_id}")
                
                # Rate limiting
                time.sleep(0.1)
                
                # Progress update
                if total_count % 100 == 0:
                    logger.info(f"📊 Processed {total_count} stations, updated {updated_count}")
            
            logger.info(f"✅ Enhancement complete! Processed {total_count} stations, updated {updated_count}")
            
        except Exception as e:
            logger.error(f"❌ Error enhancing station names: {e}")
            raise
    
    def test_specific_station(self, station_id: str):
        """Test enhancement on a specific station to debug the process."""
        try:
            logger.info(f"🔍 Testing specific station: {station_id}")
            
            # Try both parameter types
            for param in ['46', '47']:  # Water Level, Flow
                url = f"https://wateroffice.ec.gc.ca/services/real_time_data/csv/inline?stations[]={station_id}&parameters[]={param}"
                logger.info(f"📡 Testing URL: {url}")
                
                response = self.session.get(url, timeout=15)
                logger.info(f"📊 Response status: {response.status_code}")
                
                if response.status_code == 200 and response.text.strip():
                    content = response.text.strip()
                    logger.info(f"📄 Response length: {len(content)} characters")
                    
                    # Show first few lines of response
                    lines = content.split('\n')
                    logger.info(f"📝 First 3 lines of response:")
                    for i, line in enumerate(lines[:3]):
                        logger.info(f"    Line {i+1}: {line[:100]}...")
                    
                    # Try to extract station info
                    enhanced_info = self.get_station_info_from_api(station_id)
                    if enhanced_info:
                        logger.info(f"✅ Extracted info: {enhanced_info}")
                        return enhanced_info
                    else:
                        logger.info(f"❌ No info extracted from parameter {param}")
                else:
                    logger.info(f"❌ No valid response for parameter {param}")
            
            return None
                
        except Exception as e:
            logger.error(f"❌ Error testing station {station_id}: {e}")
            return None

    def sample_enhancement(self, limit: int = 10):
        """Test enhancement on a small sample of stations."""
        try:
            stations_ref = self.db.collection('water_stations')
            docs = stations_ref.limit(limit).stream()
            
            for doc in docs:
                station_data = doc.to_dict()
                station_id = station_data.get('id')
                current_name = station_data.get('name', '')
                
                logger.info(f"🔍 Testing station {station_id}: {current_name}")
                
                enhanced_info = self.get_station_info_from_api(station_id)
                if enhanced_info:
                    logger.info(f"  📝 Enhanced info: {enhanced_info}")
                else:
                    logger.info(f"  ❌ No enhanced info available")
                
                time.sleep(0.5)  # Slower for testing
                
        except Exception as e:
            logger.error(f"❌ Error in sample enhancement: {e}")

def main():
    """Main execution function."""
    enhancer = StationNameEnhancer()
    
    if len(sys.argv) > 1:
        if sys.argv[1] == '--sample':
            logger.info("🧪 Running sample enhancement...")
            enhancer.sample_enhancement()
        elif sys.argv[1] == '--test' and len(sys.argv) > 2:
            station_id = sys.argv[2].upper()
            logger.info(f"🔬 Testing specific station: {station_id}")
            enhancer.test_specific_station(station_id)
        else:
            logger.info("Usage: python3 enhance_station_names.py [--sample | --test STATION_ID]")
    else:
        logger.info("🚀 Starting full station name enhancement...")
        enhancer.enhance_station_names()

if __name__ == "__main__":
    main()