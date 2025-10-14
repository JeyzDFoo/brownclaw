# BrownClaw Admin Scripts

This directory contains Python admin scripts for managing data in the BrownClaw app.

## Setup

1. Install Python dependencies:
```bash
cd admin_scripts
pip3 install -r requirements.txt
```

2. Configure Firebase (optional for testing):
```bash
python3 setup.py
```

**Note:** The scripts can run in demo mode without Firebase credentials. They will fetch and display data without saving to the database.

**For production use:**
   - Download your Firebase service account key from Firebase Console → Project Settings → Service Accounts
   - Run `python3 setup.py` to configure credentials
   - Or manually create `.env` file based on `.env.example`

## Scripts

### pull_stations.py

Fetches curated whitewater station data with fallback discovery.

**Usage:**
```bash
python3 pull_stations.py
```

**What it does:**
- Fetches whitewater-focused station data
- Attempts to discover additional active stations  
- Saves stations to Firestore collection `water_stations`
- Updates sync metadata
- Good for quick setup with essential stations

### discover_all_stations.py

Comprehensive discovery of ALL Canadian water monitoring stations.

**Usage:**
```bash
python3 discover_all_stations.py
```

**What it does:**
- Attempts to fetch complete station inventory from official sources
- Systematically discovers active stations using API testing
- Can find hundreds/thousands of stations across Canada
- Perfect for building a searchable database
- Takes 10-20 minutes to complete comprehensive discovery

**Recommended for:** Text search functionality, comprehensive coverage

**Environment variables needed:**
- `FIREBASE_CREDENTIALS_PATH`: Path to your Firebase service account JSON file
- `FIREBASE_PROJECT_ID`: Your Firebase project ID (defaults to 'brownclaw')

## Firebase Structure

The script creates the following Firestore structure:

```
water_stations/
  {station_id}/
    id: string
    name: string
    province: string
    latitude: number (optional)
    longitude: number (optional)
    drainage_area: number (optional)
    status: string
    data_type: string
    updated_at: string (ISO datetime)

metadata/
  stations_sync/
    last_updated: string (ISO datetime)
    station_count: number
    sync_type: string
```