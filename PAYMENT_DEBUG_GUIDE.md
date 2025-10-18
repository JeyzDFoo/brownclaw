# Stripe Payment Not Activating Premium - Debug Guide

**Date:** October 18, 2025  
**Issue:** Payment succeeded but premium features not activating

---

## 🔍 Root Causes Identified

Based on the logs and code analysis, there are 3 potential issues:

### 1. Webhook Not Receiving Events
The webhook endpoint exists but may not be properly configured in Stripe Dashboard.

### 2. Missing Webhook Events
The webhook needs `checkout.session.completed` event (not just subscription events).

### 3. Environment Variable Missing
`STRIPE_WEBHOOK_SECRET` may not be set in Firebase Functions environment.

---

## ✅ Step-by-Step Fix

### Step 1: Verify Webhook Configuration in Stripe

1. **Go to Stripe Dashboard → Webhooks:**
   - https://dashboard.stripe.com/webhooks
   
2. **Check if webhook exists:**
   - URL: `https://stripewebhook-r7yfhehdra-uc.a.run.app`
   
3. **If webhook exists, verify events:**
   - Must include: `checkout.session.completed`
   - Optional: `customer.subscription.updated`, `customer.subscription.deleted`
   
4. **If webhook doesn't exist, create it:**
   ```
   Click: "+ Add endpoint"
   Endpoint URL: https://stripewebhook-r7yfhehdra-uc.a.run.app
   Events to send:
   ✅ checkout.session.completed
   ✅ customer.subscription.updated
   ✅ customer.subscription.deleted
   ```

5. **Copy the Signing Secret:**
   - It starts with `whsec_...`
   - You'll need this for Step 2

---

### Step 2: Set Webhook Secret in Firebase

Run this command to set the webhook secret:

```bash
cd /Users/jeyzdfoo/Desktop/code/brownclaw/functions
```

Create or update `.env` file:

```bash
cat > .env << 'EOF'
STRIPE_SECRET_KEY=sk_live_51SJ0MEAdlcDQOrDhK...YOUR_SECRET_KEY
STRIPE_WEBHOOK_SECRET=whsec_...YOUR_WEBHOOK_SECRET
EOF
```

Then deploy the function:

```bash
cd /Users/jeyzdfoo/Desktop/code/brownclaw
firebase deploy --only functions:stripeWebhook
```

---

### Step 3: Test the Webhook

#### Option A: Test from Stripe Dashboard

1. Go to: https://dashboard.stripe.com/webhooks
2. Click your webhook endpoint
3. Click "Send test webhook"
4. Select event: `checkout.session.completed`
5. Click "Send test webhook"
6. Check if it succeeds

#### Option B: Make a Test Payment

1. Run your Flutter app
2. Go to Premium Purchase screen
3. Use test card: `4242 4242 4242 4242`
4. Complete payment
5. Check Firebase logs:
   ```bash
   firebase functions:log --only stripeWebhook
   ```

---

## 🔧 Manual Fix (If Webhook Still Not Working)

If the webhook still isn't working, you can manually activate premium:

### Option 1: Using Firebase Console

1. Go to: https://console.firebase.google.com/project/brownclaw/firestore
2. Navigate to: `users` collection
3. Find your user document (by email or user ID)
4. Add/Update field:
   ```
   isPremium: true
   ```
5. Refresh your app

### Option 2: Using Cloud Function

Run this to manually check and update your premium status:

```bash
# First, get your User ID from Firebase Auth
# Then call getSubscriptionStatus function
```

---

## 📊 Check Current Status

### 1. Check Stripe Dashboard
- **Recent Payments:** https://dashboard.stripe.com/payments
  - Look for your payment - is status "succeeded"?
  
- **Subscriptions:** https://dashboard.stripe.com/subscriptions
  - Is your subscription "active"?
  
- **Customers:** https://dashboard.stripe.com/customers
  - Find your customer - is subscription listed?

