#!/bin/bash

echo "🔧 Stripe Webhook Quick Fix"
echo "============================"
echo ""
echo "Your webhook URL is: https://stripewebhook-r7yfhehdra-uc.a.run.app"
echo ""
echo "📋 Steps to Fix:"
echo ""
echo "1️⃣  Go to your Stripe Dashboard:"
echo "   Test mode: https://dashboard.stripe.com/test/webhooks"
echo "   Live mode: https://dashboard.stripe.com/webhooks"
echo ""
echo "2️⃣  Check if webhook exists with URL above"
echo "   - If NO: Click '+ Add endpoint' and create it"
echo "   - If YES: Click on it to view details"
echo ""
echo "3️⃣  CRITICAL: Verify these events are selected:"
echo "   ✅ checkout.session.completed  <-- REQUIRED for web payments!"
echo "   ✅ customer.subscription.updated"
echo "   ✅ customer.subscription.deleted"
echo ""
echo "   If missing, click 'Add events' and select them"
echo ""
echo "4️⃣  Get the Signing Secret:"
echo "   - Click 'Signing secret' > 'Reveal'"
echo "   - Copy it (starts with whsec_)"
echo ""
read -p "Paste your webhook signing secret here: " webhook_secret

if [ -z "$webhook_secret" ]; then
    echo ""
    echo "⚠️  No secret provided. Please run this script again with your webhook secret."
    echo ""
    echo "To get your secret:"
    echo "1. Go to Stripe Dashboard > Webhooks"
    echo "2. Click your webhook endpoint"
    echo "3. Find 'Signing secret' and click 'Reveal'"
    echo "4. Copy the secret (whsec_...)"
    exit 1
fi

echo ""
echo "5️⃣  Updating .env file..."

cd functions

# Update or add webhook secret
if grep -q "STRIPE_WEBHOOK_SECRET" .env; then
    # Mac-compatible sed command
    sed -i '' "s|STRIPE_WEBHOOK_SECRET=.*|STRIPE_WEBHOOK_SECRET=$webhook_secret|" .env
    echo "✅ Updated existing STRIPE_WEBHOOK_SECRET"
else
    echo "" >> .env
    echo "STRIPE_WEBHOOK_SECRET=$webhook_secret" >> .env
    echo "✅ Added STRIPE_WEBHOOK_SECRET"
fi

cd ..

echo ""
echo "6️⃣  Deploying updated webhook function..."
firebase deploy --only functions:stripeWebhook

echo ""
echo "7️⃣  Testing webhook..."
echo ""
echo "Go to Stripe Dashboard and:"
echo "1. Click your webhook endpoint"
echo "2. Click 'Send test webhook'"
echo "3. Select: checkout.session.completed"
echo "4. Click 'Send test webhook'"
echo ""
echo "Expected: Status 200 ✅"
echo ""
echo "============================"
echo "🎉 Webhook configuration complete!"
echo ""
echo "Next: Try a test payment to verify everything works"
echo "Test card: 4242 4242 4242 4242"
echo ""
