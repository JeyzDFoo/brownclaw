# Brown Paw - AI Coding Agent Instructions

## Project Overview
BrownClaw is a **cross-platform** Flutter app (Web + Android) for whitewater kayakers to log river descents and track real-time water levels. Built with Firebase (Auth, Firestore, Storage, Analytics, Functions) and Stripe for premium subscriptions.

**Key Stack:** Flutter 3.9.2+, Provider pattern for state management, Firebase backend, Government of Canada hydrometric API for live water data.

## Supported Platforms
- **Web** (Primary platform - fully tested)
- **Android** (Newly added - configured and building)
- **iOS** (Not configured yet)

## First-Time Setup

### Prerequisites
- Flutter SDK 3.9.2+
- Firebase CLI: `npm install -g firebase-tools`
- Git

### Initial Setup
```bash
# 1. Clone and install dependencies
git clone <repo-url>
cd brownclaw
flutter pub get

# 2. Firebase login and project selection
firebase login
firebase use brownclaw

# 3. Set up Firebase emulators (for testing)
firebase init emulators
# Select: Firestore, Authentication
# Use default ports (Firestore: 8080, Auth: 9099)

# 4. Set up Python payment backend (optional for local testing)
cd functions
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env
# Edit .env with your Stripe keys from https://dashboard.stripe.com/apikeys
cd ..

# 5. Run the app
flutter run -d chrome
```

### Environment Variables
**Functions `.env`** (required for payment features):
```bash
STRIPE_SECRET_KEY=sk_test_...  # From Stripe Dashboard
STRIPE_WEBHOOK_SECRET=whsec_...  # From Stripe Webhooks
```

### Verify Setup
```bash
# Start emulators in one terminal
firebase emulators:start

# Run tests in another terminal
./run_tests.sh integration

# Run on web
flutter run -d chrome

# Run on Android (requires emulator or device)
flutter run -d <device-id>

# If tests pass, setup is complete! ✅
```

## Platform-Specific Considerations

### Web
- Uses `dart:html` for browser APIs (page reload, URL manipulation)
- Stripe uses hosted Checkout pages (redirect-based flow)
- No platform-specific permissions needed

### Android
- Package name: `com.brownpaw.brownclaw`
- Min SDK: 21 (Android 5.0 Lollipop)
- Firebase configured via FlutterFire CLI
- Stripe uses native payment sheet (flutter_stripe SDK)
- Deep linking configured for: `brownclaw://stripe-redirect`
- Icons generated via flutter_launcher_icons

### Platform-Aware Code Pattern
BrownClaw uses **conditional imports** to handle platform differences:

```dart
// In service files (e.g., stripe_service.dart)
import 'service_stub.dart'
    if (dart.library.html) 'service_web.dart'
    if (dart.library.io) 'service_mobile.dart';

// Use kIsWeb check for runtime platform detection
if (kIsWeb) {
  // Web-specific logic
} else {
  // Mobile-specific logic
}
```

**Important files for platform abstraction:**
- `lib/services/stripe_service_web.dart` - Web browser APIs (dart:html)
- `lib/services/stripe_service_mobile.dart` - Mobile APIs
- `lib/services/stripe_service_stub.dart` - Fallback for unsupported platforms

When adding browser-specific code, always use conditional imports to prevent Android build failures.

## Architecture Patterns

### State Management - Provider Pattern
All state flows through `ChangeNotifier` providers registered in `lib/main.dart`:
- **CacheProvider**: Foundation-level caching for all data (static: 1hr TTL, live: 5min TTL)
- **RiverRunProvider**: Manages river runs with static cache (`_cache`, `_cacheTime`) - 10min timeout
- **FavoritesProvider**: User's favorite rivers synced to Firestore `user_favorites/{userId}`
- **LiveWaterDataProvider**: Live water data with request deduplication pattern
- **PremiumProvider**: Stripe subscription state and paywall logic
- **LogbookProvider**: Personal river descent entries (private to user)

**Critical Pattern**: Providers use **static caches** to persist across instance recreation. Always check for static cache before re-initializing.

```dart
// Example from RiverRunProvider
static final Map<String, RiverRunWithStations> _cache = {};
static DateTime? _cacheTime;
static const _cacheTimeout = Duration(minutes: 10);
```

