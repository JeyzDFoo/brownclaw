import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_stripe/flutter_stripe.dart'
    if (dart.library.html) 'package:cloud_functions/cloud_functions.dart';
import 'stripe_service_stub.dart'
    if (dart.library.html) 'stripe_service_web.dart'
    if (dart.library.io) 'stripe_service_mobile.dart';

/// Stripe Service for Web and Mobile
/// Web: Uses Stripe Checkout (hosted payment page)
/// Mobile: Uses flutter_stripe SDK for native payment sheets
class StripeService {
  static final StripeService _instance = StripeService._internal();
  factory StripeService() => _instance;
  StripeService._internal();

  static const String publishableKey =
      'pk_live_51SJ0MEAdlcDQOrDhhUZHnuVr7lzgZxeY4gQ2TyzDjtWv4li2XBGtgTpRFlkOHi2BQYTv3Uoey8IliofMrUvYwNyY00zsQfET3S';

  /// Create a subscription for the current user
  /// Web: Redirects to Stripe Checkout page
  /// Mobile: Opens native payment sheet
  Future<bool> createSubscription({required String priceId}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User must be logged in to subscribe');
      }

      if (kDebugMode) {
        print('🔄 Creating Stripe Checkout session for user: ${user.uid}');
        print('   Price ID: $priceId');
      }

      if (kIsWeb) {
        return _createSubscriptionWeb(priceId, user);
      } else {
        return _createSubscriptionMobile(priceId, user);
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error creating subscription: $e');
      }
      rethrow;
    }
  }

  /// Web implementation using Stripe Checkout
  Future<bool> _createSubscriptionWeb(String priceId, User user) async {
    // Call Cloud Function to create Stripe Checkout session
    final functions = FirebaseFunctions.instance;
    final createCheckoutSession = functions.httpsCallable(
      'createCheckoutSession',
    );

    final currentUrl = StripeServiceImpl.getCurrentUrl();

    final result = await createCheckoutSession.call({
      'priceId': priceId,
      'userId': user.uid,
      'email': user.email,
      'successUrl': currentUrl,
      'cancelUrl': currentUrl,
    });

    final data = result.data as Map<String, dynamic>;
    final checkoutUrl = data['url'] as String?;

    if (checkoutUrl == null) {
      throw Exception('Failed to get checkout URL');
    }

    if (kDebugMode) {
      print('✅ Checkout session created, redirecting to Stripe...');
    }

    // Redirect to Stripe Checkout
    StripeServiceImpl.redirectToCheckout(checkoutUrl);

    return true;
  }

  /// Mobile implementation using flutter_stripe
  Future<bool> _createSubscriptionMobile(String priceId, User user) async {
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

  /// Create a one-time payment for premium (lifetime)
  Future<bool> createOneTimePayment({
    required int amountCents,
    required String currency,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User must be logged in to make a payment');
      }

      if (kDebugMode) {
        print('🔄 Creating checkout session for user: ${user.uid}');
        print('   Amount: $amountCents cents ($currency)');
      }

      // For now, we'll use subscription flow only
      // You can implement one-time payments later if needed
      throw UnimplementedError('One-time payments not yet implemented for web');
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error creating payment: $e');
      }
      rethrow;
    }
  }

  /// Cancel user's subscription
  Future<bool> cancelSubscription() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User must be logged in');
      }

      if (kDebugMode) {
        print('🔄 Cancelling subscription for user: ${user.uid}');
      }

      final functions = FirebaseFunctions.instance;
      final cancelSubscription = functions.httpsCallable('cancelSubscription');

      await cancelSubscription.call({'userId': user.uid});

      if (kDebugMode) {
        print('✅ Subscription cancelled successfully');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error cancelling subscription: $e');
      }
      rethrow;
    }
  }

  /// Get user's subscription status
  Future<Map<String, dynamic>?> getSubscriptionStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final functions = FirebaseFunctions.instance;
      final getStatus = functions.httpsCallable('getSubscriptionStatus');

      final result = await getStatus.call({'userId': user.uid});

      return result.data as Map<String, dynamic>?;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting subscription status: $e');
      }
      return null;
    }
  }
}
