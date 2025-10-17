# Stripe Integration Setup Guide

This guide will help you complete the Stripe integration for premium subscriptions in Brown Claw.

## 🎯 Overview

We've implemented a complete premium subscription system with:
- 3-day chart view (FREE)
- 7-day, 30-day, and 365-day views (PREMIUM)
- Monthly, Yearly, and Lifetime subscription options
- Stripe payment processing

## 📋 Prerequisites

1. **Stripe Account**: Sign up at https://stripe.com
2. **Firebase Project**: Already configured
3. **Flutter SDK**: Already installed

## 🔧 Setup Steps

### 1. Install Dependencies

Run this command to install the new packages:

```bash
flutter pub get
```

This will install:
- `flutter_stripe: ^11.1.0` - Stripe SDK for Flutter
- `cloud_functions: ^5.1.3` - Firebase Cloud Functions

### 2. Configure Stripe Keys

#### Get Your Stripe Keys
1. Go to https://dashboard.stripe.com
2. Navigate to **Developers** → **API Keys**
3. Copy your **Publishable Key** (starts with `pk_test_...` for test mode)
4. Copy your **Secret Key** (starts with `sk_test_...` for test mode)

#### Add Publishable Key to Flutter App

Update `lib/main.dart` to initialize Stripe:

```dart
import 'package:flutter_stripe/flutter_stripe.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Stripe
  Stripe.publishableKey = 'pk_test_YOUR_PUBLISHABLE_KEY_HERE';
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const MainApp());
}
```

### 3. Create Stripe Products & Prices

1. Go to https://dashboard.stripe.com/test/products
2. Click **+ Add product**
3. Create this product:

#### Monthly Premium
- Name: "Premium Monthly"
- Price: $2.00 USD
- Recurring: Monthly
- Copy the **Price ID** (starts with `price_...`)

#### Update Price ID in Code

Edit `lib/screens/premium_purchase_screen.dart`:

```dart
// Replace this with your actual Stripe Price ID
static const String monthlyPriceId = 'price_YOUR_MONTHLY_PRICE_ID';
```

### 4. Set Up Firebase Cloud Functions

#### Install Firebase CLI
```bash
npm install -g firebase-tools
firebase login
```

#### Initialize Cloud Functions
```bash
cd /Users/jeyzdfoo/Desktop/code/brownclaw
firebase init functions
```

Select:
- Use existing project (select your Firebase project)
- Language: TypeScript or JavaScript
- Install dependencies: Yes

#### Create Cloud Functions

Create `functions/src/index.ts` (or `.js`):

```typescript
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import Stripe from 'stripe';

admin.initializeApp();

// Initialize Stripe with your secret key
const stripe = new Stripe('sk_test_YOUR_SECRET_KEY_HERE', {
  apiVersion: '2023-10-16',
});

// Create a subscription
export const createSubscription = functions.https.onCall(async (data, context) => {
  const { priceId, userId, email } = data;

  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  try {
    // Get or create customer
    let customer;
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    const userData = userDoc.data();

    if (userData?.stripeCustomerId) {
      customer = await stripe.customers.retrieve(userData.stripeCustomerId);
    } else {
      customer = await stripe.customers.create({
        email: email,
        metadata: { firebaseUserId: userId },
      });

      // Save customer ID to Firestore
      await admin.firestore().collection('users').doc(userId).set({
        stripeCustomerId: customer.id,
      }, { merge: true });
    }

    // Create subscription
    const subscription = await stripe.subscriptions.create({
      customer: customer.id,
      items: [{ price: priceId }],
      payment_behavior: 'default_incomplete',
      payment_settings: { save_default_payment_method: 'on_subscription' },
      expand: ['latest_invoice.payment_intent'],
    });

    const invoice = subscription.latest_invoice as Stripe.Invoice;
    const paymentIntent = invoice.payment_intent as Stripe.PaymentIntent;

    // Update user premium status
    await admin.firestore().collection('users').doc(userId).set({
      isPremium: true,
      subscriptionId: subscription.id,
      subscriptionStatus: subscription.status,
    }, { merge: true });

    return {
      clientSecret: paymentIntent.client_secret,
      customerId: customer.id,
      subscriptionId: subscription.id,
    };
  } catch (error) {
    console.error('Error creating subscription:', error);
    throw new functions.https.HttpsError('internal', 'Failed to create subscription');
  }
});

// Create a one-time payment
export const createPaymentIntent = functions.https.onCall(async (data, context) => {
  const { amount, currency, userId, email } = data;

  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  try {
    // Get or create customer
    let customer;
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    const userData = userDoc.data();

    if (userData?.stripeCustomerId) {
      customer = await stripe.customers.retrieve(userData.stripeCustomerId);
    } else {
      customer = await stripe.customers.create({
        email: email,
        metadata: { firebaseUserId: userId },
      });

      await admin.firestore().collection('users').doc(userId).set({
        stripeCustomerId: customer.id,
      }, { merge: true });
    }

    // Create payment intent
    const paymentIntent = await stripe.paymentIntents.create({
      amount: amount,
      currency: currency,
      customer: customer.id,
      metadata: {
        userId: userId,
        type: 'lifetime_premium',
      },
    });

    return {
      clientSecret: paymentIntent.client_secret,
      customerId: customer.id,
    };
  } catch (error) {
    console.error('Error creating payment intent:', error);
    throw new functions.https.HttpsError('internal', 'Failed to create payment intent');
  }
});

// Cancel subscription
export const cancelSubscription = functions.https.onCall(async (data, context) => {
  const { userId } = data;

  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  try {
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    const userData = userDoc.data();

    if (!userData?.subscriptionId) {
      throw new functions.https.HttpsError('not-found', 'No active subscription found');
    }

    await stripe.subscriptions.cancel(userData.subscriptionId);

    await admin.firestore().collection('users').doc(userId).set({
      isPremium: false,
      subscriptionStatus: 'canceled',
    }, { merge: true });

    return { success: true };
  } catch (error) {
    console.error('Error canceling subscription:', error);
    throw new functions.https.HttpsError('internal', 'Failed to cancel subscription');
  }
});

// Stripe Webhook Handler
export const stripeWebhook = functions.https.onRequest(async (req, res) => {
  const sig = req.headers['stripe-signature'];
  const webhookSecret = 'whsec_YOUR_WEBHOOK_SECRET';

  try {
    const event = stripe.webhooks.constructEvent(req.rawBody, sig!, webhookSecret);

    switch (event.type) {
      case 'payment_intent.succeeded':
        const paymentIntent = event.data.object as Stripe.PaymentIntent;
        if (paymentIntent.metadata.type === 'lifetime_premium') {
          await admin.firestore().collection('users').doc(paymentIntent.metadata.userId).set({
            isPremium: true,
            subscriptionType: 'lifetime',
          }, { merge: true });
        }
        break;

      case 'customer.subscription.updated':
      case 'customer.subscription.deleted':
        const subscription = event.data.object as Stripe.Subscription;
        const customerId = subscription.customer as string;
        
        // Find user by customer ID
        const usersSnapshot = await admin.firestore()
          .collection('users')
          .where('stripeCustomerId', '==', customerId)
          .limit(1)
          .get();

        if (!usersSnapshot.empty) {
          const userDoc = usersSnapshot.docs[0];
          await userDoc.ref.set({
            isPremium: subscription.status === 'active',
            subscriptionStatus: subscription.status,
          }, { merge: true });
        }
        break;
    }

    res.json({ received: true });
  } catch (error) {
    console.error('Webhook error:', error);
    res.status(400).send('Webhook error');
  }
});
```