### Layered Architecture (Current State)
```
UI (Screens) → Providers (State/Business Logic) → Services (Data Access) → Firebase/API
```

**Known Issue**: Some screens bypass providers and call services directly (anti-pattern). See `ARCHITECTURAL_REFACTORING_PLAN.md` for migration to Repository pattern. When adding features, follow the correct flow: **Screen → Provider → Service**.

### Data Models
All models in `lib/models/` follow immutable pattern with `copyWith()`:
- **RiverRun**: Specific river section with difficulty, flow ranges, station association
- **RiverRunWithStations**: Composite model bundling run + associated water stations
- **LiveWaterData**: Typed model for water data (flow, level, temperature) - **not yet fully adopted**
- **River**: Basic river metadata
- **RiverDescent**: User logbook entry (PRIVATE, user-owned in Firestore)

**Important**: Many services still use `Map<String, dynamic>` for live data. Search for `#todo` comments to find typed model migration points.

## Firebase & Security

### Firestore Collections
- `rivers/`: Admin-only write (hardcoded UIDs in `firestore.rules`)
- `river_runs/`: Admin-only write
- `river_descents/`: **PRIVATE** user data - strict ownership rules
- `user_favorites/{userId}/`: User-specific, strict `isOwner()` check
- `gauge_stations/`, `water_stations/`: Read-only (backend writes)

**Admin UIDs** (in `firestore.rules`): `08y0oUgfD2aWOgScPJRDdyfehsv2`, `Ela2Ijh7kedHFLFMNGuKSaygWE02`

### Authentication
Google Sign-In only. Check `lib/services/google_sign_in_service.dart` for auth flow. User state managed in `UserProvider`.

## Critical Workflows

### Testing
**Focus on Integration Tests** - Test real provider/service/Firebase interactions, not isolated units.

**Integration Test Driven Development (ITDD):**
Write integration tests BEFORE implementing features. This workflow ensures:
- Features work end-to-end from the start (auth → provider → service → Firebase → UI)
- Cache behavior is validated across provider lifecycles
- Error states are handled properly (offline, auth failures, Firestore errors)
- No surprises when components interact in production

**ITDD Workflow:**
1. **Write failing integration test** for complete user flow (e.g., "add favorite → sync to Firestore → persist across sessions")
2. **Start Firebase emulators** (`firebase emulators:start`)
3. **Implement minimum code** to make test pass (model → service → provider → screen)
4. **Run test** - verify it passes with real Firebase interactions
5. **Refactor** with confidence - test catches regressions

```bash
# Run integration tests
./run_tests.sh integration  # Integration tests only
./run_tests.sh coverage     # With coverage report
flutter test test/integration/  # Direct integration test run
```

**Test Structure:**
- `test/integration/`: End-to-end provider + service + Firebase flows
- `test/models/`: Model serialization/deserialization
- `test/services/`: Service layer with Firebase interactions
- Skip unit tests - focus on real-world integration scenarios

**When Writing Tests:**
- Test complete workflows (auth → fetch → cache → UI state)
- Use Firebase emulators for realistic data (`firebase emulators:start`)
- Mock external APIs (Government of Canada, TransAlta) but not Firebase
- Verify cache behavior across provider instances (static cache persistence)

### Deployment
```bash
# Auto-bumps version in lib/version.dart and pubspec.yaml
./deploy.sh patch   # Default: patch version bump
./deploy.sh minor   # Minor version bump
./deploy.sh major   # Major version bump
```

### Live Data Integration
**TransAlta API**: Premium feature for Kananaskis region. See `lib/services/transalta_service.dart` and `TRANSALTA_SERVICE_README.md`. Requires CORS proxy setup.

**Government of Canada API**: JSON endpoint at `https://api.weather.gc.ca/collections/hydrometric-realtime/items`. Implements request deduplication in `LiveWaterDataService._activeRequests`.

## Project-Specific Conventions

### Performance Logging
Use `PerformanceLogger.log('event_name')` at critical points. Already instrumented in `main.dart` provider initialization. See `PERFORMANCE_LOGGING.md`.

### Caching Strategy
1. Check provider's static cache first
2. Check `CacheProvider` for shared data
3. Fall back to service layer
4. **Never** cache in UI screens directly

Example from `RiverRunProvider`:
```dart
if (_isCacheValid) {
  return _cache.values.toList();
}
```

