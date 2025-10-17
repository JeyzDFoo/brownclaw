# Premium Pricing Update

## 💰 Simplified Pricing

Changed from multiple tiers to a single, affordable plan:

### Before:
- Monthly: $4.99/month
- Yearly: $39.99/year
- Lifetime: $99.99 one-time

### After:
- **Monthly: $2.00/month** (only option)

## ✅ Changes Made

1. **Updated `premium_purchase_screen.dart`**
   - Removed yearly and lifetime options
   - Changed monthly price to $2.00
   - Updated badge to "BEST VALUE"
   - Simplified heading to "Simple, Affordable Pricing"

2. **Updated Documentation**
   - `STRIPE_QUICKSTART.md` - Updated to create only 1 product
   - `STRIPE_INTEGRATION_GUIDE.md` - Simplified product creation steps
   - `.env.example` - Removed unused price ID variables

## 📋 Setup Steps (Updated)

1. **Create Stripe Product**
   - Go to: https://dashboard.stripe.com/test/products
   - Click "Add product"
   - Name: "Premium Monthly"
   - Price: $2.00 USD recurring monthly
   - Copy the Price ID (starts with `price_...`)

2. **Update Code**
   - Edit `lib/screens/premium_purchase_screen.dart`
   - Replace line 18:
     ```dart
     static const String monthlyPriceId = 'price_YOUR_ACTUAL_ID_HERE';
     ```

3. **Test**
   - Use test card: `4242 4242 4242 4242`
   - Verify $2.00 charge in Stripe dashboard

## 🎯 User Experience

Premium users now see:
- Single pricing option: $2.00/month
- "BEST VALUE" badge
- Clear messaging: "Cancel anytime. No questions asked."
- All premium features unlocked (7d, 30d, 365d chart views)

## 📊 What Stays Free

- 3-day historical chart view
- All other app features (favorites, logbook, etc.)

---

**Ready to integrate!** Follow the STRIPE_QUICKSTART.md guide.
