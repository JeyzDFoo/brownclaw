# Payment Not Activating Premium - Solutions

**Date:** October 18, 2025  
**Issue:** Stripe payment succeeded but premium features not activating  
**Status:** 🔧 Ready to Fix

---

## 🎯 Quick Summary

Your Stripe payment **succeeded** ✅, but the webhook that activates premium in Firebase either:
- Isn't receiving events from Stripe, OR
- Is configured but failing to process them, OR
- Is missing the webhook signing secret

---

## ✅ **FASTEST FIX: Manual Activation (2 minutes)**

Since your payment already went through, activate premium manually:

### Steps:

1. **Open Firebase Console:**
   ```
   https://console.firebase.google.com/project/brownclaw/firestore
   ```

2. **Navigate to `users` collection**

3. **Find your user document** (by email or user ID)

4. **Edit the document and set:**
   ```
   isPremium: true (boolean)
   subscriptionStatus: active (string)
   ```

5. **Save** and **refresh your app** - Premium should work now! 🎉

---

## 🔧 **PERMANENT FIX: Configure Webhook (10 minutes)**

To make future payments work automatically, fix the webhook:

### Option A: Use the Fix Script

Run this in your terminal:
```bash
cd /Users/jeyzdfoo/Desktop/code/brownclaw
./fix_stripe_webhook.sh
```

The script will guide you through:
1. Checking if webhook exists in Stripe
2. Getting the webhook signing secret
3. Updating your `.env` file
4. Deploying the updated function
5. Testing the webhook

### Option B: Manual Configuration

#### Step 1: Check Stripe Webhook

1. Go to: https://dashboard.stripe.com/webhooks (or `/test/webhooks` for test mode)

2. Look for webhook URL:
   ```
   https://stripewebhook-r7yfhehdra-uc.a.run.app
   ```

3. If it doesn't exist, create it:
   - Click **"+ Add endpoint"**
   - URL: `https://stripewebhook-r7yfhehdra-uc.a.run.app`
   - Events to send:
     - ✅ `checkout.session.completed`
     - ✅ `customer.subscription.updated`
     - ✅ `customer.subscription.deleted`
   - Click **"Add endpoint"**

4. Click on the webhook and **reveal the signing secret**
   - Starts with `whsec_...`

#### Step 2: Update Environment Variables

1. Edit `functions/.env`:
   ```bash
   cd /Users/jeyzdfoo/Desktop/code/brownclaw/functions
   nano .env
   ```

2. Add or update:
   ```bash
   STRIPE_WEBHOOK_SECRET=whsec_YOUR_ACTUAL_SECRET_HERE
   ```

3. Save and exit (`Ctrl+X`, then `Y`, then `Enter`)

#### Step 3: Redeploy Function

```bash
cd /Users/jeyzdfoo/Desktop/code/brownclaw
firebase deploy --only functions:stripeWebhook
```

#### Step 4: Test Webhook

1. Go to Stripe Dashboard → Webhooks
2. Click your webhook endpoint
3. Click **"Send test webhook"**
4. Select: `checkout.session.completed`
5. Click **"Send test webhook"**
6. Should see: **200 OK** ✅

---

## 🔍 **Verify Everything is Working**

### Check 1: Stripe Payment
- Go to: https://dashboard.stripe.com/payments
- Find your payment
- Status: **Succeeded** ✅

### Check 2: Stripe Subscription
- Go to: https://dashboard.stripe.com/subscriptions
- Find your subscription
- Status: **Active** ✅

### Check 3: Firebase User Document
- Go to: https://console.firebase.google.com/project/brownclaw/firestore
- Find your user in `users` collection
- Should have:
  ```
  isPremium: true
  stripeCustomerId: cus_XXXXX
  subscriptionId: sub_XXXXX
  subscriptionStatus: active
  ```

### Check 4: App Features
- Open your app
- Premium icon should show in menu (🏆 gold icon)
- Chart views should have all options unlocked (3d, 7d, 30d, 365d)
- No lock icons on premium features

