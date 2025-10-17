# Stripe Integration Checklist

## 📋 Configuration TODOs

Complete these steps to activate Stripe payments:

### 1. Flutter App - Stripe Publishable Key
**File:** `lib/main.dart` (line ~24)

```dart
// #todo: STRIPE INTEGRATION - Add Stripe publishable key here
// Uncomment and add your key from https://dashboard.stripe.com/apikeys
import 'package:flutter_stripe/flutter_stripe.dart';
Stripe.publishableKey = 'pk_test_YOUR_PUBLISHABLE_KEY_HERE';
```

**Steps:**
- [ ] Sign up at https://stripe.com
- [ ] Go to Dashboard → Developers → API Keys
- [ ] Copy **Publishable Key** (starts with `pk_test_`)
- [ ] Uncomment the import in `main.dart`
- [ ] Add the key before `Firebase.initializeApp()`

---

### 2. Flutter App - Product Price ID
**File:** `lib/screens/premium_purchase_screen.dart` (line ~21)

```dart
// #todo: STRIPE INTEGRATION - Add your Stripe Price ID here
static const String monthlyPriceId = 'price_XXXXXXXXXXXXX';
```

**Steps:**
- [ ] Go to https://dashboard.stripe.com/test/products
- [ ] Click **+ Add product**
- [ ] Name: "Premium Monthly"
- [ ] Price: $2.00 USD
- [ ] Recurring: Monthly
- [ ] Copy the **Price ID** (starts with `price_`)
- [ ] Replace `price_XXXXXXXXXXXXX` with your actual Price ID

---

### 3. Cloud Functions - Secret Key
**File:** `functions/src/index.ts` (line ~113)

```typescript
// #todo: STRIPE INTEGRATION - Add your Stripe Secret Key here
const stripe = new Stripe('sk_test_YOUR_SECRET_KEY_HERE', {
  apiVersion: '2023-10-16',
});
```

**Steps:**
- [ ] Go to https://dashboard.stripe.com/test/apikeys
- [ ] Copy **Secret Key** (starts with `sk_test_`)
- [ ] ⚠️ NEVER commit this to git
- [ ] Consider using environment variables
- [ ] Replace `sk_test_YOUR_SECRET_KEY_HERE` with your key

---

### 4. Cloud Functions - Webhook Secret
**File:** `functions/src/index.ts` (line ~258)

```typescript
// #todo: STRIPE INTEGRATION - Add your Webhook Secret here
const webhookSecret = 'whsec_YOUR_WEBHOOK_SECRET';
```

**Steps:**
- [ ] Deploy Cloud Functions first: `firebase deploy --only functions`
- [ ] Go to https://dashboard.stripe.com/test/webhooks
- [ ] Click **+ Add endpoint**
- [ ] URL: `https://YOUR_PROJECT.cloudfunctions.net/stripeWebhook`
- [ ] Select events: `payment_intent.succeeded`, `customer.subscription.*`
- [ ] Copy the **Signing secret** (starts with `whsec_`)
- [ ] Replace `whsec_YOUR_WEBHOOK_SECRET` with your secret
- [ ] Redeploy: `firebase deploy --only functions`

---

## ✅ Quick Setup Flow

1. **Get Stripe Keys** (10 min)
   - Publishable Key → `main.dart`
   - Secret Key → Cloud Functions

2. **Create Product** (5 min)
   - $2.00/month product
   - Copy Price ID → `premium_purchase_screen.dart`

3. **Setup Cloud Functions** (30 min)
   - Install Firebase CLI
   - Copy Cloud Function code
   - Add Secret Key
   - Deploy functions

4. **Setup Webhook** (10 min)
   - Get Cloud Function URL
   - Create webhook endpoint
   - Copy webhook secret
   - Update Cloud Functions
   - Redeploy

5. **Test** (5 min)
   - Run app: `flutter run`
   - Try subscription with test card: `4242 4242 4242 4242`
   - Verify in Stripe Dashboard

---

## 🔍 Find All TODOs

Search for `#todo: STRIPE INTEGRATION` in:
- `lib/main.dart`
- `lib/screens/premium_purchase_screen.dart`
- `functions/src/index.ts`
- `STRIPE_INTEGRATION_GUIDE.md`

---

## 📚 Documentation

- **Quick Start**: `STRIPE_QUICKSTART.md`
- **Full Guide**: `STRIPE_INTEGRATION_GUIDE.md`
- **This Checklist**: `STRIPE_TODOS.md`

---

## 🆘 Need Help?

Each TODO comment includes:
- File location
- Step-by-step instructions
- Links to Stripe Dashboard

Follow the guide and check off each item! 🚀
