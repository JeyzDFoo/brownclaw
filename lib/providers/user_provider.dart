import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
}
