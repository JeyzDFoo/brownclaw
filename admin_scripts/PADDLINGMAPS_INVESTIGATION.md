# PaddlingMaps.com API Investigation

## Summary
Created `probe_riverapp_api.py` (renamed from RiverApp to PaddlingMaps probe) to investigate the PaddlingMaps.com API.

## Finding: Cloudflare Protected
**Status**: ❌ Automated probing blocked  
**Protection**: Cloudflare bot detection ("Just a moment..." challenge)

All endpoints return HTTP 403 with Cloudflare challenge page.

## Manual Investigation Required

### Steps to Find the API:
1. Open https://paddlingmaps.com/region/Alberta in Chrome
2. Open DevTools (F12) → Network tab
3. Reload page and click on rivers
4. Look for:
   - `.json` files
   - XHR/Fetch requests
   - API endpoints
   - External APIs (wateroffice.ec.gc.ca, usgs.gov)

### What to Extract:
- River names and locations
- Gauge station IDs
- Flow level recommendations
- Difficulty ratings
- Regional data structure

## Alternative Approaches

### Option 1: Browser Automation
Use Selenium or Playwright to bypass Cloudflare protection:
```python
from selenium import webdriver
driver = webdriver.Chrome()
driver.get('https://paddlingmaps.com/region/Alberta')
# Extract data after page loads
```

### Option 2: Contact PaddlingMaps
**Best approach** - Email them:
- Explain BrownClaw project
- Ask for API access or data partnership
- Offer to credit them as data source
- Propose mutual benefit (more paddlers using both platforms)

### Option 3: Use Government APIs Directly
BrownClaw already uses:
- Government of Canada: `api.weather.gc.ca/collections/hydrometric-realtime`
- TransAlta: `transalta.com/river-flows/?get-riverflow-data=1`

PaddlingMaps likely aggregates the same data sources.

## Data We Need from PaddlingMaps

### Alberta Rivers (Priority):
- Kananaskis River (sections: Barrier to Seebe, Lower K, etc.)
- Bow River (sections: Calgary, Canmore)
- Red Deer River
- Elbow River
- Sheep River

### Data Points:
- Gauge station associations
- Flow recommendations (min/optimal/max)
- Difficulty ratings
- Put-in/take-out locations
- Season information

## Current BrownClaw Coverage
We already have comprehensive Alberta coverage via:
- Government of Canada API (all hydrometric stations)
- TransAlta API (Kananaskis specific)
- Firestore (user-contributed river data)

**Conclusion**: PaddlingMaps data is complementary, not essential. Focus on improving existing Government API integration and user-contributed data.

## Script Usage
```bash
python3 admin_scripts/probe_riverapp_api.py
```

Generates: `paddlingmaps_probe_report_YYYYMMDD_HHMMSS.json`
