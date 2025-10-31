# BrownClaw Version Control & PWA Update Strategy

## 🔥 Firestore-Based Version Checking (NEW)
BrownClaw now uses **Firestore** for version checking instead of static JSON files, completely solving PWA caching issues!

### How It Works:
- **Version Storage**: `app_config/version` document in Firestore
- **Update Check**: App queries Firestore directly (bypasses all caching)
- **PWA Compatible**: Works perfectly with installed PWAs
- **Real-time**: Admins can update version info instantly

### Version Document Structure:
```json
{
  "version": "1.1.2",
  "buildNumber": 5,
  "buildDate": "2025-10-30", 
  "updateMessage": "New version available!",
  "changelog": ["🔇 Production print suppression", "⚡ Performance improvements"],
  "isUpdateRequired": false
}
```

## Codebase Versioning
- Use Git for all source control and release management.
- Tag each production release (e.g., v1.0.0) for traceability. 
- Update `pubspec.yaml` version for every release.
- **NEW**: Deploy script auto-updates Firestore version document

## User-Facing Versioning
- Display the app version in the UI (e.g., About or Settings screen).
- Maintain a changelog for transparency and debugging.
- **NEW**: Update banners work in PWAs and regular web browsers

## Service Worker & Cache Management
- Ensure the service worker updates and clears old caches on new deployments.
- Use versioned asset URLs or cache-busting strategies to avoid stale content.

## Update Detection
- Implement logic to detect when a new version is available (e.g., via service worker events).
- Prompt users to refresh or reload when an update is detected.

## Rollback Plan
- Tag releases and keep previous builds for quick rollback if needed.

---

*Note: Proper version control and update management are critical for a smooth PWA user experience and reliable production deployments.*

*Added by GitHub Copilot (GPT-4.1), October 16, 2025.*
