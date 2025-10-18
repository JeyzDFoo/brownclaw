# Version Control System - Implementation Guide

## Overview

A simple but effective version control system has been implemented to help users know when your web app has been updated. Users will see a prominent banner when a new version is available, with a one-click refresh button.

## How It Works

### 1. Version Tracking
- **Local version**: Stored in `lib/version.dart` (compiled into app)
- **Server version**: Stored in `web/version.json` (deployed with app)
- **Check frequency**: Once per hour automatically
- **Display**: Banner appears when server version > local version

### 2. Version Check Flow

```
App Startup
    ↓
VersionProvider checks for update
    ↓
Fetches /version.json from server
    ↓
Compares buildNumber
    ↓
If server > local: Show UpdateBanner
    ↓
User clicks "Refresh Now"
    ↓
Page reloads with new version
```

## Files Created

### 1. `lib/version.dart` - Version Constants
```dart
class AppVersion {
  static const String version = '1.0.0';
  static const int buildNumber = 1;
  static const String buildDate = '2025-10-17';
}
```

**Update this file when:**
- Making significant changes
- Fixing bugs
- Adding features
- Before each deployment

### 2. `web/version.json` - Server Version Info
```json
{
  "version": "1.0.0",
  "buildNumber": 1,
  "buildDate": "2025-10-17",
  "minRequiredBuild": 1,
  "updateMessage": "A new version is available..."
}
```

**This file is deployed with your app** and read by clients to check for updates.

### 3. `lib/services/version_checker_service.dart` - Update Checker
- Fetches version.json from server
- Compares build numbers
- Rate limits checks to once per hour
- Handles network errors gracefully

### 4. `lib/providers/version_provider.dart` - State Management
- Manages update check state
- Shows/hides update banner
- Integrates with Provider architecture

### 5. `lib/widgets/update_banner.dart` - UI Component
- Orange banner at top of screen
- "Refresh Now" button
- Dismissible (but will reappear on next check)

## How to Use

### When You Deploy a New Version:

1. **Update `lib/version.dart`:**
   ```dart
   class AppVersion {
     static const String version = '1.0.1';  // ← Increment
     static const int buildNumber = 2;        // ← Increment
     static const String buildDate = '2025-10-18';  // ← Update
   }
   ```

2. **Update `web/version.json`:**
   ```json
   {
     "version": "1.0.1",
     "buildNumber": 2,
     "buildDate": "2025-10-18",
     "minRequiredBuild": 1,
     "updateMessage": "New features and bug fixes available!"
   }
   ```

3. **Build and deploy:**
   ```bash
   flutter build web --release
   firebase deploy --only hosting
   ```

### Version Numbering Guidelines

Use semantic versioning: `MAJOR.MINOR.PATCH`

- **MAJOR**: Breaking changes (1.0.0 → 2.0.0)
- **MINOR**: New features (1.0.0 → 1.1.0)
- **PATCH**: Bug fixes (1.0.0 → 1.0.1)

**Build number**: Increment by 1 with every deployment, no matter how small.

### Example Deployment Workflow

```bash
# 1. Update version files
# Edit lib/version.dart - bump buildNumber to 2
# Edit web/version.json - bump buildNumber to 2

# 2. Build
flutter build web --release

# 3. Deploy
firebase deploy --only hosting

# 4. Users with buildNumber 1 will see update banner
# 5. They click "Refresh Now" and get buildNumber 2
```

## Customization Options

### Change Check Frequency

In `lib/services/version_checker_service.dart`:
```dart
static const Duration _checkInterval = Duration(hours: 1); // Change this
```

### Customize Update Message

In `web/version.json`:
```json
{
  "updateMessage": "🎉 Exciting new features! Click to update."
}
```

### Force Immediate Check

```dart
// In any screen
context.read<VersionProvider>().forceCheck();
```

### Add Version Display to Settings

```dart
import 'package:brownclaw/version.dart';

// In your settings screen:
Text('Version: ${AppVersion.fullVersion}')
// Shows: "v1.0.0 (Build 1)"
```

