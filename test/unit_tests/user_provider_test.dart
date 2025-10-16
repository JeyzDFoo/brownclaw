import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

// Generate mocks for Firebase Auth and User
@GenerateMocks([FirebaseAuth, User])
import 'user_provider_test.mocks.dart';

// Testable version of UserProvider that accepts dependencies
class TestableUserProvider extends ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  final FirebaseAuth _auth;
  StreamSubscription<User?>? _authSubscription;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;

  TestableUserProvider(this._auth) {
    // Listen to auth state changes
    _authSubscription = _auth.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  Future<void> signOut() async {
    setLoading(true);
    try {
      await _auth.signOut();
    } catch (e) {
      // Handle error in production
      rethrow;
    } finally {
      setLoading(false);
    }
  }

  // Test helper method to simulate user changes
  void setUser(User? user) {
    _user = user;
    notifyListeners();
  }
}

void main() {
  group('UserProvider Tests', () {
    late TestableUserProvider userProvider;
    late MockFirebaseAuth mockAuth;
    late MockUser mockUser;
    late StreamController<User?> authStateController;

    setUp(() {
      mockAuth = MockFirebaseAuth();
      mockUser = MockUser();
      authStateController = StreamController<User?>();

      // Setup mock behavior
      when(
        mockAuth.authStateChanges(),
      ).thenAnswer((_) => authStateController.stream);

      // Setup mock user properties
      when(mockUser.uid).thenReturn('test-uid-123');
      when(mockUser.email).thenReturn('test@example.com');
      when(mockUser.displayName).thenReturn('Test User');

      userProvider = TestableUserProvider(mockAuth);
    });

    tearDown(() {
      authStateController.close();
      userProvider.dispose();
    });

    test('should initialize with null user and not loading', () {
      expect(userProvider.user, null);
      expect(userProvider.isLoading, false);
      expect(userProvider.isAuthenticated, false);
    });

    test('should update user when auth state changes', () async {
      // Initially no user
      expect(userProvider.user, null);
      expect(userProvider.isAuthenticated, false);

      // Simulate user sign in
      authStateController.add(mockUser);
      await Future.delayed(Duration.zero); // Allow stream to process

      expect(userProvider.user, mockUser);
      expect(userProvider.isAuthenticated, true);
    });

    test('should update to null when user signs out via auth state', () async {
      // Start with authenticated user
      authStateController.add(mockUser);
      await Future.delayed(Duration.zero);
      expect(userProvider.isAuthenticated, true);

      // Simulate sign out
      authStateController.add(null);
      await Future.delayed(Duration.zero);

      expect(userProvider.user, null);
      expect(userProvider.isAuthenticated, false);
    });

    test('should set and clear loading state', () {
      bool notified = false;
      userProvider.addListener(() {
        notified = true;
      });

      expect(userProvider.isLoading, false);

      userProvider.setLoading(true);
      expect(userProvider.isLoading, true);
      expect(notified, true);

      notified = false;
      userProvider.setLoading(false);
      expect(userProvider.isLoading, false);
      expect(notified, true);
    });

    test('should call Firebase signOut and manage loading state', () async {
      // Setup mock to succeed
      when(mockAuth.signOut()).thenAnswer((_) async => Future.value());

      expect(userProvider.isLoading, false);

      final signOutFuture = userProvider.signOut();

      // Should be loading during sign out
      expect(userProvider.isLoading, true);

      await signOutFuture;

      // Should not be loading after completion
      expect(userProvider.isLoading, false);
      verify(mockAuth.signOut()).called(1);
    });

    test('should handle signOut errors properly', () async {
      // Setup mock to throw error
      when(mockAuth.signOut()).thenThrow(Exception('Sign out failed'));

      expect(userProvider.isLoading, false);

      // Should throw the error
      expect(() => userProvider.signOut(), throwsException);

      // Wait a bit to ensure finally block executes
      await Future.delayed(Duration(milliseconds: 10));

      // Should not be loading after error
      expect(userProvider.isLoading, false);
      verify(mockAuth.signOut()).called(1);
    });

    test('should notify listeners when user changes', () async {
      int notificationCount = 0;
      userProvider.addListener(() {
        notificationCount++;
      });

      // Simulate auth state changes
      authStateController.add(mockUser);
      await Future.delayed(Duration.zero);
      expect(notificationCount, 1);

      authStateController.add(null);
      await Future.delayed(Duration.zero);
      expect(notificationCount, 2);
    });

    test('should return correct authentication status', () async {
      // Initially not authenticated
      expect(userProvider.isAuthenticated, false);

      // After user signs in
      authStateController.add(mockUser);
      await Future.delayed(Duration.zero);
      expect(userProvider.isAuthenticated, true);

      // After user signs out
      authStateController.add(null);
      await Future.delayed(Duration.zero);
      expect(userProvider.isAuthenticated, false);
    });

    test('should handle multiple rapid auth state changes', () async {
      int notificationCount = 0;
      userProvider.addListener(() {
        notificationCount++;
      });

      // Rapid state changes
      authStateController.add(mockUser);
      authStateController.add(null);
      authStateController.add(mockUser);

      await Future.delayed(Duration(milliseconds: 10));

      expect(notificationCount, 3);
      expect(userProvider.user, mockUser);
      expect(userProvider.isAuthenticated, true);
    });
  });
}