### 2. Check Firebase Console
- **Firestore:** https://console.firebase.google.com/project/brownclaw/firestore
  - Check `users/{yourUserId}` document
  - Should have:
    ```
    isPremium: true
    stripeCustomerId: "cus_..."
    subscriptionId: "sub_..."
    subscriptionStatus: "active"
    ```

### 3. Check Function Logs
```bash
firebase functions:log --only stripeWebhook | head -100
```

Look for:
- ✅ Success: "Success" (status 200)
- ❌ Error: "Invalid signature", "Webhook secret not configured"

---

## 🎯 Expected Firestore Structure

After successful payment, your user document should look like:

```json
{
  "email": "your@email.com",
  "isPremium": true,
  "stripeCustomerId": "cus_XXXXX",
  "subscriptionId": "sub_XXXXX",
  "subscriptionStatus": "active"
}
```

---

## 🔍 Debugging Commands

### Check deployed functions:
```bash
firebase functions:list
```

### View recent logs:
```bash
firebase functions:log
```

### Check environment variables:
```bash
cd functions
cat .env
```

### Redeploy webhook function:
```bash
firebase deploy --only functions:stripeWebhook
```

---

## 💡 Common Issues & Solutions

### Issue: "Webhook secret not configured"
**Solution:** Set `STRIPE_WEBHOOK_SECRET` in `functions/.env` and redeploy

### Issue: "Invalid signature"
**Solution:** 
1. Get correct webhook secret from Stripe Dashboard
2. Update `functions/.env`
3. Redeploy function

### Issue: "No Stripe signature found"
**Solution:** Webhook URL in Stripe must exactly match the deployed function URL

### Issue: Payment succeeded but webhook not triggered
**Solution:** 
1. Check webhook events include `checkout.session.completed`
2. Test webhook in Stripe Dashboard
3. Check function logs for errors

### Issue: Webhook succeeds but isPremium still false
**Solution:** 
1. Check userId in checkout session metadata matches Firebase user
2. Verify user document exists in Firestore
3. Check subscription status in Stripe

---

## 📞 Quick Fix Script

Save this as `fix_premium.sh` and run it:

```bash
#!/bin/bash

echo "🔍 Checking Stripe integration..."

# Check if functions directory exists
if [ ! -d "functions" ]; then
  echo "❌ Functions directory not found"
  exit 1
fi

# Check if .env exists
if [ ! -f "functions/.env" ]; then
  echo "⚠️  No .env file found in functions/"
  echo "Creating .env file..."
  read -p "Enter your STRIPE_SECRET_KEY: " secret_key
  read -p "Enter your STRIPE_WEBHOOK_SECRET: " webhook_secret
  
  cat > functions/.env << EOF
STRIPE_SECRET_KEY=$secret_key
STRIPE_WEBHOOK_SECRET=$webhook_secret
EOF
  echo "✅ .env file created"
fi

# Deploy webhook function
echo "🚀 Deploying stripeWebhook function..."
firebase deploy --only functions:stripeWebhook

echo "✅ Done! Test your payment flow now."
echo ""
echo "Next steps:"
echo "1. Go to https://dashboard.stripe.com/webhooks"
echo "2. Verify webhook URL: https://stripewebhook-r7yfhehdra-uc.a.run.app"
echo "3. Verify events include: checkout.session.completed"
echo "4. Test payment with card: 4242 4242 4242 4242"
```

---

## 🎉 Success Checklist

After fixing, you should see:

- ✅ Stripe payment succeeds
- ✅ Webhook logs show "Success" (200 status)
- ✅ Firestore user document has `isPremium: true`
- ✅ App shows premium icon in menu
- ✅ All chart ranges (3d, 7d, 30d, 365d) are unlocked
- ✅ No lock icons on premium features

---

## 📝 Notes

- Webhook secret is different from API secret key
- Get webhook secret from Stripe Dashboard → Webhooks → (your endpoint) → Signing secret
- Test mode and live mode have different webhook secrets
- Webhook must use POST method
- Function must be publicly accessible (no authentication required for webhooks)
