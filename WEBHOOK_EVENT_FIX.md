# 🎯 Fix: Add checkout.session.completed Event

**Issue Found:** Your webhook is missing the `checkout.session.completed` event!

**Why this matters:** Your web app uses Stripe Checkout, which triggers this event when payment succeeds. Without it, your webhook never gets notified and can't activate premium.

---

## ✅ Quick Fix (2 minutes)

### Step 1: Open Stripe Dashboard

**Test Mode:**
```
https://dashboard.stripe.com/test/webhooks
```

**Live Mode:**
```
https://dashboard.stripe.com/webhooks
```

### Step 2: Find Your Webhook

Look for webhook with URL:
```
https://stripewebhook-r7yfhehdra-uc.a.run.app
```

Click on it.

### Step 3: Add the Missing Event

1. Scroll to **"Events to send"** section
2. Click **"+ Add events"** (or "Select events")
3. In the search box, type: `checkout.session.completed`
4. Check the box next to: ✅ **checkout.session.completed**
5. Click **"Add events"** button to save

### Step 4: Verify Events

Your webhook should now have these events:
- ✅ `checkout.session.completed` ← **NEWLY ADDED**
- ✅ `customer.subscription.updated`
- ✅ `customer.subscription.deleted`

---

## 🧪 Test It Works

### Option A: Test in Stripe Dashboard

1. Stay on your webhook page
2. Click **"Send test webhook"** button
3. Select event: **checkout.session.completed**
4. Click **"Send test webhook"**
5. Expected result: **✅ 200 OK**

### Option B: Real Payment Test

1. Run your Flutter app
2. Navigate to: **Premium Purchase**
3. Click **"Subscribe"**
4. Use test card:
   ```
   Card: 4242 4242 4242 4242
   Expiry: 12/34
   CVC: 123
   ZIP: 12345
   ```
5. Complete payment
6. **Premium should activate automatically!** 🎉

---

## 🔍 What Happens Now

```
User completes payment
    ↓
Stripe Checkout succeeds
    ↓
Stripe sends: checkout.session.completed event  ← NOW CONFIGURED!
    ↓
Your webhook receives it
    ↓
Function updates Firestore: isPremium = true
    ↓
App detects change
    ↓
Premium unlocked! 🎉
```

---

## 📊 Check It Worked

### After test payment:

1. **Check Firestore:**
   - Go to: https://console.firebase.google.com/project/brownclaw/firestore
   - Navigate to: `users/{yourUserId}`
   - Should have: `isPremium: true` ✅

2. **Check Webhook Logs:**
   ```bash
   firebase functions:log | grep -i "checkout.session.completed"
   ```
   Should show: "Success" with 200 status

3. **Check App:**
   - Premium icon (🏆) shows in menu
   - All chart ranges unlocked (3d, 7d, 30d, 365d)
   - No lock icons

---

## 🐛 If It Still Doesn't Work

### Check webhook secret is correct:

```bash
cd functions
cat .env | grep WEBHOOK
```

If empty or wrong, update it:
```bash
# Get secret from Stripe Dashboard > Webhooks > (your endpoint) > Signing secret
nano .env
# Add: STRIPE_WEBHOOK_SECRET=whsec_YOUR_SECRET
```

Then redeploy:
```bash
cd ..
firebase deploy --only functions:stripeWebhook
```

---

## 📝 Summary

**Problem:** Missing `checkout.session.completed` event  
**Solution:** Add event in Stripe Dashboard  
**Result:** Payments now automatically activate premium!

**No code changes needed** - just configuration in Stripe Dashboard.

---

## 🎉 You're Done!

After adding the event, try a test payment and premium should work automatically!

Need help? Check the logs:
```bash
firebase functions:log --only stripeWebhook
```
