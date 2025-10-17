# Stripe Integration - Quick Start

## ✅ What's Been Done

1. **Premium Provider** - Manages subscription status
2. **Stripe Service** - Handles payment processing
3. **Purchase Screen** - Beautiful UI for selecting plans
4. **Paywall Implementation** - Locks 7d, 30d, 365d views behind premium
5. **Navigation Flow** - Integrated into app menu and detail screens

## 🚀 Next Steps (In Order)

### 1. Install Dependencies (5 minutes)
```bash
cd /Users/jeyzdfoo/Desktop/code/brownclaw
flutter pub get
```

### 2. Get Stripe Keys (10 minutes)
1. Sign up at https://stripe.com
2. Go to Dashboard → Developers → API Keys
3. Copy Publishable Key (`pk_test_...`)
4. Copy Secret Key (`sk_test_...`)

### 3. Initialize Stripe in App (2 minutes)
Edit `lib/main.dart`, add before Firebase initialization:
```dart
import 'package:flutter_stripe/flutter_stripe.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ADD THIS:
  Stripe.publishableKey = 'pk_test_YOUR_KEY_HERE';
  
  await Firebase.initializeApp(...);
  runApp(const MainApp());
}
```

### 4. Create Stripe Products (15 minutes)
1. Go to https://dashboard.stripe.com/test/products
2. Create 1 product:
   - Monthly Premium: $2.00/month → Copy Price ID

3. Update `lib/screens/premium_purchase_screen.dart`:
```dart
static const String monthlyPriceId = 'price_YOUR_ID_HERE';
```

### 5. Set Up Cloud Functions (30 minutes)
```bash
# Install Firebase CLI
npm install -g firebase-tools
firebase login

# Initialize functions
firebase init functions
# Choose TypeScript, install dependencies

# Copy the code from STRIPE_INTEGRATION_GUIDE.md
# Update Secret Key in functions/src/index.ts

# Deploy
firebase deploy --only functions
```

### 6. Configure Webhooks (10 minutes)
1. Dashboard → Developers → Webhooks
2. Add endpoint: `https://YOUR_PROJECT.cloudfunctions.net/stripeWebhook`
3. Select events: payment_intent.succeeded, subscription.*
4. Copy webhook secret
5. Update in Cloud Functions

### 7. Test! (10 minutes)
```bash
flutter run
```

- Go to Premium Settings
- Click Upgrade to Premium
- Use test card: `4242 4242 4242 4242`
- Verify premium features unlock

## 📝 Test Card Numbers

- Success: `4242 4242 4242 4242`
- Requires Auth: `4000 0025 0000 3155`
- Declined: `4000 0000 0000 9995`

Any future date, any CVC, any ZIP.

## 📚 Full Documentation

See `STRIPE_INTEGRATION_GUIDE.md` for complete details.

## 🆘 Need Help?

- Stripe Docs: https://stripe.com/docs
- Flutter Stripe Package: https://pub.dev/packages/flutter_stripe
- Firebase Functions: https://firebase.google.com/docs/functions

---

**Total Setup Time: ~90 minutes**
