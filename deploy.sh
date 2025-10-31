#!/bin/bash

# BrownClaw Deployment Script with Automatic Version Bumping
# Usage: ./deploy.sh [version_type]
# version_type: major, minor, patch (default: patch)

set -e  # Exit on error

VERSION_TYPE=${1:-patch}

echo "🎯 BrownClaw Deployment Script"
echo "================================"

# Get current version from version.dart
CURRENT_VERSION=$(grep "version =" lib/version.dart | grep -o '[0-9]*\.[0-9]*\.[0-9]*')
CURRENT_BUILD=$(grep "buildNumber =" lib/version.dart | grep -o '[0-9]*')

echo "📊 Current version: $CURRENT_VERSION (Build $CURRENT_BUILD)"

# Parse version
IFS='.' read -r -a VERSION_PARTS <<< "$CURRENT_VERSION"
MAJOR="${VERSION_PARTS[0]}"
MINOR="${VERSION_PARTS[1]}"
PATCH="${VERSION_PARTS[2]}"

# Bump version based on type
case $VERSION_TYPE in
  major)
    MAJOR=$((MAJOR + 1))
    MINOR=0
    PATCH=0
    ;;
  minor)
    MINOR=$((MINOR + 1))
    PATCH=0
    ;;
  patch)
    PATCH=$((PATCH + 1))
    ;;
  *)
    echo "❌ Invalid version type. Use: major, minor, or patch"
    exit 1
    ;;
esac

NEW_VERSION="$MAJOR.$MINOR.$PATCH"
NEW_BUILD=$((CURRENT_BUILD + 1))
DATE=$(date +%Y-%m-%d)

echo "🔢 New version: $NEW_VERSION (Build $NEW_BUILD)"
echo ""

# Confirm with user
read -p "Continue with deployment? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Deployment cancelled"
    exit 1
fi

echo ""
echo "📝 Updating version files..."

# Update version.dart
sed -i '' "s/version = '[0-9]*\.[0-9]*\.[0-9]*'/version = '$NEW_VERSION'/" lib/version.dart
sed -i '' "s/buildNumber = $CURRENT_BUILD/buildNumber = $NEW_BUILD/" lib/version.dart
sed -i '' "s/buildDate = '[0-9-]*'/buildDate = '$DATE'/" lib/version.dart

# Update version.json (legacy - still used for web caching)
sed -i '' "s/\"version\": \"[0-9]*\.[0-9]*\.[0-9]*\"/\"version\": \"$NEW_VERSION\"/" web/version.json
sed -i '' "s/\"buildNumber\": $CURRENT_BUILD/\"buildNumber\": $NEW_BUILD/" web/version.json
sed -i '' "s/\"buildDate\": \"[0-9-]*\"/\"buildDate\": \"$DATE\"/" web/version.json

echo "✅ Version files updated"

echo "🔥 Updating Firestore version document..."
python3 setup_firestore_version.py > /dev/null 2>&1

# Try to update Firestore using Node.js script if available
if command -v node >/dev/null 2>&1; then
    if node upload_version_to_firestore.js 2>/dev/null; then
        echo "✅ Firestore version document updated automatically"
    else
        echo "⚠️  Could not auto-update Firestore - please update manually:"
        echo "   Collection: app_config"
        echo "   Document: version"
        echo "   Build Number: $NEW_BUILD"
        echo "   Version: $NEW_VERSION"
    fi
else
    echo "⚠️  Node.js not available - please update Firestore manually:"
    echo "   Collection: app_config"
    echo "   Document: version" 
    echo "   Build Number: $NEW_BUILD"
    echo "   Version: $NEW_VERSION"
fi
echo ""

echo "🧪 Running tests..."
if flutter test --reporter=compact; then
    echo "✅ Tests passed"
else
    echo "⚠️  Some tests failed, but continuing..."
fi
echo ""

echo "🏗️  Building web release..."
flutter build web --release

if [ $? -ne 0 ]; then
    echo "❌ Build failed!"
    exit 1
fi

echo "✅ Build complete"
echo ""

echo "🚀 Deploying to Firebase..."
firebase deploy --only hosting

if [ $? -ne 0 ]; then
    echo "❌ Deployment failed!"
    exit 1
fi

echo ""
echo "✨ Success!"
echo "================================"
echo "📦 Deployed version: $NEW_VERSION (Build $NEW_BUILD)"
echo "🌐 URL: https://your-app.web.app"
echo "📅 Date: $DATE"
echo ""
echo "💡 Users will see update banner within 1 hour"
echo ""
