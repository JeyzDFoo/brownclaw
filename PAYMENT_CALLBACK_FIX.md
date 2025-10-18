# 🚨 Payment Callback Issue - Diagnosis & Fix

## 🔍 Issues Found

I've identified **TWO critical issues** preventing premium activation after successful Stripe payments:

### Issue #1: Missing Webhook Secret ❌
**File:** `functions/.env`
```
STRIPE_WEBHOOK_SECRET=whsec_YOUR_WEBHOOK_SECRET_HERE
```
This is a placeholder! Stripe can't verify webhook events without the real secret.

### Issue #2: Webhook Event Not Configured (Likely) ⚠️
Your webhook needs the `checkout.session.completed` event to receive payment notifications from Stripe Checkout.

### What's Happening:
```
User completes payment ✅
    ↓
Stripe processes payment successfully ✅
    ↓
Stripe sends webhook to your function ✅
    ↓
Function receives webhook ✅
    ↓
Function tries to verify signature with placeholder secret ❌
    ↓
Verification fails → No premium activation ❌
```

**Evidence from logs:**
```
stripe._error.SignatureVerificationError: Unable to extract timestamp and signatures from header
```

---

## ✅ Solution (5 minutes)

### Step 1: Get Your Webhook Secret from Stripe

1. Go to Stripe Dashboard:
   - **Test Mode:** https://dashboard.stripe.com/test/webhooks
   - **Live Mode:** https://dashboard.stripe.com/webhooks

2. Find your webhook endpoint:
   ```
   https://stripewebhook-r7yfhehdra-uc.a.run.app
   ```

3. Click on it

4. Click **"Reveal"** next to "Signing secret"

5. Copy the secret (starts with `whsec_...`)

### Step 2: Update Environment Variable

1. Open `functions/.env` file

2. Replace the placeholder:
   ```bash
   # BEFORE:
   STRIPE_WEBHOOK_SECRET=whsec_YOUR_WEBHOOK_SECRET_HERE
   
   # AFTER:
   STRIPE_WEBHOOK_SECRET=whsec_1234YourActualSecretHere5678
   ```

3. Save the file

### Step 3: Verify Webhook Events

While in Stripe Dashboard (on your webhook page):

1. Scroll to **"Events to send"** section

2. Verify these events are checked:
   - ✅ `checkout.session.completed` ← **CRITICAL for web payments**
   - ✅ `customer.subscription.updated`
   - ✅ `customer.subscription.deleted`
   - ✅ `payment_intent.succeeded` ← For one-time payments

3. If `checkout.session.completed` is missing:
   - Click **"+ Add events"**
   - Search for: `checkout.session.completed`
   - Check the box
   - Click **"Add events"**

### Step 4: Redeploy the Function

```bash
cd /Users/jeyzdfoo/Desktop/code/brownclaw
firebase deploy --only functions:stripeWebhook
```

This will upload the new environment variable to Google Cloud.

---

## 🧪 Test the Fix

### Test 1: Send Test Webhook from Stripe

1. In Stripe Dashboard, on your webhook page
2. Click **"Send test webhook"**
3. Select: **checkout.session.completed**
4. Click **"Send test webhook"**
5. Expected result: **✅ Webhook received (200)**

### Test 2: Real Payment Test

1. Run your app
2. Navigate to premium purchase
3. Use test card:
   ```
   Card: 4242 4242 4242 4242
   Expiry: 12/34
   CVC: 123
   ```
4. Complete payment
5. **Premium should activate within 2-3 seconds** ✨

---

## 🔍 Verify It Worked

### Check Webhook Logs:
```bash
firebase functions:log --only stripeWebhook 2>&1 | head -30
```

**Good signs:**
- No more `SignatureVerificationError`
- You see: `"Success"` responses

**If you see errors:**
- Check the webhook secret is correct
- Make sure you redeployed after changing `.env`

### Check Firestore:
1. Go to Firebase Console → Firestore
2. Open `users` collection
3. Find your user document
4. Should show:
   ```
   isPremium: true
   subscriptionStatus: "active"
   subscriptionId: "sub_..."
   stripeCustomerId: "cus_..."
   ```

---

## 🎯 Quick Checklist

- [ ] Get real webhook secret from Stripe Dashboard
- [ ] Update `functions/.env` with real secret
- [ ] Verify `checkout.session.completed` event is configured
- [ ] Redeploy: `firebase deploy --only functions:stripeWebhook`
- [ ] Test with test webhook from Stripe
- [ ] Test with real payment
- [ ] Verify premium activates in app

---

## 🆘 Still Not Working?

### Debug Steps:

1. **Check environment variable deployed correctly:**
   ```bash
   # View deployed config (won't show secret value for security)
   firebase functions:config:get
   ```

2. **Check webhook URL is correct:**
   - In Stripe: `https://stripewebhook-r7yfhehdra-uc.a.run.app`
   - Should match your Cloud Function URL

3. **Check webhook is receiving events:**
   - Stripe Dashboard → Webhooks → Your endpoint
   - Check "Event logs" tab
   - Should show 200 responses

4. **Check function logs for errors:**
   ```bash
   firebase functions:log --only stripeWebhook 2>&1 | head -50
   ```

5. **Verify user has auth context:**
   - The metadata in checkout session should include `userId`
   - Check this in Stripe Dashboard under successful payment

---

## 📝 How This Works

### Payment Flow:
1. User clicks "Subscribe" in app
2. App calls `createCheckoutSession` Cloud Function
3. Function creates Stripe Checkout session with:
   - User's email
   - Price ID
   - Metadata: `userId`
4. User completes payment on Stripe Checkout page
5. Stripe sends `checkout.session.completed` event to webhook
6. Webhook verifies signature with secret
7. Webhook extracts `userId` from metadata
8. Webhook updates Firestore: `isPremium = true`
9. App detects Firestore change
10. Premium unlocked! 🎉

---

## 🔐 Security Note

**NEVER commit `.env` file to git!**

Your `.env` file contains sensitive secrets. It's already in `.gitignore`, but double-check:

```bash
cat .gitignore | grep .env
```

Should show:
```
.env
```

---

## 🎉 Expected Result

After fixing both issues:
- Webhook signature verification works ✅
- Checkout completion events are received ✅
- Premium status updates immediately ✅
- No more manual activation needed ✅
