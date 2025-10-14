#!/usr/bin/env python3
"""
Official Station Name Updater - Uses the authoritative Environment Canada station list
to update ALL station names with their official names from the government source.
"""

import requests
import firebase_admin
from firebase_admin import credentials, firestore
import logging
from datetime import datetime

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def update_stations_with_official_names():
    """Update all stations with official names from Environment Canada."""
    
    # Initialize Firebase
    logger.info("Initializing Firebase...")
    try:
        cred = credentials.Certificate('service_account_key.json')
        try:
            app = firebase_admin.get_app()
        except ValueError:
            app = firebase_admin.initialize_app(cred)
        db = firestore.client()
        logger.info("✅ Firebase initialized successfully")
    except Exception as e:
        logger.error(f"❌ Failed to initialize Firebase: {e}")
        return
    
    # Fetch official station list
    logger.info("📡 Fetching official station list from Environment Canada...")
    try:
        response = requests.get('https://dd.weather.gc.ca/hydrometric/doc/hydrometric_StationList.csv')
        if response.status_code != 200:
            logger.error(f"❌ Failed to fetch station list: HTTP {response.status_code}")
            return
            
        lines = response.text.strip().split('\n')
        logger.info(f"📋 Successfully fetched {len(lines)-1} stations from official source")
        
        if len(lines) < 2:
            logger.error("❌ No station data found in CSV")
            return
            
    except Exception as e:
        logger.error(f"❌ Error fetching station list: {e}")
        return
    
    # Parse CSV data
    logger.info("📊 Parsing station data...")
    official_stations = {}
    header = lines[0]
    logger.info(f"📋 CSV Header: {header}")
    
    for line_num, line in enumerate(lines[1:], 2):
        try:
            # Simple CSV parsing (handling quoted names with commas)
            parts = []
            in_quotes = False
            current_part = ""
            
            for char in line:
                if char == '"':
                    in_quotes = not in_quotes
                elif char == ',' and not in_quotes:
                    parts.append(current_part.strip())
                    current_part = ""
                else:
                    current_part += char
            parts.append(current_part.strip())  # Add last part
            
            if len(parts) >= 5:
                station_id = parts[0].strip()
                station_name = parts[1].strip().strip('"')  # Remove quotes
                latitude = parts[2].strip()
                longitude = parts[3].strip()
                province = parts[4].strip()
                
                if station_id and station_name:
                    official_stations[station_id] = {
                        'name': station_name,
                        'latitude': float(latitude) if latitude else None,
                        'longitude': float(longitude) if longitude else None,
                        'province': province,
                        'source': 'Environment Canada Official'
                    }
                    
        except Exception as e:
            logger.debug(f"Error parsing line {line_num}: {e}")
            continue
    
    logger.info(f"✅ Parsed {len(official_stations)} official station records")
    
    # Update Firebase stations
    logger.info("🔄 Updating stations in Firebase...")
    
    # Get all existing stations
    stations_ref = db.collection('water_stations')
    existing_stations = list(stations_ref.stream())
    
    logger.info(f"📊 Found {len(existing_stations)} existing stations in database")
    
    # Update stations with official names
    updated_count = 0
    no_match_count = 0
    batch_size = 100
    batch = db.batch()
    batch_count = 0
    
    for doc in existing_stations:
        try:
            doc_data = doc.to_dict()
            station_id = doc_data.get('id', doc.id)
            
            if station_id in official_stations:
                official_data = official_stations[station_id]
                current_name = doc_data.get('name', '')
                new_name = official_data['name']
                
                # Update if name is different
                if current_name != new_name:
                    # Prepare update data
                    update_data = {
                        'name': new_name,
                        'official_name': new_name,
                        'name_source': 'Environment Canada Official',
                        'updated_at': datetime.now().isoformat()
                    }
                    
                    # Add coordinates if available and missing
                    if official_data['latitude'] and not doc_data.get('latitude'):
                        update_data['latitude'] = official_data['latitude']
                    if official_data['longitude'] and not doc_data.get('longitude'):
                        update_data['longitude'] = official_data['longitude']
                    
                    # Add province if missing
                    if official_data['province'] and not doc_data.get('province'):
                        update_data['province'] = official_data['province']
                    
                    batch.update(doc.reference, update_data)
                    batch_count += 1
                    updated_count += 1
                    
                    logger.info(f"📝 {station_id}: {current_name[:50]}... → {new_name[:50]}...")
                    
                    # Commit batch when full
                    if batch_count >= batch_size:
                        batch.commit()
                        logger.info(f"💾 Committed batch of {batch_count} updates")
                        batch = db.batch()
                        batch_count = 0
            else:
                no_match_count += 1
                if no_match_count <= 10:  # Only log first 10 for brevity
                    logger.debug(f"🤷 No official data found for station {station_id}")
                    
        except Exception as e:
            logger.error(f"❌ Error updating station {station_id}: {e}")
            continue
    
    # Commit final batch
    if batch_count > 0:
        batch.commit()
        logger.info(f"💾 Committed final batch of {batch_count} updates")
    
    # Summary
    logger.info("="*60)
    logger.info("🎉 Official Station Name Update Complete!")
    logger.info("="*60)
    logger.info(f"📊 Total stations in database: {len(existing_stations)}")
    logger.info(f"📚 Official stations available: {len(official_stations)}")
    logger.info(f"✅ Stations updated: {updated_count}")
    logger.info(f"🤷 Stations without official match: {no_match_count}")
    logger.info(f"📈 Success rate: {(len(existing_stations) - no_match_count) / len(existing_stations) * 100:.1f}%")
    
    # Show some sample updated names
    logger.info("\n📋 Sample of updated official names:")
    sample_count = 0
    for doc in existing_stations:
        if sample_count >= 10:
            break
        doc_data = doc.to_dict()
        station_id = doc_data.get('id', doc.id)
        if station_id in official_stations:
            name = official_stations[station_id]['name']
            logger.info(f"   {station_id}: {name}")
            sample_count += 1

if __name__ == "__main__":
    logger.info("🚀 Starting Official Station Name Update...")
    update_stations_with_official_names()
    logger.info("✅ Update process complete!")