#!/usr/bin/env python3
"""
Initialize Firestore version document for BrownClaw

This script creates the app_config/version document in Firestore
with the current version information from version.dart
"""

import re
import json
from datetime import datetime

def get_version_from_dart():
    """Extract version info from lib/version.dart"""
    with open('lib/version.dart', 'r') as f:
        content = f.read()
    
    # Extract version, build number, and date
    version_match = re.search(r"version = '([^']+)'", content)
    build_match = re.search(r'buildNumber = (\d+)', content)
    date_match = re.search(r"buildDate = '([^']+)'", content)
    
    if not all([version_match, build_match, date_match]):
        raise ValueError("Could not parse version info from lib/version.dart")
    
    return {
        'version': version_match.group(1),
        'buildNumber': int(build_match.group(1)),
        'buildDate': date_match.group(1)
    }

def create_firestore_version_doc():
    """Create the Firestore version document structure"""
    version_info = get_version_from_dart()
    
    # Create Firestore document structure
    firestore_doc = {
        'version': version_info['version'],
        'buildNumber': version_info['buildNumber'],
        'buildDate': version_info['buildDate'],
        'minRequiredBuild': 1,  # Minimum build number required to use app
        'updateMessage': 'New version available with production print suppression and improved performance! Please refresh to update.',
        'changelog': [
            '🔇 Production print suppression (clean logs)',
            '⚡ Improved performance and debugging',
            '🛠️ Enhanced version checking via Firestore',
            '📱 Better PWA compatibility',
            '✨ Previous: Launch screen and optimized assets'
        ],
        'isUpdateRequired': False,  # Set to true to force users to update
        'createdAt': datetime.now().isoformat(),
        'updatedAt': datetime.now().isoformat()
    }
    
    return firestore_doc

def main():
    print("🔥 BrownClaw Firestore Version Document Creator")
    print("=" * 50)
    
    try:
        doc = create_firestore_version_doc()
        
        print(f"📄 Generated Firestore document for version {doc['version']} (Build {doc['buildNumber']}):")
        print()
        print(json.dumps(doc, indent=2))
        print()
        print("🚀 To upload to Firestore:")
        print("1. Go to Firebase Console > Firestore Database")
        print("2. Create collection: 'app_config'")
        print("3. Create document: 'version'") 
        print("4. Copy the JSON above into the document")
        print()
        print("📱 Or use Firebase CLI:")
        print("   firebase firestore:set app_config/version version_doc.json")
        
        # Save to file for easy upload
        with open('firestore_version_doc.json', 'w') as f:
            json.dump(doc, f, indent=2)
        
        print(f"💾 Saved to: firestore_version_doc.json")
        
    except Exception as e:
        print(f"❌ Error: {e}")
        return 1
    
    return 0

if __name__ == '__main__':
    exit(main())