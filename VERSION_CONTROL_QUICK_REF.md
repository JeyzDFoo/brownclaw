# Version Control - Quick Reference

## 🚀 Deploy New Version

```bash
./deploy.sh          # Patch: 1.0.0 → 1.0.1
./deploy.sh minor    # Minor: 1.0.0 → 1.1.0  
./deploy.sh major    # Major: 1.0.0 → 2.0.0
```

## 📝 Manual Deployment

1. Bump `lib/version.dart` buildNumber
2. Bump `web/version.json` buildNumber  
3. Run: `flutter build web --release`
4. Run: `firebase deploy --only hosting`

## 🔍 Check Current Version

**In code:**
```dart
import 'package:brownclaw/version.dart';
print(AppVersion.fullVersion);  // "v1.0.0 (Build 1)"
```

**On web:**
Visit: `https://your-app.web.app/version.json`

## 🧪 Test Update Banner

1. Set local buildNumber to 1
2. Run app
3. Change web/version.json buildNumber to 2
4. Force check: `context.read<VersionProvider>().forceCheck()`
5. Banner appears!

## 📊 Version Format

- **Semantic**: `MAJOR.MINOR.PATCH` (1.0.0)
- **Build Number**: Integer incremented each deploy
- **Build Date**: ISO format (2025-10-17)

## ⚙️ Configuration

**Check frequency:** `lib/services/version_checker_service.dart`
```dart
static const Duration _checkInterval = Duration(hours: 1);
```

**Update message:** `web/version.json`
```json
{
  "updateMessage": "Your custom message here"
}
```

## 🐛 Troubleshooting

**Banner not showing?**
- Check buildNumber: server > local
- Wait 1 hour or force check
- Verify version.json is deployed

**Version check failing?**
- Check browser console for errors
- Verify version.json is accessible
- Check network tab in DevTools

## 📞 Debug Output

Look for in console:
```
VersionChecker: Checking for updates...
VersionChecker: Current build: 1
VersionChecker: Update available! Current: 1, Latest: 2
```

## ✅ Checklist Before Deploy

- [ ] Updated version.dart buildNumber
- [ ] Updated version.json buildNumber
- [ ] Dates match
- [ ] Tests pass
- [ ] Build successful
- [ ] Deploy successful
- [ ] version.json accessible online

---

**Current Version**: 1.0.0 (Build 1)  
**Last Updated**: October 17, 2025