### Error Handling
Services return typed models or null. Providers set `_error` string and notify listeners:
```dart
try {
  // Service call
} catch (e) {
  _error = 'User-friendly message: ${e.toString()}';
  notifyListeners();
}
```

### TODO Comments
Search for `// #todo:` to find technical debt and planned improvements. Key areas:
- Type-safe `LiveWaterData` model migration (19 occurrences)
- Lazy screen loading in `MainScreen`
- StationProvider for centralized station data
- Remove 600px width constraint for true mobile-first

## Stripe Integration
3-tier premium model: Monthly ($2.99), Yearly ($19.99), Lifetime ($34.99).
- Web: `lib/services/stripe_service.dart`
- Mobile: Separate implementation (see `STRIPE_INTEGRATION_GUIDE.md`)
- Premium state: `PremiumProvider.isPremium`, synced with Firestore `users/{uid}/premium_status`

## Payment Backend (Python)
**Transitioning from Firebase Functions to locally-served Python instance on dedicated hardware.**

Stripe integration and payment processing code located in `functions/main.py`:

**Available Endpoints:**
- `createCheckoutSession`: Web checkout flow for subscriptions
- `createSubscription`: Direct subscription creation
- `createPaymentIntent`: One-time payment for lifetime premium
- `getSubscriptionStatus`: Check user's subscription state
- `stripeWebhook`: Handle Stripe events (subscription updates, cancellations, payments)

**Local Development:**
```bash
cd functions
pip install -r requirements.txt
python main.py  # Local server setup (details TBD)
```

**Environment Variables** (`.env` in `functions/`):
- `STRIPE_SECRET_KEY`: Stripe API secret key
- `STRIPE_WEBHOOK_SECRET`: Webhook signing secret

**Webhook Events Handled:**
- `checkout.session.completed`: Web subscription creation
- `customer.subscription.updated`: Status changes (active, past_due, etc.)
- `customer.subscription.deleted`: Cancellations
- `payment_intent.succeeded`: Lifetime premium purchases

All endpoints sync premium status to Firestore `users/{userId}` collection with `isPremium`, `subscriptionId`, `subscriptionStatus` fields.

**Note**: Flutter app will need endpoint URLs updated to point to local instance instead of Firebase Functions.

## Common Development Scenarios

### Adding a New Provider
1. Create provider class extending `ChangeNotifier` in `lib/providers/`
2. Implement static cache if data is expensive to fetch:
   ```dart
   static final Map<String, YourData> _cache = {};
   static DateTime? _cacheTime;
   static const _cacheTimeout = Duration(minutes: 10);
   ```
3. Register in `lib/main.dart` MultiProvider (order matters - dependencies first)
4. Add to `lib/providers/providers.dart` export
5. Call services from provider, never from screens
6. Set `_isLoading`, `_error`, and call `notifyListeners()` appropriately

### Creating a New Screen
1. Create StatefulWidget in `lib/screens/`
2. Access providers via `context.read<YourProvider>()` or `context.watch<YourProvider>()`
3. Use `Consumer<YourProvider>` for reactive UI updates
4. **Never** call services directly - always go through providers
5. Handle loading and error states from provider:
   ```dart
   if (provider.isLoading) return CircularProgressIndicator();
   if (provider.error != null) return Text('Error: ${provider.error}');
   ```
6. Add to `MainScreen._screens` list if it's a tab screen

### Adding a New Model
1. Create immutable class in `lib/models/` with `const` constructor
2. Implement `fromMap()` factory for Firestore deserialization
3. Implement `toMap()` for Firestore serialization
4. Add `copyWith()` method for immutable updates
5. Add to `lib/models/models.dart` export
6. Use helper methods like `_safeToDouble()`, `_timestampToDateTime()` from existing models

### Modifying Firestore Security Rules
1. Edit `firestore.rules`
2. Test locally: `firebase emulators:start`
3. Verify with Firebase console emulator UI
4. Deploy: `firebase deploy --only firestore:rules`
5. **Always** use helper functions: `isAuthenticated()`, `isOwner(userId)`, `isAdmin()`

### Adding a Live Data Source
1. Create service in `lib/services/` (e.g., `new_api_service.dart`)
2. Implement request deduplication pattern (see `LiveWaterDataService._activeRequests`)
3. Add caching with TTL (5min for live data)
4. Return typed models (prefer `LiveWaterData` over `Map<String, dynamic>`)
5. Integrate into `LiveWaterDataProvider` or create dedicated provider
6. Update `RiverRunWithStations` to include new data source

