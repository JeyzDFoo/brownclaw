import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserProvider extends ChangeNotifier {
  User? _user;
  bool _isLoading = false;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;

  // Check if current user is an admin
  // Currently set to make all users admin by default
  bool get isAdmin {
    return true; // All users are admin by default
    // To use email-based admin check, replace with:
    // if (_user == null || _user!.email == null) return false;
    // return _adminEmails.contains(_user!.email!.toLowerCase());
  }

  UserProvider() {
    // Listen to auth state changes
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  Future<void> signOut() async {
    setLoading(true);
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      if (kDebugMode) {
        print('Error signing out: $e');
      }
    } finally {
      setLoading(false);
    }
  }

  Future<void> deleteAccount() async {
    if (_user == null) {
      throw Exception('No user logged in');
    }

    setLoading(true);
    try {
      final userId = _user!.uid;
      final firestore = FirebaseFirestore.instance;

      // Delete user data from Firestore
      // Delete user favorites
      await firestore.collection('user_favorites').doc(userId).delete();

      // Delete user's river descents (logbook entries)
      final descentsQuery = await firestore
          .collection('river_descents')
          .where('userId', isEqualTo: userId)
          .get();

      for (var doc in descentsQuery.docs) {
        await doc.reference.delete();
      }

      // Delete user document if it exists
      await firestore.collection('users').doc(userId).delete();

      // Delete Firebase Auth account
      await _user!.delete();

      if (kDebugMode) {
        print('✅ Account deleted successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error deleting account: $e');
      }
      rethrow;
    } finally {
      setLoading(false);
    }
  }
}