#### Install Dependencies for Cloud Functions
```bash
cd functions
npm install stripe
npm install --save-dev @types/stripe
cd ..
```

#### Deploy Cloud Functions
```bash
firebase deploy --only functions
```

### 5. Set Up Stripe Webhooks

1. Go to https://dashboard.stripe.com/test/webhooks
2. Click **+ Add endpoint**
3. Endpoint URL: Your Cloud Function URL (shown after deployment)
   - Example: `https://us-central1-YOUR_PROJECT.cloudfunctions.net/stripeWebhook`
4. Select events to listen to:
   - `payment_intent.succeeded`
   - `customer.subscription.created`
   - `customer.subscription.updated`
   - `customer.subscription.deleted`
5. Copy the **Signing secret** (starts with `whsec_...`)
6. Update it in your Cloud Functions code

### 6. Test the Integration

#### Using Test Cards

Stripe provides test card numbers:

- **Successful payment**: `4242 4242 4242 4242`
- **Requires authentication**: `4000 0025 0000 3155`
- **Declined**: `4000 0000 0000 9995`

Use any future expiry date, any 3-digit CVC, and any ZIP code.

#### Testing Flow

1. Run your Flutter app: `flutter run`
2. Go to **Premium Settings** from the menu
3. Toggle premium OFF (for testing)
4. Click **Upgrade to Premium**
5. Select a plan
6. Use test card: `4242 4242 4242 4242`
7. Complete payment
8. Verify premium status is activated

## 🔒 Security Checklist

- [ ] Never commit Secret Keys to version control
- [ ] Use environment variables for sensitive keys
- [ ] Enable webhook signing verification
- [ ] Test with Stripe test mode first
- [ ] Review Stripe's security best practices

## 📱 Platform-Specific Setup

### iOS

Add to `ios/Runner/Info.plist`:
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
</dict>
```

### Android

No additional configuration needed for Android.

## 🚀 Going Live

When ready for production:

1. Switch to **Live Mode** in Stripe Dashboard
2. Get your **Live API Keys** (starts with `pk_live_...` and `sk_live_...`)
3. Update keys in your app and Cloud Functions
4. Create live Products and Prices
5. Update Price IDs in the app
6. Test thoroughly with real cards (small amounts)
7. Set up proper webhook endpoint for production

## 📊 Monitoring

Monitor your payments in:
- Stripe Dashboard: https://dashboard.stripe.com
- Firebase Console: https://console.firebase.google.com

## 🆘 Troubleshooting

### Payment fails silently
- Check Cloud Function logs in Firebase Console
- Verify API keys are correct
- Ensure webhook endpoint is accessible

### Premium status doesn't update
- Check Firestore rules allow writes
- Verify webhook is receiving events
- Check Firebase Functions logs

### App crashes on payment
- Ensure `flutter pub get` was run
- Check Stripe initialization in main.dart
- Verify all imports are correct

## 📚 Additional Resources

- [Stripe Flutter SDK](https://pub.dev/packages/flutter_stripe)
- [Stripe API Docs](https://stripe.com/docs/api)
- [Firebase Cloud Functions](https://firebase.google.com/docs/functions)
- [Stripe Testing](https://stripe.com/docs/testing)

## ✅ Current Status

### Completed ✓
- [x] Premium provider created
- [x] Paywall UI implemented
- [x] Purchase screen created
- [x] Stripe service layer
- [x] Navigation flows
- [x] 3-day free tier enforced

### To Do
- [ ] Add Stripe publishable key to main.dart
- [ ] Create Stripe products and prices
- [ ] Set up Firebase Cloud Functions
- [ ] Configure Stripe webhooks
- [ ] Test payment flow
- [ ] Deploy to production

---

Need help? Check the [Stripe Documentation](https://stripe.com/docs) or reach out to Stripe support.
