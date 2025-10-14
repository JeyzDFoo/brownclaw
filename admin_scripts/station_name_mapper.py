#!/usr/bin/env python3
"""
Station name mapper using known station data and manual mappings.
This script updates station names using a combination of manual mappings and pattern matching.
"""

import os
import sys
import logging
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

class StationNameMapper:
    def __init__(self):
        """Initialize the station name mapper."""
        self.db = None
        self.init_firebase()
        
        # Known station mappings from Canadian Water Service
        self.known_stations = {
            '02KF005': 'Ottawa River at Britannia',
            '02KA006': 'Madawaska River at Arnprior', 
            '02ED003': 'French River near Monetville',
            '05BH004': 'Bow River at Calgary',
            '05AD007': 'Kicking Horse River at Golden',
            '05BJ004': 'Elbow River at Calgary',
            '02KB001': 'Petawawa River near Petawawa',
            '02KD007': 'Gatineau River near Ottawa',
            '02KB008': 'Rouge River at Calumet',
            '09AB004': 'Yukon River at Whitehorse',
        }
        
        # Pattern-based name generation
        self.province_patterns = {
            '01': 'Atlantic Canada',
            '02': 'Quebec/Ontario',
            '03': 'Ontario',
            '04': 'Ontario',
            '05': 'Prairie Provinces',
            '06': 'Prairie Provinces', 
            '07': 'British Columbia',
            '08': 'British Columbia',
            '09': 'Northern Canada',
            '10': 'Arctic/Nunavut'
        }
        
        # River name patterns based on station ID patterns (region-specific)
        self.river_patterns = {
            # Quebec/Ontario region (02)
            '02': {
                'KF': 'Ottawa River',
                'KA': 'Madawaska River', 
                'KB': 'Petawawa River',
                'KD': 'Gatineau River',
                'ED': 'French River',
            },
            # Prairie regions (05)
            '05': {
                'BH': 'Bow River',
                'AD': 'Kicking Horse River',
                'BJ': 'Elbow River',
            },
            # Northern Canada (09)
            '09': {
                'AB': 'Yukon River',
            }
        }
        
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
    
    def generate_station_name(self, station_id: str) -> Optional[str]:
        """Generate a meaningful station name based on station ID patterns."""
        try:
            # Check known stations first
            if station_id in self.known_stations:
                return self.known_stations[station_id]
            
            # Extract patterns from station ID
            if len(station_id) >= 6:
                region_code = station_id[:2]
                sub_pattern = station_id[2:4]
                
                # Get region name
                region_name = self.province_patterns.get(region_code, 'Canada')
                
                # Look for river patterns specific to this region
                if region_code in self.river_patterns:
                    region_patterns = self.river_patterns[region_code]
                    for pattern, river_name in region_patterns.items():
                        if pattern in sub_pattern:
                            # Create a descriptive name
                            station_num = station_id[4:] if len(station_id) > 4 else '001'
                            location_name = self.get_location_name(region_code)
                            return f"{river_name} near {location_name}"
                
                # If no specific pattern matches, create generic but meaningful name
                location_name = self.get_location_name(region_code)
                return f"Monitoring Station {station_id} - {location_name}"
            
            return None
            
        except Exception as e:
            logger.debug(f"Error generating name for {station_id}: {e}")
            return None
    
    def get_location_name(self, region_code: str) -> str:
        """Get a location name based on region code."""
        location_map = {
            '01': 'Atlantic Canada',
            '02': 'Quebec',
            '03': 'Ontario',
            '04': 'Ontario',
            '05': 'Alberta',
            '06': 'Saskatchewan',
            '07': 'British Columbia',
            '08': 'British Columbia', 
            '09': 'Yukon/NWT',
            '10': 'Nunavut'
        }
        return location_map.get(region_code, 'Canada')
    
    def update_station_names(self):
        """Update all station names in Firestore with better names."""
        try:
            stations_ref = self.db.collection('water_stations')
            docs = stations_ref.stream()
            
            updated_count = 0
            total_count = 0
            
            batch = self.db.batch()
            batch_count = 0
            
            for doc in docs:
                total_count += 1
                station_data = doc.to_dict()
                station_id = station_data.get('id')
                current_name = station_data.get('name', '')
                
                # Skip if already has a good name (not starting with "Station ")
                if current_name and not current_name.startswith('Station '):
                    continue
                
                # Generate new name
                new_name = self.generate_station_name(station_id)
                
                if new_name and new_name != current_name:
                    # Add to batch update
                    doc_ref = stations_ref.document(doc.id)
                    batch.update(doc_ref, {
                        'name': new_name,
                        'updated_at': datetime.now(timezone.utc).isoformat(),
                        'name_source': 'pattern_mapping'
                    })
                    
                    batch_count += 1
                    updated_count += 1
                    
                    logger.info(f"📝 {station_id}: {current_name} → {new_name}")
                    
                    # Commit batch every 100 updates
                    if batch_count >= 100:
                        batch.commit()
                        logger.info(f"💾 Committed batch of {batch_count} updates")
                        batch = self.db.batch()
                        batch_count = 0
                
                # Progress update
                if total_count % 500 == 0:
                    logger.info(f"📊 Processed {total_count} stations, updated {updated_count}")
            
            # Commit remaining batch
            if batch_count > 0:
                batch.commit()
                logger.info(f"💾 Committed final batch of {batch_count} updates")
            
            logger.info(f"✅ Update complete! Processed {total_count} stations, updated {updated_count}")
            
        except Exception as e:
            logger.error(f"❌ Error updating station names: {e}")
            raise
    
    def preview_updates(self, limit: int = 20):
        """Preview what names would be updated without making changes."""
        try:
            stations_ref = self.db.collection('water_stations')
            docs = stations_ref.limit(limit).stream()
            
            logger.info(f"🔍 Preview of name updates (first {limit} stations):")
            logger.info("=" * 80)
            
            update_count = 0
            
            for doc in docs:
                station_data = doc.to_dict()
                station_id = station_data.get('id')
                current_name = station_data.get('name', '')
                
                new_name = self.generate_station_name(station_id)
                
                if new_name and new_name != current_name:
                    update_count += 1
                    logger.info(f"📝 {station_id}")
                    logger.info(f"   Old: {current_name}")
                    logger.info(f"   New: {new_name}")
                    logger.info("")
                else:
                    logger.info(f"⏭️  {station_id}: {current_name} (no change)")
            
            logger.info(f"📊 Would update {update_count} out of {limit} stations previewed")
                
        except Exception as e:
            logger.error(f"❌ Error previewing updates: {e}")

def main():
    """Main execution function."""
    mapper = StationNameMapper()
    
    if len(sys.argv) > 1:
        if sys.argv[1] == '--preview':
            limit = int(sys.argv[2]) if len(sys.argv) > 2 else 20
            logger.info(f"🔍 Previewing station name updates (limit: {limit})...")
            mapper.preview_updates(limit)
        else:
            logger.info("Usage: python3 station_name_mapper.py [--preview [limit]]")
    else:
        logger.info("🚀 Starting station name updates...")
        mapper.update_station_names()

if __name__ == "__main__":
    main()