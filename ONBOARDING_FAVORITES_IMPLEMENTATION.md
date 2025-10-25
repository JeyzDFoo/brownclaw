# Default Favorites Onboarding Implementation

## Overview
New users automatically receive two default favorite rivers when they create an account:
- **Upper Kananaskis River** (`09oCVcqR8JjEAJS0PP7E`)
- **Harvie Passage** on Bow River (`N0ptPBwD1u2ByePoCOiY`)

## Implementation

### Cloud Function
**Function Name**: `initializeNewUserFavorites`
**Type**: Callable HTTPS function
**Location**: `functions/main.py` (lines 538-598)

**Features:**
- Requires authentication (user must be logged in)
- Checks if user already has favorites (prevents duplicate initialization)
- Creates `user_favorites/{userId}` document with default favorites
- Returns success status and favorite count

**Deployment:**
```bash
firebase deploy --only functions:initializeNewUserFavorites
```

### Integration with Flutter App

Add this code to your sign-up flow after successful Google Sign-In:

#### 1. Add the callable function to `lib/services/google_sign_in_service.dart`:

```dart
import 'package:cloud_functions/cloud_functions.dart';

class GoogleSignInService {
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;
  
  // Existing sign-in code...
  
  static Future<void> initializeNewUserFavorites() async {
    try {
      final result = await _functions
          .httpsCallable('initializeNewUserFavorites')
          .call();
      
      print('✅ Default favorites initialized: ${result.data}');
    } catch (e) {
      print('⚠️  Could not initialize favorites: $e');
      // Don't throw - this is not critical to sign-in flow
    }
  }
}
```

#### 2. Call it after successful sign-in:

```dart
// In your sign-in flow (e.g., UserProvider or GoogleSignInService)
Future<UserCredential> signInWithGoogle() async {
  final userCredential = await _auth.signInWithCredential(credential);
  
  // Check if this is a new user
  final isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;
  
  if (isNewUser) {
    // Initialize default favorites for new users
    await GoogleSignInService.initializeNewUserFavorites();
  }
  
  return userCredential;
}
```

### Response Format

**Success (New User):**
```json
{
  "success": true,
  "message": "Default favorites initialized",
  "favoriteCount": 2
}
```

**Success (Existing User):**
```json
{
  "success": true,
  "message": "User already has favorites",
  "alreadyInitialized": true
}
```

**Error:**
```json
{
  "code": "internal",
  "message": "Failed to initialize favorites: <error details>"
}
```

## Testing

### Manual Test
1. Create a new Google account
2. Sign up in the BrownClaw app
3. Navigate to Favourites screen
4. Should see Upper Kananaskis River and Harvie Passage pre-populated

### Programmatic Test
```bash
# Create a test script to call the function
firebase functions:shell
> initializeNewUserFavorites({auth: {uid: 'test-user-123'}})
```

## Firestore Structure

Created document: `user_favorites/{userId}`

```json
{
  "riverRuns": [
    "09oCVcqR8JjEAJS0PP7E",  // Upper Kananaskis River
    "N0ptPBwD1u2ByePoCOiY"   // Harvie Passage (Bow River)
  ],
  "lastUpdated": <timestamp>,
  "createdAt": <timestamp>
}
```

## Customizing Default Favorites

To change the default rivers, update the `default_favorites` array in `functions/main.py`:

```python
default_favorites = [
    '09oCVcqR8JjEAJS0PP7E',  # Upper Kananaskis River
    'N0ptPBwD1u2ByePoCOiY',  # Harvie Passage (Bow River)
    'YOUR_NEW_RUN_ID_HERE',  # Add more rivers here
]
```

Then redeploy:
```bash
firebase deploy --only functions:initializeNewUserFavorites
```

## Deployment History

- **v1.1.1 (Build 4)** - 2025-10-24: Initial implementation with callable function approach
- Web app deployed: https://brownclaw.web.app
- Function deployed: `initializeNewUserFavorites` (us-central1)

## Notes

- Function is **callable** (not an auth trigger) to give more control over when it runs
- Safe to call multiple times - checks if favorites already exist
- Non-blocking - won't prevent sign-in if it fails
- Compatible with existing `UserFavoritesService` architecture
- Respects Firestore security rules (user must be authenticated)