---

## 📊 **Helpful Scripts**

I've created 3 scripts to help you:

### 1. Check Premium Status
```bash
./check_premium_status.sh
```
Guides you through checking if premium is activated.

### 2. Fix Webhook Configuration
```bash
./fix_stripe_webhook.sh
```
Interactive script to configure your webhook properly.

### 3. Manual Premium Activation
```bash
./manual_activate_premium.sh YOUR_EMAIL
```
Shows steps to manually activate premium.

---

## 🐛 **Common Issues & Solutions**

### Issue: "Payment succeeded but isPremium is false"
**Cause:** Webhook not triggering or failing  
**Fix:** 
1. Check webhook is configured with `checkout.session.completed` event
2. Check webhook signing secret is correct in `.env`
3. Redeploy webhook function
4. Or manually activate (see above)

### Issue: "Invalid signature" in webhook logs
**Cause:** Wrong webhook secret  
**Fix:**
1. Get correct secret from Stripe Dashboard
2. Update `functions/.env`
3. Redeploy: `firebase deploy --only functions:stripeWebhook`

### Issue: "Webhook secret not configured"
**Cause:** `.env` file missing webhook secret  
**Fix:** Add `STRIPE_WEBHOOK_SECRET=whsec_...` to `functions/.env`

### Issue: Webhook returns 200 but user not premium
**Cause:** User ID mismatch or Firestore permissions  
**Fix:**
1. Check checkout session includes correct userId in metadata
2. Check function logs: `firebase functions:log`
3. Verify user document exists in Firestore

---

## 🔬 **Debug Commands**

### View webhook logs:
```bash
firebase functions:log --only stripeWebhook | head -50
```

### Check deployed functions:
```bash
firebase functions:list
```

### Check environment variables:
```bash
cat functions/.env
```

### Test payment with Stripe CLI (advanced):
```bash
stripe listen --forward-to https://stripewebhook-r7yfhehdra-uc.a.run.app
stripe trigger checkout.session.completed
```

---

## 📞 **Need More Help?**

### Check these resources:

1. **Stripe Dashboard:**
   - Payments: https://dashboard.stripe.com/payments
   - Webhooks: https://dashboard.stripe.com/webhooks
   - Logs: https://dashboard.stripe.com/logs

2. **Firebase Console:**
   - Firestore: https://console.firebase.google.com/project/brownclaw/firestore
   - Functions: https://console.firebase.google.com/project/brownclaw/functions
   - Logs: https://console.firebase.google.com/project/brownclaw/logs

3. **Documentation:**
   - See: `PAYMENT_DEBUG_GUIDE.md`
   - See: `STRIPE_SETUP_COMPLETE.md`
   - See: `STRIPE_INTEGRATION_GUIDE.md`

---

## ✅ **Action Plan**

### Immediate (Now):
1. ✅ Manually activate premium in Firebase Console (2 min)
2. ✅ Test app to confirm premium works

### Short-term (Today):
1. ✅ Run `./fix_stripe_webhook.sh` to configure webhook
2. ✅ Test webhook in Stripe Dashboard
3. ✅ Try a test payment to verify automation works

### Long-term:
1. ✅ Monitor webhook logs for any errors
2. ✅ Set up email notifications for failed webhooks (optional)
3. ✅ Add retry logic for failed webhook processing (optional)

---

## 🎉 Success!

Once fixed, your payment flow will work like this:

```
User clicks "Subscribe"
    ↓
Stripe Checkout opens
    ↓
User enters payment details
    ↓
Payment succeeds
    ↓
Stripe sends webhook: checkout.session.completed
    ↓
Your function receives webhook
    ↓
Function updates Firestore: isPremium = true
    ↓
App detects change via PremiumProvider
    ↓
Premium features unlock automatically! 🎉
```

---

**Created:** October 18, 2025  
**Last Updated:** October 18, 2025
