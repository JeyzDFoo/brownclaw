import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PremiumProvider extends ChangeNotifier {
  bool _isPremium = false;
  bool _isLoading = false;

  bool get isPremium => _isPremium;
  bool get isLoading => _isLoading;

  PremiumProvider() {
    // Listen to auth state changes and check premium status
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        _checkPremiumStatus(user.uid);
      } else {
        _isPremium = false;
        notifyListeners();
      }
    });
  }

  Future<void> _checkPremiumStatus(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (doc.exists) {
        final data = doc.data();
        _isPremium = data?['isPremium'] == true;
      } else {
        _isPremium = false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error checking premium status: $e');
      }
      _isPremium = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Manually refresh premium status
  Future<void> refreshPremiumStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _checkPremiumStatus(user.uid);
    }
  }

  /// For testing/admin purposes - toggle premium status
  Future<void> setPremiumStatus(bool premium) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'isPremium': premium,
      }, SetOptions(merge: true));

      _isPremium = premium;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error setting premium status: $e');
      }
    }
  }
}
