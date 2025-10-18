#!/bin/bash

# Stripe Webhook Configuration Checker
# This script helps you verify your Stripe webhook is properly configured

echo "🔍 Stripe Webhook Configuration Checker"
echo "========================================"
echo ""

WEBHOOK_URL="https://stripewebhook-r7yfhehdra-uc.a.run.app"

echo "Your webhook URL: $WEBHOOK_URL"
echo ""
echo "📋 Required Steps:"
echo ""
echo "STEP 1: Check Stripe Dashboard"
echo "------------------------------"
echo "1. Go to: https://dashboard.stripe.com/test/webhooks"
echo "   (Or live mode: https://dashboard.stripe.com/webhooks)"
echo ""
echo "2. Look for endpoint: $WEBHOOK_URL"
echo ""

read -p "Does this webhook exist in your Stripe Dashboard? (y/n): " webhook_exists

if [ "$webhook_exists" != "y" ]; then
    echo ""
    echo "❌ Webhook not found! Let's create it:"
    echo ""
    echo "1. Click '+ Add endpoint' in Stripe Dashboard"
    echo "2. Endpoint URL: $WEBHOOK_URL"
    echo "3. Description: Firebase webhook for premium subscriptions"
    echo "4. Select these events:"
    echo "   ✅ checkout.session.completed"
    echo "   ✅ customer.subscription.updated"
    echo "   ✅ customer.subscription.deleted"
    echo "5. Click 'Add endpoint'"
    echo ""
    read -p "Press Enter after you've created the webhook..."
fi

echo ""
echo "STEP 2: Get Webhook Signing Secret"
echo "-----------------------------------"
echo "1. In Stripe Dashboard, click on your webhook endpoint"
echo "2. Find 'Signing secret' section"
echo "3. Click 'Reveal' to see the secret"
echo "4. Copy the secret (starts with 'whsec_')"
echo ""
read -p "Paste your webhook secret here: " webhook_secret

if [ -z "$webhook_secret" ]; then
    echo "❌ No secret provided. Exiting."
    exit 1
fi

echo ""
echo "STEP 3: Update .env file"
echo "------------------------"

cd functions

# Check if .env exists
if [ ! -f ".env" ]; then
    echo "⚠️  Creating new .env file"
    touch .env
fi

# Check if webhook secret is already in .env
if grep -q "STRIPE_WEBHOOK_SECRET" .env; then
    echo "Updating existing STRIPE_WEBHOOK_SECRET..."
    # Create temp file and replace the line
    sed "s/STRIPE_WEBHOOK_SECRET=.*/STRIPE_WEBHOOK_SECRET=$webhook_secret/" .env > .env.tmp
    mv .env.tmp .env
else
    echo "Adding STRIPE_WEBHOOK_SECRET..."
    echo "" >> .env
    echo "STRIPE_WEBHOOK_SECRET=$webhook_secret" >> .env
fi

echo "✅ .env file updated"
echo ""

echo "STEP 4: Deploy Updated Function"
echo "--------------------------------"
cd ..
echo "Running: firebase deploy --only functions:stripeWebhook"
echo ""

firebase deploy --only functions:stripeWebhook

echo ""
echo "STEP 5: Test the Webhook"
echo "------------------------"
echo "1. Go to: https://dashboard.stripe.com/webhooks"
echo "2. Click on your webhook endpoint"
echo "3. Click 'Send test webhook'"
echo "4. Select: checkout.session.completed"
echo "5. Click 'Send test webhook'"
echo ""
echo "Expected result: 200 OK"
echo ""
read -p "Did the test succeed? (y/n): " test_success

if [ "$test_success" = "y" ]; then
    echo ""
    echo "🎉 Success! Your webhook is configured correctly!"
    echo ""
    echo "Next: Try making a payment with test card 4242 4242 4242 4242"
    echo "The premium features should activate automatically."
else
    echo ""
    echo "⚠️  Test failed. Let's check the logs:"
    echo ""
    firebase functions:log --only stripeWebhook | head -30
fi

echo ""
echo "========================================"
echo "✅ Configuration complete!"
echo ""