### Writing Integration Tests (ITDD Approach)
1. **Write test FIRST** - Define expected behavior before implementation
2. Create test file in `test/integration/` (e.g., `favorites_flow_test.dart`)
3. Start Firebase emulators for realistic testing:
   ```bash
   firebase emulators:start
   ```
4. Write complete workflow test:
   ```dart
   test('user adds favorite → syncs to Firestore → persists across sessions', () async {
     // Setup: Auth + Provider
     final auth = MockAuth();
     final provider = FavoritesProvider();
     
     // Action: Add favorite via provider
     await provider.addFavorite('run-123');
     
     // Verify: Firestore write
     final doc = await firestore.collection('user_favorites').doc(userId).get();
     expect(doc.data()['rivers'], contains('run-123'));
     
     // Verify: Cache update
     expect(provider.favoriteRunIds, contains('run-123'));
     
     // Verify: New provider instance loads from cache
     final newProvider = FavoritesProvider();
     await newProvider.ensureInitialized();
     expect(newProvider.favoriteRunIds, contains('run-123'));
   });
   ```
5. **Run test** - it should fail (not implemented yet)
6. **Implement** model → service → provider to make test pass
7. **Verify** test passes with real Firebase interactions
8. Test edge cases: offline mode, permission errors, static cache persistence
9. Run: `./run_tests.sh integration`

**Benefits of ITDD:**
- Catches architectural issues early (e.g., forgetting static cache)
- Validates Firebase security rules during development
- Ensures features work end-to-end before UI implementation
- Provides living documentation of system behavior
- Makes refactoring safe - tests catch breaking changes

## UX Patterns & Conventions

### Loading States
Always show loading indicators for async operations:
```dart
if (provider.isLoading) {
  return const Center(child: CircularProgressIndicator());
}
```
- Use `CircularProgressIndicator()` for full-screen loads
- Use `CircularProgressIndicator(strokeWidth: 2)` for inline/button loads
- Always center loading indicators

### Error Handling
Display errors via SnackBars (transient) or error widgets (persistent):
```dart
// Transient errors (user actions)
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text('Error: ${provider.error}'),
    backgroundColor: Colors.red,
  ),
);

// Persistent errors (data loading failures)
if (provider.error != null) {
  return Center(child: Text('Error: ${provider.error}'));
}
```

### Reactive UI with Consumer
Use `Consumer` widgets to rebuild only affected UI sections:
```dart
// Single provider
Consumer<FavoritesProvider>(
  builder: (context, favorites, child) {
    return ListView.builder(...);
  },
)

// Multiple providers (Consumer2, Consumer3, Consumer4)
Consumer4<FavoritesProvider, RiverRunProvider, LiveWaterDataProvider, TransAltaProvider>(
  builder: (context, favorites, runs, liveData, transalta, child) {
    // Reactive to all 4 providers
  },
)
```

### Confirmation Dialogs
Use `showDialog` with `AlertDialog` for destructive actions:
```dart
final confirmed = await showDialog<bool>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Confirm Delete'),
    content: const Text('Are you sure?'),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, true),
        child: const Text('Delete'),
      ),
    ],
  ),
);
if (confirmed == true) {
  // Proceed with deletion
}
```

### Pull-to-Refresh
Use `RefreshIndicator` for manual data refresh:
```dart
RefreshIndicator(
  onRefresh: () async {
    await provider.refresh();
  },
  child: ListView(...),
)
```

### State Persistence
Use `AutomaticKeepAliveClientMixin` for tab screens to preserve state:
```dart
class _MyScreenState extends State<MyScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  
  @override
  Widget build(BuildContext context) {
    super.build(context); // Required!
    // ... rest of build
  }
}
```

### Theme Support
Access theme via `ThemeProvider` (Material 3 with brown/teal palette):
- Primary: Brown (`Colors.brown`)
- Secondary: Teal (`Color(0xFF009688)`)
- Both light and dark themes supported
- Toggle via `ThemeProvider.toggleTheme()`

## Common Pitfalls

