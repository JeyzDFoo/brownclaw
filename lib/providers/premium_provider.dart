import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart'; // Commented out while all users are premium

class PremiumProvider extends ChangeNotifier {
  // Commented out - not needed while all users are premium
  // bool _isPremium = false;
  bool _isLoading = false;
  bool _cancelAtPeriodEnd = false;
  DateTime? _currentPeriodEnd;

  // Temporarily make all users premium by default (3-month free trial)
  // TODO: Implement proper 3-month trial logic based on accountCreatedAt
  bool get isPremium => true; // All users are premium by default
  bool get isLoading => _isLoading;
  bool get cancelAtPeriodEnd => _cancelAtPeriodEnd;
  DateTime? get currentPeriodEnd => _currentPeriodEnd;

  PremiumProvider() {
    // Listen to auth state changes and check premium status
    // Commented out while all users are premium by default
    /*
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        _checkPremiumStatus(user.uid);
      } else {
        _isPremium = false;
        notifyListeners();
      }
    });
    */
  }

  Future<void> _checkPremiumStatus(String userId) async {
    // Commented out while all users are premium by default
    /*
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
        _cancelAtPeriodEnd = data?['cancelAtPeriodEnd'] == true;

        // Parse currentPeriodEnd if it exists (Firestore timestamp)
        final periodEndTimestamp = data?['currentPeriodEnd'];
        if (periodEndTimestamp != null) {
          if (periodEndTimestamp is int) {
            // Unix timestamp in seconds
            _currentPeriodEnd = DateTime.fromMillisecondsSinceEpoch(
              periodEndTimestamp * 1000,
            );
          } else if (periodEndTimestamp is double) {
            // Unix timestamp in seconds as double
            _currentPeriodEnd = DateTime.fromMillisecondsSinceEpoch(
              (periodEndTimestamp * 1000).toInt(),
            );
          }
        } else {
          _currentPeriodEnd = null;
        }
      } else {
        _isPremium = false;
        _cancelAtPeriodEnd = false;
        _currentPeriodEnd = null;
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
    */
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
    // Commented out while all users are premium by default
    /*
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
    */
  }
}
