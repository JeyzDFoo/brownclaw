#!/usr/bin/env python3
"""
Setup script for configuring Firebase credentials and environment.
Run this once to set up your admin scripts.
"""

import os
import sys
import json
from pathlib import Path

def main():
    print("🔥 BrownClaw Admin Scripts Setup")
    print("=" * 40)
    
    # Get the admin_scripts directory
    script_dir = Path(__file__).parent
    env_file = script_dir / '.env'
    
    print(f"Setting up environment in: {script_dir}")
    
    # Check if .env already exists
    if env_file.exists():
        print("\n⚠️  .env file already exists!")
        response = input("Do you want to overwrite it? (y/N): ")
        if response.lower() != 'y':
            print("Setup cancelled.")
            return
    
    print("\n📋 Firebase Configuration")
    print("To get your Firebase service account key:")
    print("1. Go to Firebase Console > Project Settings > Service Accounts")
    print("2. Click 'Generate new private key'")
    print("3. Save the JSON file securely on your system")
    print()
    
    # Get Firebase credentials path
    while True:
        cred_path = input("Enter the path to your Firebase service account JSON file: ").strip()
        if not cred_path:
            print("❌ Please provide a valid path")
            continue
            
        # Expand user path
        cred_path = os.path.expanduser(cred_path)
        
        if os.path.exists(cred_path):
            # Try to validate it's a valid Firebase service account file
            try:
                with open(cred_path, 'r') as f:
                    data = json.load(f)
                    if 'project_id' in data and 'private_key' in data:
                        project_id = data['project_id']
                        print(f"✅ Valid Firebase service account file found for project: {project_id}")
                        break
                    else:
                        print("❌ This doesn't appear to be a valid Firebase service account file")
                        continue
            except (json.JSONDecodeError, IOError) as e:
                print(f"❌ Error reading file: {e}")
                continue
        else:
            print("❌ File not found. Please check the path and try again.")
            continue
    
    # Get project ID (with default from the service account file)
    default_project_id = data.get('project_id', 'brownclaw')
    project_id_input = input(f"Enter Firebase project ID [{default_project_id}]: ").strip()
    project_id = project_id_input if project_id_input else default_project_id
    
    # Create .env file
    env_content = f"""# Firebase Admin SDK Configuration
FIREBASE_CREDENTIALS_PATH={cred_path}
FIREBASE_PROJECT_ID={project_id}

# Optional: Set log level (DEBUG, INFO, WARNING, ERROR)
LOG_LEVEL=INFO
"""
    
    try:
        with open(env_file, 'w') as f:
            f.write(env_content)
        
        print("\n✅ Configuration saved!")
        print(f"📄 Environment file created: {env_file}")
        print("\n🚀 You can now run the admin scripts:")
        print("   python3 pull_stations.py")
        
    except IOError as e:
        print(f"\n❌ Error creating .env file: {e}")
        return 1
    
    return 0

if __name__ == "__main__":
    sys.exit(main())