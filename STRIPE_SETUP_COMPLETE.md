# Stripe Setup - Complete Guide

**Date:** October 18, 2025  
**Status:** ✅ Cloud Functions Deployed | ⏳ Product Setup Needed

---

## ✅ What's Already Done

### 1. Flutter App Configuration
- ✅ Stripe SDK initialized in `main.dart`
- ✅ Publishable Key added: `pk_live_51SJ0MEAdlcDQOrDh...`
- ✅ `StripeService` implemented for payment processing
- ✅ `PremiumPurchaseScreen` ready for subscriptions
- ✅ Premium paywall active (3-day free, 7d/30d/365d premium)

### 2. Cloud Functions Deployed
- ✅ `createSubscription` - Creates monthly subscriptions
- ✅ `createPaymentIntent` - Processes one-time payments
- ✅ `cancelSubscription` - Cancels subscriptions
- ✅ `getSubscriptionStatus` - Checks subscription status
- ✅ `stripeWebhook` - Handles Stripe events

**Function URLs:**
```
createSubscription: https://us-central1-brownclaw.cloudfunctions.net/createSubscription
stripeWebhook: https://stripewebhook-r7yfhehdra-uc.a.run.app
```

### 3. Security Configured
- ✅ Secret key stored in `functions/.env` (gitignored)
- ✅ Webhook endpoint deployed and fixed
- ✅ Environment variables loaded properly

---

## 📋 What You Need To Do Now

### Step 1: Create Stripe Product (5 minutes)

1. **Go to Stripe Products:**
   - Visit: https://dashboard.stripe.com/products
   - Click **"+ Add product"**

2. **Create Monthly Subscription:**
   ```
   Product Name: Premium Monthly
   Description: Access to 7-day, 30-day, and 365-day historical chart views
   
   Pricing:
   - Price: $2.00 USD
   - Billing Period: Monthly (recurring)
   - Currency: USD
   
   Click "Add product"
   ```

3. **Copy the Price ID:**
   - After creating, you'll see a Price ID like: `price_1ABC123xyz...`
   - **COPY THIS ID** - you need it in the next step

### Step 2: Update Flutter App with Price ID (1 minute)

Open `lib/screens/premium_purchase_screen.dart` and update line 22-23:

**BEFORE:**
```dart
static const String monthlyPriceId =
    'price_XXXXXXXXXXXXX'; // Replace with your price_xxx ID
```

**AFTER:**
```dart
static const String monthlyPriceId =
    'price_YOUR_ACTUAL_PRICE_ID_HERE'; // Replace with the ID from Step 1
```

### Step 3: Verify Webhook is Connected (Already Done! ✅)

Your webhook endpoint is already set up:
- URL: `https://stripewebhook-r7yfhehdra-uc.a.run.app`
- Events: `customer.subscription.updated`, `customer.subscription.deleted`, `payment_intent.succeeded`
- Secret is in your `.env` file

---

## 🧪 Testing Your Integration

### Test Card Numbers (Stripe Test Mode)

| Card Number | Result |
|------------|--------|
| `4242 4242 4242 4242` | ✅ Success |
| `4000 0000 0000 9995` | ❌ Declined |
| `4000 0027 6000 3184` | 🔐 Requires authentication |

**Other test details:**
- Expiration: Any future date (e.g., 12/30)
- CVC: Any 3 digits (e.g., 123)
- ZIP: Any 5 digits (e.g., 12345)

### Testing Flow

1. **Launch your app** (development mode)
2. **Navigate to Premium:**
   - Menu → "Premium Settings" → "Upgrade to Premium"
3. **Select Monthly Plan** ($2.00/month)
4. **Enter test card:** `4242 4242 4242 4242`
5. **Complete payment**
6. **Verify:**
   - User shows as premium in Firestore: `users/{userId}/isPremium: true`
   - Chart view unlocks 7d, 30d, 365d options
   - Premium icon appears in app menu

---

## 🔄 How It Works

### Payment Flow

```
User clicks "Subscribe"
    ↓
Flutter app calls Cloud Function (createSubscription)
    ↓
Cloud Function creates Stripe subscription
    ↓
Returns clientSecret to Flutter
    ↓
Flutter shows Stripe payment sheet
    ↓
User enters card details
    ↓
Stripe processes payment
    ↓
Webhook notifies Cloud Function
    ↓
Cloud Function updates Firestore (isPremium: true)
    ↓
Flutter app detects premium status
    ↓
Premium features unlocked! 🎉
```

