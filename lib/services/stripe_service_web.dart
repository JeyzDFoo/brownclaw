import 'dart:html' as html;
import 'package:firebase_auth/firebase_auth.dart';

/// Web-specific implementation
class StripeServiceImpl {
  static void redirectToCheckout(String url) {
    html.window.location.href = url;
  }

  static String getCurrentUrl() {
    return html.window.location.href;
  }

  static void reloadPage() {
    html.window.location.reload();
  }

  /// Web doesn't support mobile payment sheet
  static Future<bool> createSubscriptionMobile(
    String priceId,
    User user,
  ) async {
    throw UnsupportedError('Mobile payment sheet not available on web');
  }
}
