# Add Kananaskis TransAlta Station to Firestore

This script adds a gauge station entry for the TransAlta Barrier Dam so that Kananaskis shows "Live data available" instead of "No real-time gauge station data available".

## Prerequisites

1. **Firebase Service Account Key**
   - Download from Firebase Console → Project Settings → Service Accounts
   - Click "Generate new private key"
   - Save as `serviceAccountKey.json` in the project root

2. **Python packages**
   ```bash
   pip install firebase-admin
   ```

## Run the Script

```bash
cd /Users/jeyzdfoo/Desktop/code/brownclaw
python3 add_kananaskis_station.py
```

## What the Script Does

1. Creates a new gauge station document: `TRANSALTA_BARRIER`
   - Station ID: `TRANSALTA_BARRIER`
   - Name: `TransAlta Barrier Dam`
   - Coordinates: 51.1, -115.0 (Kananaskis area)
   - Data source: `TransAlta` (marks it as special vs Gov of Canada stations)

2. Updates Kananaskis river runs to:
   - Set `stationId: 'TRANSALTA_BARRIER'`
   - Set `hasValidStation: true`

## Verify

After running the script:
1. Refresh the Kananaskis river detail page
2. Should now show: `Station ID: TRANSALTA_BARRIER`
3. No more "No real-time gauge station data available" message

## Manual Alternative

If you prefer to add manually in Firebase Console:

### 1. Add to `gauge_stations` collection:
```json
Document ID: TRANSALTA_BARRIER
{
  "stationId": "TRANSALTA_BARRIER",
  "name": "TransAlta Barrier Dam",
  "latitude": 51.1,
  "longitude": -115.0,
  "isActive": true,
  "parameters": ["Flow"],
  "dataSource": "TransAlta",
  "region": "Kananaskis"
}
```

### 2. Update `river_runs` for Kananaskis:
Find the Kananaskis document(s) and add/update:
```json
{
  "stationId": "TRANSALTA_BARRIER",
  "hasValidStation": true
}
```

## Security Note

⚠️ **DO NOT commit `serviceAccountKey.json` to git!**

It's already in `.gitignore`, but double-check before committing.