### What Each File Does

**Flutter App:**
- `main.dart` - Initializes Stripe with publishable key
- `stripe_service.dart` - Calls Cloud Functions for payments
- `premium_purchase_screen.dart` - Shows subscription options
- `premium_provider.dart` - Manages premium status

**Cloud Functions:**
- `createSubscription` - Creates Stripe subscription, returns payment intent
- `stripeWebhook` - Receives Stripe events, updates Firestore
- `getSubscriptionStatus` - Checks if user is premium
- `cancelSubscription` - Cancels user subscription

**Firestore:**
```
users/{userId}/
  ├── isPremium: true/false
  ├── stripeCustomerId: "cus_..."
  ├── subscriptionId: "sub_..."
  └── subscriptionStatus: "active"
```

---

## 🚀 Going Live (When Ready)

### Switch from Test to Live Mode

1. **Get Live Keys from Stripe:**
   - Publishable: `pk_live_...`
   - Secret: `sk_live_...`
   - (You already have these!)

2. **Update Flutter:**
   ```dart
   // main.dart - Already using live key ✅
   Stripe.publishableKey = 'pk_live_51SJ0MEAdlcDQOrDh...';
   ```

3. **Update Cloud Functions:**
   ```bash
   # functions/.env - Already using live key ✅
   STRIPE_SECRET_KEY=sk_live_51SJ0MEAdlcDQOrDh...
   ```

4. **Recreate Webhook for Live:**
   - Go to: https://dashboard.stripe.com/webhooks
   - Toggle from "Test" to "Live" mode
   - Add same endpoint: `https://stripewebhook-r7yfhehdra-uc.a.run.app`
   - Select same events
   - Copy new webhook secret
   - Update `functions/.env` with new `STRIPE_WEBHOOK_SECRET`
   - Redeploy: `firebase deploy --only functions`

5. **Test with Real Card:**
   - Use your own card for a $2 test
   - Verify it works end-to-end
   - Cancel immediately in Stripe dashboard if needed

---

## 📊 Monitoring

### Check Stripe Dashboard
- Payments: https://dashboard.stripe.com/payments
- Subscriptions: https://dashboard.stripe.com/subscriptions
- Customers: https://dashboard.stripe.com/customers
- Webhooks: https://dashboard.stripe.com/webhooks

### Check Firebase Console
- Firestore: See user premium status
- Functions Logs: Check for errors
- Authentication: See user list

### Check App
- Users with `isPremium: true` can access all chart views
- Premium icon shows in menu
- Free users see lock icons on 7d/30d/365d

---

## ❓ Troubleshooting

### "Payment failed"
- Check Cloud Functions logs: `firebase functions:log`
- Verify secret key is correct in `.env`
- Ensure functions are deployed

### "Webhook not receiving events"
- Verify webhook URL in Stripe dashboard
- Check webhook secret matches `.env`
- Test webhook in Stripe dashboard (send test event)

### "User not showing as premium"
- Check Firestore for `isPremium` field
- Verify webhook processed successfully
- Call `getSubscriptionStatus` function manually

### "Price ID not found"
- Verify you copied the correct Price ID from Stripe
- Check you're using the right mode (test vs live)
- Ensure product is active in Stripe

---

## 📞 Quick Commands

```bash
# Deploy all functions
firebase deploy --only functions

# Deploy specific function
firebase deploy --only functions:createSubscription

# View logs
firebase functions:log

# Test locally (if needed)
cd functions
source venv/bin/activate
python main.py
```

---

## ✅ Checklist

- [x] Cloud Functions deployed
- [x] Webhook endpoint configured
- [x] Secret keys secured in .env
- [x] Flutter app has publishable key
- [ ] **Create Stripe Product** (Do this now!)
- [ ] **Add Price ID to Flutter app** (After creating product)
- [ ] Test with test card (4242...)
- [ ] Verify premium status in Firestore
- [ ] Test subscription cancellation
- [ ] Ready for production! 🚀

---

**Need Help?**
- Stripe Docs: https://stripe.com/docs
- Firebase Functions: https://firebase.google.com/docs/functions
- Your guides: `STRIPE_INTEGRATION_GUIDE.md`, `STRIPE_QUICKSTART.md`

