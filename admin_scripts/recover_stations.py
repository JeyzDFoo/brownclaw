#!/usr/bin/env python3
"""
Station Recovery Script - Recreate the water_stations collection using official Environment Canada data
"""

import requests
import firebase_admin
from firebase_admin import credentials, firestore
import logging
from datetime import datetime

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def recover_stations_collection():
    """Recreate the water_stations collection with official Environment Canada data."""
    
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
    
    # Parse CSV and create station documents
    logger.info("📊 Creating station documents...")
    header = lines[0]
    logger.info(f"📋 CSV Header: {header}")
    
    # Create the water_stations collection
    stations_ref = db.collection('water_stations')
    
    created_count = 0
    error_count = 0
    batch_size = 100
    batch = db.batch()
    batch_count = 0
    
    for line_num, line in enumerate(lines[1:], 2):
        try:
            # Parse CSV line (handling quoted names with commas)
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
                latitude_str = parts[2].strip()
                longitude_str = parts[3].strip()
                province = parts[4].strip()
                timezone = parts[5].strip() if len(parts) > 5 else 'UTC'
                
                # Convert coordinates
                latitude = None
                longitude = None
                try:
                    if latitude_str:
                        latitude = float(latitude_str)
                    if longitude_str:
                        longitude = float(longitude_str)
                except ValueError:
                    pass
                
                if station_id and station_name:
                    # Create complete station document
                    station_doc = {
                        'id': station_id,
                        'name': station_name,
                        'official_name': station_name,
                        'province': province,
                        'latitude': latitude,
                        'longitude': longitude,
                        'timezone': timezone,
                        'data_source': 'Environment Canada Official',
                        'name_source': 'Environment Canada Official',
                        'api_available': True,
                        'is_whitewater': False,  # Will be updated later for whitewater rivers
                        'created_at': datetime.now().isoformat(),
                        'updated_at': datetime.now().isoformat(),
                        'status': 'Active'
                    }
                    
                    # Add to batch
                    doc_ref = stations_ref.document(station_id)
                    batch.set(doc_ref, station_doc)
                    batch_count += 1
                    created_count += 1
                    
                    if created_count <= 10:  # Log first 10 for verification
                        logger.info(f"📝 Creating: {station_id} - {station_name[:50]}...")
                    elif created_count % 100 == 0:
                        logger.info(f"📊 Created {created_count} stations so far...")
                    
                    # Commit batch when full
                    if batch_count >= batch_size:
                        batch.commit()
                        logger.info(f"💾 Committed batch of {batch_count} stations")
                        batch = db.batch()
                        batch_count = 0
                        
        except Exception as e:
            logger.error(f"❌ Error processing line {line_num}: {e}")
            error_count += 1
            continue
    
    # Commit final batch
    if batch_count > 0:
        batch.commit()
        logger.info(f"💾 Committed final batch of {batch_count} stations")
    
    # Create metadata document
    try:
        metadata_ref = db.collection('metadata').document('stations_recovery')
        metadata_doc = {
            'recovery_date': datetime.now().isoformat(),
            'stations_created': created_count,
            'errors': error_count,
            'source': 'Environment Canada Official Station List',
            'csv_url': 'https://dd.weather.gc.ca/hydrometric/doc/hydrometric_StationList.csv',
            'total_official_stations': len(lines) - 1
        }
        db.collection('metadata').document('stations_recovery').set(metadata_doc)
        logger.info("📋 Created recovery metadata document")
    except Exception as e:
        logger.error(f"❌ Failed to create metadata: {e}")
    
    # Summary
    logger.info("="*60)
    logger.info("🎉 Station Collection Recovery Complete!")
    logger.info("="*60)
    logger.info(f"✅ Stations created: {created_count}")
    logger.info(f"❌ Errors: {error_count}")
    logger.info(f"📈 Success rate: {(created_count / (created_count + error_count) * 100):.1f}%")
    
    # Verify the collection was created
    logger.info("\n🔍 Verifying collection...")
    try:
        station_count = len(list(stations_ref.limit(1).stream()))
        if station_count > 0:
            logger.info("✅ Collection 'water_stations' created successfully!")
            
            # Show some sample stations
            sample_stations = list(stations_ref.limit(5).stream())
            logger.info("📋 Sample recovered stations:")
            for doc in sample_stations:
                data = doc.to_dict()
                logger.info(f"   {doc.id}: {data.get('name', 'No name')}")
        else:
            logger.error("❌ Collection appears to be empty!")
    except Exception as e:
        logger.error(f"❌ Error verifying collection: {e}")

if __name__ == "__main__":
    logger.info("🚑 Starting Station Collection Recovery...")
    recover_stations_collection()
    logger.info("✅ Recovery process complete!")