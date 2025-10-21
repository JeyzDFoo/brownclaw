#!/bin/bash

# Version Update Script for Brown Paw
# This script helps update version numbers across all relevant files

set -e

echo "🚀 Brown Paw Version Update Script"
echo "===================================="
echo ""

# Get current version
CURRENT_VERSION=$(grep -m 1 'version:' pubspec.yaml | sed 's/version: //')
CURRENT_BUILD=$(grep -m 1 'buildNumber' lib/version.dart | grep -o '[0-9]*')

echo "📋 Current version: $CURRENT_VERSION (Build $CURRENT_BUILD)"
echo ""

# Ask for new version
read -p "Enter new version (e.g., 1.2.0) or press Enter to keep $CURRENT_VERSION: " NEW_VERSION
if [ -z "$NEW_VERSION" ]; then
    NEW_VERSION=$(echo $CURRENT_VERSION | cut -d'+' -f1)
fi

# Calculate new build number
NEW_BUILD=$((CURRENT_BUILD + 1))

# Get today's date
TODAY=$(date +%Y-%m-%d)

echo ""
echo "📦 New version will be: $NEW_VERSION+$NEW_BUILD"
echo "📅 Build date: $TODAY"
echo ""
read -p "Continue with update? (y/n) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Update cancelled"
    exit 1
fi

echo ""
echo "📝 Updating version files..."

# Update pubspec.yaml
echo "  → pubspec.yaml"
sed -i.bak "s/^version: .*/version: $NEW_VERSION+$NEW_BUILD/" pubspec.yaml && rm pubspec.yaml.bak

# Update lib/version.dart
echo "  → lib/version.dart"
sed -i.bak "s/static const String version = .*/static const String version = '$NEW_VERSION';/" lib/version.dart && rm lib/version.dart.bak
sed -i.bak "s/static const int buildNumber = .*/static const int buildNumber = $NEW_BUILD;/" lib/version.dart && rm lib/version.dart.bak
sed -i.bak "s/static const String buildDate = .*/static const String buildDate = '$TODAY';/" lib/version.dart && rm lib/version.dart.bak

# Update web/version.json
echo "  → web/version.json"
cat > web/version.json << EOF
{
  "version": "$NEW_VERSION",
  "buildNumber": $NEW_BUILD,
  "buildDate": "$TODAY",
  "minRequiredBuild": 1,
  "updateMessage": "New version available! Please refresh to get the latest updates.",
  "changelog": [
    "Add your changelog items here"
  ]
}
EOF

echo ""
echo "✅ Version updated successfully!"
echo ""
echo "📋 Next steps:"
echo "  1. Edit web/version.json to add your changelog items"
echo "  2. Update CHANGELOG.md with detailed changes"
echo "  3. Test the app: flutter run -d chrome"
echo "  4. Build for production: flutter build web --release"
echo "  5. Deploy to your hosting service"
echo "  6. Commit changes: git add . && git commit -m \"Release v$NEW_VERSION (Build $NEW_BUILD)\""
echo ""
echo "🎉 Happy deploying!"
