# 🚨 Favorites Not Loading - Quick Debug Guide

## The Issue
Favorites aren't loading on the Favorites screen, but you can see them in Find Runs.

## Most Likely Causes

### 1. Hot Reload Problem ⚡
**The most common cause!**

When you hot reload or hot restart, the provider constructors don't always run again. The state might be stale.

**Solution:** 
- **STOP the app completely** (not just hot reload)
- **Restart it fresh**
- This ensures all providers initialize from scratch

### 2. FavoritesProvider Constructor Not Running
The `currentUser` check might not be working.

**Check:**
```dart
FavoritesProvider() {
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser != null) {
    print('👤 User already authenticated...'); // Should see this!
    _loadFavorites();
  }
  // ... rest of constructor
}
```

**Look for this in console:** `👤 FavoritesProvider: User already authenticated on init`

### 3. Stream Not Emitting
The Firestore stream might not be returning data.

**Check in `user_favorites_service.dart`:**
```dart
static Stream<List<String>> getUserFavoriteRunIds() {
  final user = _auth.currentUser;
  if (user == null) return Stream.value([]); // ⚠️ This might be the issue!
  
  // Add debug logging here:
  print('🔍 getUserFavoriteRunIds called for user: ${user.uid}');
  
  return _favoritesCollection.doc(user.uid).snapshots().map((doc) {
    if (!doc.exists) {
      print('⚠️  No favorites document exists!');
      return <String>[];
    }
    final data = doc.data() as Map<String, dynamic>?;
    final favoriteRuns = data?['riverRuns'] as List?;
    final result = favoriteRuns?.cast<String>() ?? <String>[];
    print('📊 Loaded ${result.length} favorite IDs from Firestore');
    return result;
  });
}
```

### 4. Firestore Document Doesn't Exist
You might not have any favorites actually saved in Firestore.

**How to check:**
1. Open Firebase Console
2. Go to Firestore Database
3. Look for collection: `user_favorites`
4. Find document with your user ID
5. Check if `riverRuns` array has values

**OR** add a favorite from Find Runs screen and see if it persists.

## Quick Debug Steps

### Step 1: Add More Logging
Edit `/Users/jeyzdfoo/Desktop/code/brownclaw/lib/services/user_favorites_service.dart`:

Find line 52 (in `getUserFavoriteRunIds()`):
```dart
static Stream<List<String>> getUserFavoriteRunIds() {
  final user = _auth.currentUser;
  
  // ADD THIS:
  if (kDebugMode) {
    print('🔍 getUserFavoriteRunIds: currentUser = ${user?.uid ?? "NULL"}');
  }
  
  if (user == null) {
    if (kDebugMode) {
      print('❌ getUserFavoriteRunIds: No user, returning empty stream');
    }
    return Stream.value([]);
  }
  
  // ... rest of method
}
```

### Step 2: Run the Debug Script
```bash
cd /Users/jeyzdfoo/Desktop/code/brownclaw
./debug_favorites.sh
```

This will show you exactly what's happening in order.

### Step 3: Check the Console Output
You should see this sequence:

```
🚀 RiverRunProvider: Initializing and loading all runs...
👤 FavoritesProvider: User already authenticated on init (abc123)
🔍 getUserFavoriteRunIds: currentUser = abc123
⭐ FavoritesProvider: Loaded 5 favorites
🔍 FavouritesScreen: Checking favorites - current: 5, previous: 0
🔄 FavouritesScreen: Favorites changed! Loading 5 favorites...
📥 FavouritesScreen: Calling loadFavoriteRuns with 5 IDs
⚡ CACHE HIT: Found all 5 favorites from all-runs cache
```

### Step 4: Identify Where It Breaks

- **No `👤` log**: FavoritesProvider constructor not running → Try full app restart
- **`👤` but no `🔍`**: _loadFavorites() not being called → Check constructor logic
- **`🔍` but no `⭐`**: Stream not emitting → Check Firestore data exists
- **`⭐` but no `🔍 FavouritesScreen`**: Screen not reacting → Provider not in widget tree
- **`🔍 FavouritesScreen` but shows 0**: Provider state not updating → Check notifyListeners()

## Nuclear Option: Force Reload

Add this to the Favorites screen's `initState`:

```dart
@override
void initState() {
  super.initState();
  
  // Force reload after build
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) {
      final favProvider = context.read<FavoritesProvider>();
      final rivProvider = context.read<RiverRunProvider>();
      
      print('🔧 FORCE RELOAD: favorites=${favProvider.favoriteRunIds.length}');
      
      if (favProvider.favoriteRunIds.isNotEmpty) {
        rivProvider.loadFavoriteRuns(favProvider.favoriteRunIds);
      }
    }
  });
}
```

## Still Not Working?

Share your console output with these specific logs:
1. Everything from app start until you navigate to Favorites
2. Any errors or exceptions
3. The output of `flutter doctor -v`

---

**Created**: 2025-10-17
**Last Updated**: 2025-10-17
