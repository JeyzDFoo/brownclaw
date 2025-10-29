import 'package:flutter/foundation.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Mobile-specific implementation
class StripeServiceImpl {
  static void redirectToCheckout(String url) {
    // Mobile doesn't use redirect - will use payment sheet instead
    throw UnsupportedError('Use payment sheet for mobile payments');
  }

  static String getCurrentUrl() {
    return 'brownclaw://stripe-redirect';
  }

  static void reloadPage() {
    // No-op on mobile
  }

  /// Mobile implementation using flutter_stripe
  static Future<bool> createSubscriptionMobile(
    String priceId,
    User user,
  ) async {
    // Call Cloud Function to create subscription
    final functions = FirebaseFunctions.instance;
    final createSubscription = functions.httpsCallable('createSubscription');

    final result = await createSubscription.call({
      'priceId': priceId,
      'userId': user.uid,
      'email': user.email,
    });

    final data = result.data as Map<String, dynamic>;
    final clientSecret = data['clientSecret'] as String?;

    if (clientSecret == null) {
      throw Exception('Failed to get client secret');
    }

    if (kDebugMode) {
      print('✅ Subscription created, presenting payment sheet...');
    }

    // Present payment sheet
    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        merchantDisplayName: 'Brown Paw',
        paymentIntentClientSecret: clientSecret,
        customerEphemeralKeySecret: data['ephemeralKey'] as String?,
        customerId: data['customer'] as String?,
      ),
    );

    await Stripe.instance.presentPaymentSheet();

    if (kDebugMode) {
      print('✅ Payment completed successfully');
    }

    return true;
  }
}
