import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class GoogleSignInService {
  static GoogleSignIn? _googleSignInInstance;

  static GoogleSignIn get _googleSignIn {
    _googleSignInInstance ??= GoogleSignIn(
      clientId:
          '1047120968895-f56596g53nq4fnkf8n78q1hsl97a8fk7.apps.googleusercontent.com',
      scopes: ['email', 'profile'],
    );
    return _googleSignInInstance!;
  }

  static Future<UserCredential?> signInWithGoogle() async {
    try {
      print('🟦 GoogleSignInService: Starting Google Sign-In process...');

      // For web, try silent sign-in first (recommended approach)
      GoogleSignInAccount? googleUser;

      if (kIsWeb) {
        print(
          '🟦 GoogleSignInService: Web platform - trying silent sign-in first...',
        );
        try {
          googleUser = await _googleSignIn.signInSilently();
          if (googleUser == null) {
            print(
              '🟦 GoogleSignInService: Silent sign-in returned null, using interactive sign-in...',
            );
            googleUser = await _googleSignIn.signIn();
          } else {
            print('🟦 GoogleSignInService: Silent sign-in successful!');
          }
        } catch (e) {
          print(
            '🟠 GoogleSignInService: Silent sign-in failed, falling back to interactive: $e',
          );
          googleUser = await _googleSignIn.signIn();
        }
      } else {
        // For mobile/desktop, use the standard sign-in
        print(
          '🟦 GoogleSignInService: Mobile/Desktop platform - using standard sign-in...',
        );
        googleUser = await _googleSignIn.signIn();
      }

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

      if (googleAuth.accessToken != null) {
        print(
          '🟦 GoogleSignInService: Access token length: ${googleAuth.accessToken!.length}',
        );
      }
      if (googleAuth.idToken != null) {
        print(
          '🟦 GoogleSignInService: ID token length: ${googleAuth.idToken!.length}',
        );
      }

      // Check if we have the necessary tokens
      if (googleAuth.accessToken == null) {
        print('🔴 GoogleSignInService: No access token received!');
        throw Exception('Failed to get access token from Google');
      }

      // Create a new credential - idToken might be null on web
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
