import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

void main() {
  test('Debug: Check if currentUser works before authStateChanges', () async {
    // This test verifies the timing issue

    print('🔍 TEST: Simulating FavoritesProvider initialization...');

    // Simulate what happens in the constructor
    print('1️⃣ Checking FirebaseAuth.instance.currentUser...');
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
      print('✅ User is logged in: ${currentUser.uid}');
      print('   This should trigger _loadFavorites()');
    } else {
      print('❌ No user logged in');
      print('   Waiting for authStateChanges...');
    }

    print('2️⃣ Setting up authStateChanges listener...');
    final subscription = FirebaseAuth.instance.authStateChanges().listen((
      user,
    ) {
      if (user != null) {
        print('✅ authStateChanges fired: User signed in');
      } else {
        print('❌ authStateChanges fired: User signed out');
      }
    });

    // Wait a bit
    await Future.delayed(Duration(seconds: 1));

    print('3️⃣ After 1 second, checking currentUser again...');
    final userAfter = FirebaseAuth.instance.currentUser;
    print('   User: ${userAfter?.uid ?? "null"}');

    subscription.cancel();

    print('');
    print('🎯 EXPECTED BEHAVIOR:');
    print(
      '   - If user already logged in: currentUser returns user immediately',
    );
    print('   - authStateChanges does NOT fire (because no change occurred)');
    print(
      '   - We MUST call _loadFavorites() in the if (currentUser != null) block',
    );
    print('');
    print('🎯 COMMON MISTAKE:');
    print('   - Only listening to authStateChanges');
    print('   - Missing the check for current user on initialization');
    print('   - Results in favorites never loading on app restart');
  });
}