1. **Don't bypass providers**: Screens calling services directly breaks state management
2. **Static cache awareness**: Provider recreation doesn't clear static caches - explicit `clearCache()` needed
3. **Platform-specific imports**: Always use conditional imports for `dart:html` or platform-specific code
4. **Firestore security**: Always test rule changes with `firebase emulators:start`
5. **Version bumping**: Use `./deploy.sh`, don't manually edit version files (dual source: `lib/version.dart` + `pubspec.yaml`)
6. **Android package name**: `com.brownpaw.brownclaw` (not `com.example.brownclaw`)

## Debugging Tips

### Firebase Issues

**Security Rule Violations:**
```bash
# Check Firebase console for detailed errors
# Emulator UI: http://localhost:4000
# Look for "permission-denied" errors in Firestore tab
```
- Verify `isAuthenticated()` and `isOwner(userId)` rules match user state
- Check admin UIDs in `firestore.rules` match your test user
- Test with emulators before deploying rules

**Auth State Issues:**
```dart
// FavoritesProvider pattern - check current user on init
final currentUser = FirebaseAuth.instance.currentUser;
if (currentUser != null) {
  // User already logged in
} else {
  // Wait for authStateChanges()
}
```
- `authStateChanges()` only fires on CHANGES, not current state
- Always check `currentUser` in provider constructors

### Performance Bottlenecks

**Use Performance Logger:**
```dart
import '../utils/performance_logger.dart';

PerformanceLogger.log('event_name');
PerformanceLogger.log('data_loaded', detail: '${items.length} items');
```
- Already instrumented in `main.dart` for provider initialization
- Check console for slow operations (>100ms gaps)
- See `PERFORMANCE_LOGGING.md` for detailed analysis

**Cache Misses:**
```dart
// Check if static cache is being used
if (RiverRunProvider._isCacheValid) {
  print('✅ Cache hit');
} else {
  print('❌ Cache miss - rebuilding');
}
```
- Provider recreation clears instance variables but NOT static caches
- Call `clearCache()` explicitly to force refresh

### Live Data Issues

**Government of Canada API Errors:**
- Check station ID format: uppercase alphanumeric (e.g., `05AD007`)
- Verify endpoint: `https://api.weather.gc.ca/collections/hydrometric-realtime/items`
- Request deduplication prevents duplicate calls - check `LiveWaterDataService._activeRequests`

**TransAlta CORS Errors:**
- Requires CORS proxy setup (see `TRANSALTA_SERVICE_README.md`)
- Premium feature - verify `PremiumProvider.isPremium` is true
- Check Kananaskis region stations only

### Test Failures

**Integration Tests:**
```bash
# Ensure emulators are running
firebase emulators:start

# Run specific test file
flutter test test/integration/favorites_flow_test.dart

# Check for Firebase connection errors
# Emulators must be running BEFORE tests
```

**Provider State Issues:**
```dart
// Ensure provider is initialized before testing
await provider.ensureInitialized();
expect(provider.isLoading, false);
```

### Build/Deploy Issues

**Version Mismatch:**
- `lib/version.dart` and `pubspec.yaml` must match
- Always use `./deploy.sh` to auto-sync versions
- Never manually edit version files

**Web Build Errors:**
```bash
# Clear build cache if seeing stale code
flutter clean
flutter pub get
flutter build web
```

## Key Files to Reference

- `ARCHITECTURAL_REFACTORING_PLAN.md`: Long-term architecture goals, known issues
- `lib/main.dart`: Provider registration order (dependency chain)
- `firestore.rules`: Security model and admin gates
- `test/README.md`: Test coverage status
- `STRIPE_INTEGRATION_GUIDE.md`: Payment setup and testing
- Service READMEs: `lib/services/TRANSALTA_SERVICE_README.md`

## Development Commands

```bash
flutter pub get                 # Install dependencies
flutter run -d chrome           # Run on web
flutter run -d <device-id>      # Run on Android device/emulator
flutter devices                 # List available devices
./deploy.sh patch              # Build and deploy with version bump
./run_tests.sh coverage        # Generate test coverage
firebase emulators:start       # Local Firestore testing

# Android-specific commands
flutter build apk --debug      # Build debug APK
flutter build apk --release    # Build release APK
flutter build appbundle        # Build Android App Bundle (AAB) for Play Store
```

When in doubt about patterns, search for `// #todo` comments - they highlight both technical debt and preferred implementation approaches.
