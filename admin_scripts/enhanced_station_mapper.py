#!/usr/bin/env python3
"""
Enhanced station name mapper with comprehensive Canadian river patterns.
This script updates station names with proper river names based on Canadian Water Service patterns.
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

class EnhancedStationNameMapper:
    def __init__(self):
        """Initialize the enhanced station name mapper."""
        self.db = None
        self.init_firebase()
        
        # Comprehensive Canadian river pattern mapping
        self.river_patterns = {
            # Atlantic Canada (01)
            '01': {
                'AD': 'Kicking Horse River',  # Some eastern rivers
                'AF': 'Annapolis River',
                'AG': 'Avon River',
                'AH': 'Shubenacadie River',
                'AJ': 'LaHave River',
                'AK': 'Mersey River',
                'AL': 'Medway River',
                'AM': 'Tusket River',
                'AN': 'Yarmouth River',
                'AP': 'Bear River',
                'AQ': 'Sissiboo River',
                'AR': 'Meteghan River',
                'BA': 'Saint John River',
                'BB': 'Kennebecasis River',
                'BC': 'Nashwaak River',
                'BD': 'Nerepis River',
                'BE': 'Washademoak River',
                'BF': 'Canaan River',
                'BG': 'Salmon River',
                'BH': 'Hammond River',
                'BJ': 'Millstream River',
                'BK': 'Pollett River',
                'BL': 'Shepody River',
                'BM': 'Petitcodiac River',
                'BN': 'Memramcook River',
                'BP': 'Tantramar River',
                'CA': 'Miramichi River',
                'CB': 'Southwest Miramichi River',
                'CC': 'Northwest Miramichi River',
                'CD': 'Little Southwest Miramichi River',
                'CE': 'Renous River',
                'CF': 'Dungarvon River',
                'CG': 'Cains River',
                'CH': 'Bartibog River',
                'CJ': 'Tabusintac River',
                'CK': 'Big Tracadie River',
                'DA': 'Restigouche River',
                'DB': 'Upsalquitch River',
                'DC': 'Kedgwick River',
                'DD': 'Patapedia River',
                'DE': 'Matapedia River',
                'DF': 'Causapscal River',
                'DG': 'Cascapedia River',
                'DH': 'Bonaventure River',
                'DJ': 'Nouvelle River',
                'DK': 'Escuminac River',
                'EA': 'Nepisiguit River',
                'EB': 'Tetagouche River',
                'EC': 'Middle River',
                'ED': 'Jacquet River',
                'EE': 'Charlo River',
                'EF': 'Eel River',
                'FA': 'Exploits River',
                'FB': 'Gander River',
                'FC': 'Terra Nova River',
                'FD': 'Trinity River',
                'FE': 'Bonavista River',
                'FF': 'Southwest River',
                'FG': 'Northeast River',
                'FH': 'Humber River',
                'FJ': 'Corner Brook Stream',
                'FK': 'Serpentine River',
                'FL': 'St. George River',
            },
            
            # Quebec/Ontario (02)  
            '02': {
                'KF': 'Ottawa River',
                'KA': 'Madawaska River', 
                'KB': 'Petawawa River',
                'KC': 'Rouge River',
                'KD': 'Gatineau River',
                'KE': 'Lievre River',
                'KG': 'Nord River',
                'KH': 'Coulonge River',
                'KJ': 'Dumoine River',
                'KK': 'Mattawa River',
                'LA': 'St. Lawrence River',
                'LB': 'Richelieu River',
                'LC': 'Yamaska River',
                'LD': 'Saint-Francois River',
                'LE': 'Nicolet River',
                'LF': 'Becancour River',
                'LG': 'Chaudiere River',
                'LH': 'Etchemin River',
                'LJ': 'Montmorency River',
                'LK': 'Jacques-Cartier River',
                'MA': 'Saguenay River',
                'MB': 'Peribonka River',
                'MC': 'Mistassini River',
                'MD': 'Ashuapmushuan River',
                'ME': 'Chamouchouane River',
                'MF': 'Mistassibi River',
                'MG': 'aux Rats River',
                'MH': 'Shipshaw River',
                'NA': 'Saint-Maurice River',
                'NB': 'Batiscan River',
                'NC': 'Sainte-Anne River',
                'ND': 'Machiche River',
                'NE': 'du Loup River',
                'OA': 'Outaouais River',  # Alternative Ottawa River designation
                'OB': 'Rideau River',
                'OC': 'Tay River',
                'OD': 'Mississippi River',
                'OE': 'Carleton Place River',
                'PA': 'Thames River',
                'PB': 'Grand River',
                'PC': 'Speed River',
                'PD': 'Conestogo River',
                'PE': 'Nith River',
                'ED': 'French River',
                'GA': 'Trent River',
                'GB': 'Otonabee River',
                'GC': 'Kawartha Lakes',
                'GD': 'Scugog River',
                'GE': 'Nonquon River',
            },
            
            # Prairie Provinces (05)
            '05': {
                'BH': 'Bow River',
                'AD': 'Kicking Horse River',
                'BJ': 'Elbow River',
                'AA': 'South Saskatchewan River',
                'AB': 'North Saskatchewan River', 
                'AC': 'Battle River',
                'AE': 'Red Deer River',
                'AF': 'Blindman River',
                'AG': 'Medicine River',
                'AH': 'Clearwater River',
                'AJ': 'Pembina River',
                'AK': 'Smoky River',
                'AL': 'Peace River',
                'AM': 'Wapiti River',
                'AN': 'Grande Prairie River',
                'AP': 'Kakwa River',
                'AQ': 'Sulphur River',
                'AR': 'Simonette River',
                'BA': 'Oldman River',
                'BB': 'Belly River',
                'BC': 'Waterton River',
                'BD': 'St. Mary River',
                'BE': 'Milk River',
                'BF': 'Frenchman River',
                'BG': 'Chinook Creek',
                'BK': 'Fish Creek',
                'BL': 'Sheep River',
                'BM': 'Highwood River',
                'BN': 'Sheep Creek',
                'BP': 'Mosquito Creek',
                'CA': 'Athabasca River',
                'CB': 'Pembina River',
                'CC': 'McLeod River',
                'CD': 'Brazeau River',
                'CE': 'North Saskatchewan River',
                'CF': 'Sturgeon River',
                'CG': 'Vermilion River',
                'CH': 'Whitesand River',
                'CJ': 'Calling River',
                'CK': 'House River',
                'DA': 'Milk River',
                'DB': 'South Saskatchewan River',
                'DC': 'Swift Current Creek',
                'DD': 'Chinook Creek',
                'DE': 'Maple Creek',
                'DF': 'Battle Creek',
                'DG': 'Eagle Creek',
                'DH': 'Matador Creek',
                'EA': 'Saskatchewan River',
                'EB': 'Carrot River',
                'EC': 'Pasquia River',
                'ED': 'Torch River',
                'EE': 'Whiteswan River',
                'EF': 'Sipanok River',
                'FA': 'Assiniboine River',
                'FB': 'Souris River',
                'FC': 'Pipestone Creek',
                'FD': 'Oak River',
                'FE': 'Birdtail Creek',
                'FF': 'Little Saskatchewan River',
                'GA': 'Red River',
                'GB': 'Seine River',
                'GC': 'Rat River',
                'GD': 'Roseau River',
                'HA': 'Nelson River',
                'HB': 'Churchill River',
                'HC': 'Burntwood River',
                'HD': 'Grass River',
                'HE': 'Limestone River',
                'JA': 'Hayes River',
                'JB': 'Gods River',
                'JC': 'Shamattawa River',
                'JD': 'Winisk River',
                'JE': 'Attawapiskat River',
                'KA': 'Albany River',
                'KB': 'Kenogami River',
                'KC': 'Ogoki River',
                'LA': 'Moose River',
                'LB': 'Mattagami River',
                'LC': 'Kapuskasing River',
                'LD': 'Frederick House River',
                'MA': 'Abitibi River',
                'MB': 'Harricana River',
                'MC': 'Bell River',
                'MD': 'Nottaway River',
                'ME': 'Rupert River',
                'MF': 'Eastmain River',
                'MG': 'La Grande River',
            },
            
            # British Columbia (07/08)
            '07': {
                'AA': 'Fraser River',
                'AB': 'Thompson River', 
                'AC': 'Nicola River',
                'AD': 'Similkameen River',
                'AE': 'Tulameen River',
                'AF': 'Coquihalla River',
                'AG': 'Harrison River',
                'AH': 'Lillooet River',
                'BA': 'Chilcotin River',
                'BB': 'Homathko River',
                'BC': 'Klinaklini River',
                'BD': 'Southgate River',
                'BE': 'Bella Coola River',
                'BF': 'Atnarko River',
                'BG': 'Dean River',
                'BH': 'Blackwater River',
                'BJ': 'Nechako River',
                'BK': 'Stuart River',
                'CA': 'Columbia River',
                'CB': 'Kootenay River',
                'CC': 'Elk River',
                'CD': 'Bull River',
                'CE': 'St. Mary River',
                'CF': 'Moyie River',
                'CG': 'Goat River',
                'CH': 'Duncan River',
                'CJ': 'Lardeau River',
                'DA': 'Peace River',
                'DB': 'Pine River',
                'DC': 'Moberly River',
                'DD': 'Halfway River',
                'DE': 'Doig River',
                'DF': 'Beatton River',
                'DG': 'Blueberry River',
                'DH': 'Kiskatinaw River',
                'EA': 'Skeena River',
                'EB': 'Bulkley River',
                'EC': 'Morice River',
                'ED': 'Babine River',
                'EE': 'Kispiox River',
                'EF': 'Kitwanga River',
                'FA': 'Stikine River',
                'FB': 'Iskut River',
                'FC': 'Klappan River',
                'FD': 'Spatsizi River',
                'FE': 'Finlay River',
                'FF': 'Parsnip River',
                'GA': 'Liard River',
                'GB': 'Fort Nelson River',
                'GC': 'Muskwa River',
                'GD': 'Prophet River',
                'GE': 'Sikanni Chief River',
                'GF': 'Fontas River',
                'GG': 'Cameron River',
                'GH': 'Petitot River',
                'HA': 'Taku River',
                'HB': 'Alsek River',
                'HC': 'Tatshenshini River',
                'HD': 'Chilkat River',
            },
            
            '08': {
                'AA': 'Vancouver Island Rivers',
                'AB': 'Somass River',
                'AC': 'Sproat River',
                'CD': 'Campbell River',
                'CE': 'Salmon River',
                'CG': 'Oyster River',
                'DA': 'Cowichan River',
                'DB': 'Koksilah River',
                'EB': 'Nanaimo River',
                'EC': 'Englishman River',
                'ED': 'French Creek',
                'EE': 'Little Qualicum River',
                'EF': 'Big Qualicum River',
                'FA': 'Alberni Inlet Rivers',
                'FB': 'Ash River',
                'FC': 'Gold River',
                'FD': 'Heber River',
                'FE': 'Burman River',
                'FF': 'Muchalat River',
                'GA': 'Nimpkish River',
                'GB': 'Cluxewe River',
                'GC': 'Keogh River',
                'GD': 'Nahwitti River',
                'GE': 'Quatse River',
                'GF': 'Marble River',
                'GG': 'Woss River',
                'GH': 'Adam River',
                'HA': 'Fraser Valley Rivers',
                'HB': 'Chilliwack River',
                'HC': 'Vedder River',
                'HD': 'Sumas River',
                'HE': 'Nooksack River',
                'HF': 'Brunette River',
                'JA': 'Coast Mountains Rivers',
                'JB': 'Squamish River',
                'JC': 'Cheakamus River',
                'JD': 'Mamquam River',
                'JE': 'Elaho River',
                'KA': 'Sunshine Coast Rivers',
                'KB': 'Powell River',
                'KC': 'Theodosia River',
                'KD': 'Lois River',
                'KE': 'Haslam Creek',
                'KF': 'Lang Creek',
                'KG': 'Stillwater River',
                'KH': 'Toba River',
                'LA': 'Sea to Sky Rivers',
                'LB': 'Capilano River',
                'LC': 'Seymour River',
                'LD': 'Lynn Creek',
                'LE': 'Mosquito Creek',
                'LF': 'Cypress Creek',
                'LG': 'Eagle Creek',
                'MA': 'North Shore Rivers',
                'MB': 'Coquitlam River',
                'MC': 'Pitt River',
                'MD': 'Alouette River',
                'ME': 'South Alouette River',
                'MF': 'Kanaka Creek',
                'MG': 'Stave River',
                'MH': 'Ruskin Creek',
                'NA': 'Harrison Lake Area',
                'NB': 'Chehalis River',
                'NC': 'Harrison River',
                'ND': 'Lillooet River',
                'NE': 'Green River',
                'NF': 'Birken Creek',
                'NG': 'Ryan Creek',
                'NH': 'Seton Creek',
                'NJ': 'Bridge River',
                'NK': 'Yalakom River',
                'NL': 'Stein River',
                'NM': 'Nahatlatch River',
                'NN': 'Anderson River',
                'NP': 'Seton River',
                'OA': 'Thompson Tributaries',
                'OB': 'Deadman River',
                'PA': 'Okanagan System',
            },
            
            # Northern Canada (09)
            '09': {
                'AA': 'Yukon River',
                'AB': 'Yukon River', 
                'AC': 'Klondike River',
                'AD': 'Indian River',
                'AE': 'Bonanza Creek',
                'AF': 'Hunker Creek',
                'AG': 'Dominion Creek',
                'AH': 'Sulphur Creek',
                'BA': 'Peel River',
                'BB': 'Wind River',
                'BC': 'Bonnet Plume River',
                'BD': 'Snake River',
                'BE': 'Ogilvie River',
                'CA': 'Porcupine River',
                'CB': 'Old Crow River',
                'CC': 'Bluefish River',
                'CD': 'Fishing Branch River',
                'CE': 'Eagle River',
                'DA': 'Mackenzie River',
                'DB': 'Great Bear River',
                'DC': 'Coppermine River',
                'DD': 'Burnside River',
                'DE': 'Tree River',
                'EA': 'Back River',
                'EB': 'Thelon River',
                'EC': 'Kazan River',
                'ED': 'Dubawnt River',
                'EE': 'Ferguson River',
                'FA': 'Anderson River',
                'FB': 'Horton River',
                'FC': 'Hornaday River',
                'FD': 'Brock River',
            },
            
            # Arctic/Nunavut (10)
            '10': {
                'AA': 'Coppermine River',
                'AB': 'Burnside River',
                'AC': 'Tree River',
                'AD': 'Hood River',
                'AE': 'Ellice River',
                'AF': 'Back River',
                'AG': 'Hayes River',
                'AH': 'Meadowbank River',
                'BA': 'Thelon River',
                'BB': 'Hanbury River',
                'BC': 'Dubawnt River',
                'BD': 'Kazan River',
                'BE': 'Ferguson River',
                'BF': 'Maguse River',
                'BG': 'Lorillard River',
                'CA': 'Chesterfield Inlet',
                'CB': 'Inlet Rivers',
                'CC': 'Baker Lake Area',
                'CD': 'Quoich River',
                'CE': 'Chantrey Inlet',
                'DA': 'Great Fish River',
                'DB': 'Back River System',
                'DC': 'Murchison River',
                'DD': 'Burnside System',
                'DE': 'Coppermine System',
                'EA': 'Bathurst Inlet',
                'EB': 'Coronation Gulf',
                'EC': 'Kugluktuk Area',
                'ED': 'Tree River System',
                'EE': 'Hood River System',
                'FA': 'Victoria Island',
                'FB': 'Banks Island',
                'FC': 'Arctic Islands',
                'FD': 'Mackenzie Delta',
                'FE': 'Anderson River',
                'GA': 'Ellesmere Island',
                'GB': 'Devon Island',
                'GC': 'Baffin Island East',
                'GD': 'Baffin Island West',
                'GE': 'Somerset Island',
                'HA': 'Hudson Bay East',
                'HB': 'Hudson Bay West', 
                'HC': 'James Bay',
                'HD': 'Ungava Bay',
                'HE': 'Labrador Sea',
                'JA': 'Foxe Basin',
                'JB': 'Gulf of Boothia',
                'JC': 'Committee Bay',
                'JD': 'Admiralty Inlet',
                'JE': 'Lancaster Sound',
                'KA': 'Baffin Bay East',
                'KB': 'Baffin Bay West',
                'KC': 'Davis Strait',
                'KD': 'Hudson Strait',
                'KE': 'Ungava Peninsula',
                'LA': 'Melville Peninsula',
                'LB': 'Boothia Peninsula',
                'LC': 'King William Island',
                'LD': 'Prince of Wales Island',
                'LE': 'Somerset Island',
                'MA': 'Arctic Ocean Drainage',
                'MB': 'Beaufort Sea',
                'MC': 'Amundsen Gulf',
                'MD': 'M\'Clure Strait',
                'ME': 'Viscount Melville Sound',
                'NB': 'Queen Elizabeth Islands',
                'NC': 'Parry Islands',
                'ND': 'Sverdrup Islands',
                'NE': 'Ellesmere Island',
                'OB': 'Alert Area',
                'PA': 'Greenland Sea Area',
                'PB': 'Lincoln Sea Area',
                'PC': 'Arctic Ocean Proper',
                'QA': 'Labrador Current Area',
                'QC': 'Davis Strait Area',
                'RA': 'Hudson Bay Central',
                'RC': 'James Bay Central',
                'TA': 'Tundra Rivers',
                'TF': 'Taiga Shield Rivers',
                'UH': 'Ungava Highland Rivers',
            }
        }
        
        # Known specific stations that override patterns
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
        
    def init_firebase(self):
        """Initialize Firebase Admin SDK."""
        try:
            # Use service account key from current directory
            cred = credentials.Certificate('service_account_key.json')
            if not firebase_admin._apps:
                firebase_admin.initialize_app(cred)
            self.db = firestore.client()
            logger.info("✅ Firebase initialized successfully")
                
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
            if len(station_id) >= 4:
                region_code = station_id[:2]
                sub_pattern = station_id[2:4]
                
                # Look for river patterns
                if region_code in self.river_patterns:
                    region_patterns = self.river_patterns[region_code]
                    
                    # Check for exact match first
                    if sub_pattern in region_patterns:
                        river_name = region_patterns[sub_pattern]
                        return f"{river_name} at {station_id}"
                    
                    # Check for partial matches (first 2 characters)
                    for pattern, river_name in region_patterns.items():
                        if pattern and sub_pattern.startswith(pattern[:2]):
                            return f"{river_name} near Station {station_id}"
                
                # If no specific pattern matches, create regional name
                location_name = self.get_location_name(region_code)
                return f"Monitoring Station {station_id} - {location_name}"
            
            return f"Water Station {station_id}"
            
        except Exception as e:
            logger.debug(f"Error generating name for {station_id}: {e}")
            return None
    
    def get_location_name(self, region_code: str) -> str:
        """Get a location name based on region code."""
        location_map = {
            '01': 'Atlantic Canada',
            '02': 'Quebec/Ontario',
            '03': 'Ontario',
            '04': 'Ontario',
            '05': 'Prairie Provinces',
            '06': 'Prairie Provinces',
            '07': 'British Columbia',
            '08': 'British Columbia', 
            '09': 'Northern Canada',
            '10': 'Arctic Canada',
            '11': 'National Waters'
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
                
                # Only update if current name is generic "Monitoring Station" pattern
                if not current_name or 'Monitoring Station' in current_name:
                    # Generate new name
                    new_name = self.generate_station_name(station_id)
                    
                    if new_name and new_name != current_name:
                        # Add to batch update
                        doc_ref = stations_ref.document(doc.id)
                        batch.update(doc_ref, {
                            'name': new_name,
                            'updated_at': datetime.now(timezone.utc).isoformat(),
                            'name_source': 'enhanced_pattern_mapping'
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

def main():
    """Main function to run the enhanced station name mapper."""
    logger.info("🚀 Starting enhanced station name mapping...")
    
    mapper = EnhancedStationNameMapper()
    mapper.update_station_names()
    
    logger.info("🎉 Enhanced station name mapping completed!")

if __name__ == "__main__":
    main()