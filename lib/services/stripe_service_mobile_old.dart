import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StripeService {
  static final StripeService _instance = StripeService._internal();
  factory StripeService() => _instance;
  StripeService._internal();

  bool _initialized = false;

  /// Initialize Stripe with your publishable key
  /// Call this in main.dart before runApp()
  Future<void> initialize(String publishableKey) async {
    if (_initialized) return;

    try {
      Stripe.publishableKey = publishableKey;
      await Stripe.instance.applySettings();
      _initialized = true;
      if (kDebugMode) {
        print('✅ Stripe initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing Stripe: $e');
      }
      rethrow;
    }
  }

  /// Create a subscription for the current user
  /// Returns true if successful, false otherwise
  Future<bool> createSubscription({required String priceId}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User must be logged in to subscribe');
      }

      if (kDebugMode) {
        print('🔄 Creating subscription for user: ${user.uid}');
        print('   Price ID: $priceId');
      }

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
        throw Exception('Failed to get payment client secret');
      }

      // Present payment sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          merchantDisplayName: 'Brown Claw',
          paymentIntentClientSecret: clientSecret,
          customerEphemeralKeySecret: data['ephemeralKey'] as String?,
          customerId: data['customerId'] as String?,
          style: ThemeMode.system,
        ),
      );

      await Stripe.instance.presentPaymentSheet();

      if (kDebugMode) {
        print('✅ Subscription created successfully');
      }

      return true;
    } on StripeException catch (e) {
      if (kDebugMode) {
        print('❌ Stripe error: ${e.error.localizedMessage}');
      }
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error creating subscription: $e');
      }
      rethrow;
    }
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
        print('🔄 Creating one-time payment for user: ${user.uid}');
        print('   Amount: $amountCents cents ($currency)');
      }

      // Call Cloud Function to create payment intent
      final functions = FirebaseFunctions.instance;
      final createPaymentIntent = functions.httpsCallable(
        'createPaymentIntent',
      );

      final result = await createPaymentIntent.call({
        'amount': amountCents,
        'currency': currency,
        'userId': user.uid,
        'email': user.email,
      });

      final data = result.data as Map<String, dynamic>;
      final clientSecret = data['clientSecret'] as String?;

      if (clientSecret == null) {
        throw Exception('Failed to get payment client secret');
      }

      // Present payment sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          merchantDisplayName: 'Brown Claw',
          paymentIntentClientSecret: clientSecret,
          customerEphemeralKeySecret: data['ephemeralKey'] as String?,
          customerId: data['customerId'] as String?,
          style: ThemeMode.system,
        ),
      );

      await Stripe.instance.presentPaymentSheet();

      if (kDebugMode) {
        print('✅ Payment completed successfully');
      }

      return true;
    } on StripeException catch (e) {
      if (kDebugMode) {
        print('❌ Stripe error: ${e.error.localizedMessage}');
      }
      rethrow;
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
