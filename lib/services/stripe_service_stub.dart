import 'package:firebase_auth/firebase_auth.dart';

/// Stub implementation for unsupported platforms
class StripeServiceImpl {
  static void redirectToCheckout(String url) {
    throw UnsupportedError('Platform not supported');
  }

  static String getCurrentUrl() {
    throw UnsupportedError('Platform not supported');
  }

  static void reloadPage() {
    throw UnsupportedError('Platform not supported');
  }

  static Future<bool> createSubscriptionMobile(
    String priceId,
    User user,
  ) async {
    throw UnsupportedError('Platform not supported');
  }
}
