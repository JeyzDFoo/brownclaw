import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class GoogleSignInService {
  static GoogleSignIn? _googleSignInInstance;

  static GoogleSignIn get _googleSignIn {
    if (_googleSignInInstance == null) {
      if (kIsWeb) {
        // On web, clientId is configured via index.html meta tag
        // Don't pass clientId here for web
        _googleSignInInstance = GoogleSignIn(scopes: ['email', 'profile']);
      } else {
        // On mobile/desktop, pass the clientId
        _googleSignInInstance = GoogleSignIn(
          clientId:
              '1047120968895-f56596g53nq4fnkf8n78q1hsl97a8fk7.apps.googleusercontent.com',
          scopes: ['email', 'profile'],
        );
      }
    }
    return _googleSignInInstance!;
  }

  static Future<UserCredential?> signInWithGoogle() async {
    try {
      print('🟦 GoogleSignInService: Starting Google Sign-In process...');

      if (kIsWeb) {
        // On web, use Firebase Auth's signInWithPopup directly
        // This is more reliable than google_sign_in package on web
        print('🟦 GoogleSignInService: Web platform - using Firebase popup...');

        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');

        try {
          final userCredential = await FirebaseAuth.instance.signInWithPopup(
            googleProvider,
          );

          print('✅ GoogleSignInService: Firebase sign-in successful!');
          print(
            '✅ GoogleSignInService: Firebase user: ${userCredential.user?.email}',
          );

          return userCredential;
        } catch (e) {
          print('🔴 GoogleSignInService: Popup sign-in failed: $e');
          rethrow;
        }
      } else {
        // For mobile/desktop, use google_sign_in package
        print(
          '🟦 GoogleSignInService: Mobile/Desktop platform - using google_sign_in package...',
        );

        final googleUser = await _googleSignIn.signIn();

        print(
          '🟦 GoogleSignInService: GoogleSignInAccount result: ${googleUser != null ? "SUCCESS" : "NULL"}',
        );
        if (googleUser != null) {
          print('🟦 GoogleSignInService: User email: ${googleUser.email}');
          print(
            '🟦 GoogleSignInService: User displayName: ${googleUser.displayName}',
          );
          print('🟦 GoogleSignInService: User id: ${googleUser.id}');
        }

        if (googleUser == null) {
          print('🟠 GoogleSignInService: User cancelled the sign-in');
          return null;
        }

        // Obtain the auth details from the request
        print('🟦 GoogleSignInService: Getting authentication details...');
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        print(
          '🟦 GoogleSignInService: Access token: ${googleAuth.accessToken != null ? "PRESENT" : "NULL"}',
        );
        print(
          '🟦 GoogleSignInService: ID token: ${googleAuth.idToken != null ? "PRESENT" : "NULL"}',
        );

        // Check if we have the necessary tokens
        if (googleAuth.accessToken == null) {
          print('🔴 GoogleSignInService: No access token received!');
          throw Exception('Failed to get access token from Google');
        }

        // Create a new credential
        print('🟦 GoogleSignInService: Creating Firebase credential...');
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        print('🟦 GoogleSignInService: Credential created successfully');

        // Sign in to Firebase with the Google credential
        print(
          '🟦 GoogleSignInService: Signing in to Firebase with credential...',
        );
        final userCredential = await FirebaseAuth.instance.signInWithCredential(
          credential,
        );

        print('🟢 GoogleSignInService: Firebase sign-in successful!');
        print(
          '🟢 GoogleSignInService: Firebase user: ${userCredential.user?.email}',
        );

        return userCredential;
      }
    } catch (e) {
      print('🔴 GoogleSignInService: Exception caught!');
      print('🔴 GoogleSignInService: Exception type: ${e.runtimeType}');
      print('🔴 GoogleSignInService: Exception message: $e');
      print('🔴 GoogleSignInService: Stack trace will follow...');

      // Provide more detailed error information
      rethrow;
    }
  }

  static Future<void> signOut() async {
    try {
      await Future.wait([
        FirebaseAuth.instance.signOut(),
        _googleSignIn.signOut(),
      ]);
    } catch (e) {
      // Handle error - in production, use a proper logging framework
      rethrow;
    }
  }

  static bool get isSignedIn => _googleSignIn.currentUser != null;

  static GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;
}