## Testing

### Test the Update Banner Locally:

1. **Set local version to 1:**
   ```dart
   // lib/version.dart
   static const int buildNumber = 1;
   ```

2. **Start local server:**
   ```bash
   flutter run -d chrome
   ```

3. **Manually edit web/version.json while app is running:**
   ```json
   {
     "buildNumber": 2
   }
   ```

4. **Force a check:**
   - Wait 1 hour, OR
   - Call `forceCheck()` from code, OR
   - Restart the app

5. **You should see the orange banner!**

### Test After Deployment:

1. Deploy version with buildNumber 1
2. Users load the app (they have buildNumber 1)
3. Deploy version with buildNumber 2
4. After 1 hour, users' apps will check and show banner
5. Users click "Refresh Now" and get buildNumber 2

## Advanced: Automated Version Bumping

### Create a deployment script:

**`deploy.sh`:**
```bash
#!/bin/bash

# Get current build number from version.dart
CURRENT_BUILD=$(grep "buildNumber =" lib/version.dart | grep -o '[0-9]*')
NEW_BUILD=$((CURRENT_BUILD + 1))

# Get current date
DATE=$(date +%Y-%m-%d)

echo "🔢 Bumping build from $CURRENT_BUILD to $NEW_BUILD"

# Update version.dart
sed -i '' "s/buildNumber = $CURRENT_BUILD/buildNumber = $NEW_BUILD/" lib/version.dart
sed -i '' "s/buildDate = '.*'/buildDate = '$DATE'/" lib/version.dart

# Update version.json
sed -i '' "s/\"buildNumber\": $CURRENT_BUILD/\"buildNumber\": $NEW_BUILD/" web/version.json
sed -i '' "s/\"buildDate\": \".*\"/\"buildDate\": \"$DATE\"/" web/version.json

echo "✅ Version files updated"
echo "🏗️  Building..."

flutter build web --release

echo "🚀 Deploying..."

firebase deploy --only hosting

echo "✨ Done! Build $NEW_BUILD deployed"
```

**Make it executable:**
```bash
chmod +x deploy.sh
```

**Use it:**
```bash
./deploy.sh
```

## Benefits

✅ **Users always know when updates are available**
✅ **One-click refresh** - no need to explain cache clearing
✅ **Automatic checks** - happens in background
✅ **Rate limited** - won't spam your server
✅ **Web-only** - smart detection, won't run on mobile
✅ **Dismissible** - users can continue working if needed
✅ **Professional** - clean, prominent UI

## Monitoring

### Check version adoption:

Add to Firebase Analytics (optional):
```dart
// In version_checker_service.dart
import 'package:firebase_analytics/firebase_analytics.dart';

// After detecting update:
FirebaseAnalytics.instance.logEvent(
  name: 'version_check',
  parameters: {
    'current_build': AppVersion.buildNumber,
    'latest_build': _latestBuildNumber,
    'update_available': _updateAvailable,
  },
);
```

## Troubleshooting

### Users not seeing updates:

1. **Check version.json is deployed**: Visit `https://yourdomain.com/version.json`
2. **Check buildNumber is higher**: Server buildNumber > local buildNumber
3. **Wait for check interval**: Default is 1 hour
4. **Check browser console**: Look for "VersionChecker:" debug messages

### Banner not appearing:

1. Verify VersionProvider is added to MultiProvider
2. Check web/version.json exists and is accessible
3. Ensure buildNumber in version.json > buildNumber in version.dart
4. Check browser console for errors

### Version check failing:

- Check CORS headers on version.json
- Verify file is deployed to correct location
- Check network tab in browser DevTools

## Future Enhancements

Potential additions:
- [ ] Minimum required version (force refresh)
- [ ] Release notes display
- [ ] Silent background updates (service workers)
- [ ] Update schedule (off-hours only)
- [ ] A/B testing for gradual rollouts
- [ ] Offline version cache

---

**Implementation Date**: October 17, 2025  
**Status**: ✅ Ready for Use  
**Impact**: High (improves user experience and deployment confidence)
