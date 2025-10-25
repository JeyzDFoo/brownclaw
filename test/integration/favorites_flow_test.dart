import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:brownclaw/providers/favorites_provider.dart';

/// Integration test for the Favorites workflow
/// Tests the complete flow: Auth → Add Favorite → Firestore Sync → Provider State → Cache Persistence
///
/// This test validates:
/// 1. User authentication triggers favorites loading
/// 2. Adding a favorite updates provider state optimistically
/// 3. Favorites sync to Firestore with debouncing
/// 4. Provider listens to Firestore changes in real-time
/// 5. Favorites persist across provider instances (via Firestore stream)
///
/// SETUP: Run Firebase emulators before running this test:
///   firebase emulators:start
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    // Initialize Firebase with emulator-friendly options
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'test-api-key',
        appId: '1:123456789:web:test',
        messagingSenderId: '123456789',
        projectId: 'brownclaw',
      ),
    );

    // Connect to Firebase emulators
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
  });

  group('Favorites Flow Integration Test', () {
    late FavoritesProvider provider;
    late String testUserId;

    setUp(() async {
      // Ensure we have a test user authenticated
      final userCredential = await FirebaseAuth.instance.signInAnonymously();
      testUserId = userCredential.user!.uid;

      // Wait a bit for auth state to propagate
      await Future.delayed(const Duration(milliseconds: 100));

      // Create provider - it should auto-initialize with current user
      provider = FavoritesProvider();

      // Clean up any existing favorites for this test user
      final favoritesDoc = FirebaseFirestore.instance
          .collection('user_favorites')
          .doc(testUserId);
      await favoritesDoc.delete();

      // Wait for provider to sync after cleanup
      await Future.delayed(const Duration(milliseconds: 200));
    });

    tearDown(() async {
      // Clean up test data
      final favoritesDoc = FirebaseFirestore.instance
          .collection('user_favorites')
          .doc(testUserId);
      await favoritesDoc.delete();

      provider.dispose();
      await FirebaseAuth.instance.signOut();
    });

    test('should load empty favorites on initial auth', () async {
      // Given: A new authenticated user with no favorites
      // When: Provider initializes
      // Then: Favorites should be empty
      expect(provider.favoriteRunIds, isEmpty);
      expect(provider.isLoading, false);
      expect(provider.error, null);
    });

    test('should add favorite and sync to Firestore', () async {
      // Given: An authenticated user
      const testRunId = 'test-run-123';

      // When: User adds a favorite
      await provider.toggleFavorite(testRunId);

      // Then: Provider should update optimistically
      expect(provider.isFavorite(testRunId), true);
      expect(provider.favoriteRunIds, contains(testRunId));

      // And: After debounce delay, Firestore should be updated
      await Future.delayed(
        const Duration(milliseconds: 600),
      ); // Debounce is 500ms

      final favoritesDoc = await FirebaseFirestore.instance
          .collection('user_favorites')
          .doc(testUserId)
          .get();

      expect(favoritesDoc.exists, true);
      final data = favoritesDoc.data();
      expect(data, isNotNull);
      expect(data!['rivers'], contains(testRunId));
    });

    test('should remove favorite and sync to Firestore', () async {
      // Given: An authenticated user with an existing favorite
      const testRunId = 'test-run-456';
      await provider.toggleFavorite(testRunId);
      await Future.delayed(
        const Duration(milliseconds: 600),
      ); // Wait for initial sync

      // When: User removes the favorite
      await provider.toggleFavorite(testRunId);

      // Then: Provider should update optimistically
      expect(provider.isFavorite(testRunId), false);
      expect(provider.favoriteRunIds, isNot(contains(testRunId)));

      // And: After debounce delay, Firestore should be updated
      await Future.delayed(const Duration(milliseconds: 600));

      final favoritesDoc = await FirebaseFirestore.instance
          .collection('user_favorites')
          .doc(testUserId)
          .get();

      // Document might exist but rivers array should be empty or not contain the run
      if (favoritesDoc.exists) {
        final data = favoritesDoc.data();
        if (data != null && data.containsKey('rivers')) {
          expect(data['rivers'], isNot(contains(testRunId)));
        }
      }
    });

    test('should handle rapid toggles with debouncing', () async {
      // Given: An authenticated user
      const testRunId = 'test-run-rapid';

      // When: User rapidly toggles favorite (simulate accidental double-tap)
      await provider.toggleFavorite(testRunId); // Add
      await Future.delayed(const Duration(milliseconds: 100));
      await provider.toggleFavorite(testRunId); // Remove
      await Future.delayed(const Duration(milliseconds: 100));
      await provider.toggleFavorite(testRunId); // Add again

      // Then: UI should show final state immediately
      expect(provider.isFavorite(testRunId), true);

      // And: After debounce, Firestore should have the final state
      await Future.delayed(const Duration(milliseconds: 600));

      final favoritesDoc = await FirebaseFirestore.instance
          .collection('user_favorites')
          .doc(testUserId)
          .get();

      expect(favoritesDoc.exists, true);
      final data = favoritesDoc.data();
      expect(data!['rivers'], contains(testRunId));
    });

    test(
      'should sync favorites across provider instances via Firestore stream',
      () async {
        // Given: A provider with a favorite
        const testRunId = 'test-run-persistence';
        await provider.toggleFavorite(testRunId);
        await Future.delayed(
          const Duration(milliseconds: 600),
        ); // Wait for Firestore sync

        // When: We create a new provider instance (simulating app restart or provider recreation)
        final newProvider = FavoritesProvider();

        // Wait for new provider to receive Firestore stream update
        await Future.delayed(const Duration(milliseconds: 300));

        // Then: New provider should have the favorite from Firestore
        expect(newProvider.isFavorite(testRunId), true);
        expect(newProvider.favoriteRunIds, contains(testRunId));

        // Cleanup
        newProvider.dispose();
      },
    );

    test('should handle Firestore errors gracefully', () async {
      // This test is harder to implement with real Firebase
      // In a real scenario, you'd use Firebase emulators and trigger rule violations
      // For now, we verify the error state mechanism exists
      expect(provider.error, null);

      // The provider has setError() method which can be triggered by Firestore errors
      provider.setError('Test error');
      expect(provider.error, 'Test error');

      // Clear error
      provider.setError(null);
      expect(provider.error, null);
    });

    test('should clear favorites on sign out', () async {
      // Given: A user with favorites
      const testRunId = 'test-run-signout';
      await provider.toggleFavorite(testRunId);
      await Future.delayed(const Duration(milliseconds: 600));
      expect(provider.favoriteRunIds, isNotEmpty);

      // When: User signs out
      await FirebaseAuth.instance.signOut();

      // Wait for auth state change to propagate
      await Future.delayed(const Duration(milliseconds: 200));

      // Then: Provider should clear favorites
      expect(provider.favoriteRunIds, isEmpty);
    });

    test('should reload favorites on sign in after sign out', () async {
      // Given: A user with favorites who signs out
      const testRunId = 'test-run-reload';
      await provider.toggleFavorite(testRunId);
      await Future.delayed(const Duration(milliseconds: 600));

      final originalUserId = testUserId;

      await FirebaseAuth.instance.signOut();
      await Future.delayed(const Duration(milliseconds: 200));
      expect(provider.favoriteRunIds, isEmpty);

      // When: User signs back in
      final userCredential = await FirebaseAuth.instance.signInAnonymously();
      testUserId = userCredential.user!.uid;

      // Note: This creates a NEW anonymous user, so favorites won't persist
      // This test validates the auth → load favorites flow
      await Future.delayed(const Duration(milliseconds: 300));

      // Then: Provider should attempt to load favorites (will be empty for new user)
      expect(provider.favoriteRunIds, isEmpty);
      expect(provider.error, null);

      // Cleanup the original user's data
      await FirebaseFirestore.instance
          .collection('user_favorites')
          .doc(originalUserId)
          .delete();
    });

    test('should support multiple favorites', () async {
      // Given: An authenticated user
      const runId1 = 'run-1';
      const runId2 = 'run-2';
      const runId3 = 'run-3';

      // When: User adds multiple favorites
      await provider.toggleFavorite(runId1);
      await provider.toggleFavorite(runId2);
      await provider.toggleFavorite(runId3);

      // Then: All should be in provider state
      expect(provider.favoriteRunIds, containsAll([runId1, runId2, runId3]));
      expect(provider.favoriteRunIds.length, 3);

      // And: After sync, all should be in Firestore
      await Future.delayed(const Duration(milliseconds: 600));

      final favoritesDoc = await FirebaseFirestore.instance
          .collection('user_favorites')
          .doc(testUserId)
          .get();

      final data = favoritesDoc.data();
      final rivers = List<String>.from(data!['rivers']);
      expect(rivers, containsAll([runId1, runId2, runId3]));
    });
  });
}
