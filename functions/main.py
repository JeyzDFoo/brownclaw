# Cloud Functions for Firebase - Stripe Integration
# Deploy with `firebase deploy --only functions`

from firebase_functions import https_fn, options
from firebase_admin import initialize_app, firestore
import stripe
import json
import os
from typing import Any
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Initialize Firebase Admin
initialize_app()

# Get Stripe keys from environment variables
STRIPE_SECRET_KEY = os.getenv('STRIPE_SECRET_KEY')
if not STRIPE_SECRET_KEY:
    raise ValueError("STRIPE_SECRET_KEY not found in environment variables")

stripe.api_key = STRIPE_SECRET_KEY

# Set CORS options for callable functions
cors_options = options.CorsOptions(
    cors_origins="*",
    cors_methods=["get", "post"],
)


@https_fn.on_call(cors=cors_options)
def createCheckoutSession(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    Create a Stripe Checkout session for web payments.
    
    Expected data:
    - priceId: Stripe Price ID
    - userId: Firebase User ID
    - email: User email
    - successUrl: URL to redirect after successful payment
    - cancelUrl: URL to redirect if user cancels
    """
    # Verify authentication
    if not req.auth:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.UNAUTHENTICATED,
            message="User must be authenticated"
        )
    
    price_id = req.data.get('priceId')
    user_id = req.data.get('userId')
    email = req.data.get('email')
    success_url = req.data.get('successUrl')
    cancel_url = req.data.get('cancelUrl')
    
    if not all([price_id, user_id, email, success_url, cancel_url]):
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="Missing required fields"
        )
    
    try:
        db = firestore.client()
        user_ref = db.collection('users').document(user_id)
        user_doc = user_ref.get()
        user_data = user_doc.to_dict() if user_doc.exists else {}
        
        # Get or create Stripe customer
        customer_id = user_data.get('stripeCustomerId')
        
        if customer_id:
            try:
                customer = stripe.Customer.retrieve(customer_id)
            except stripe.error.StripeError:
                customer = None
        else:
            customer = None
            
        if not customer:
            customer = stripe.Customer.create(
                email=email,
                metadata={'firebaseUserId': user_id}
            )
            user_ref.set({
                'stripeCustomerId': customer.id
            }, merge=True)
        
        # Create Stripe Checkout Session
        checkout_session = stripe.checkout.Session.create(
            customer=customer.id,
            line_items=[{
                'price': price_id,
                'quantity': 1,
            }],
            mode='subscription',
            success_url=success_url + '?session_id={CHECKOUT_SESSION_ID}',
            cancel_url=cancel_url,
            metadata={
                'userId': user_id,
            },
        )
        
        return {
            'url': checkout_session.url,
            'sessionId': checkout_session.id
        }
        
    except stripe.error.StripeError as e:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message=f"Stripe error: {str(e)}"
        )
    except Exception as e:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message=f"Error creating checkout session: {str(e)}"
        )


@https_fn.on_call(cors=cors_options)
def createSubscription(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    Create a Stripe subscription for a user.
    
    Expected data:
    - priceId: Stripe Price ID
    - userId: Firebase User ID
    - email: User email
    """
    # Verify authentication
    if not req.auth:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.UNAUTHENTICATED,
            message="User must be authenticated"
        )
    
    price_id = req.data.get('priceId')
    user_id = req.data.get('userId')
    email = req.data.get('email')
    
    if not all([price_id, user_id, email]):
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="Missing required fields: priceId, userId, email"
        )
    
    try:
        db = firestore.client()
        user_ref = db.collection('users').document(user_id)
        user_doc = user_ref.get()
        user_data = user_doc.to_dict() if user_doc.exists else {}
        
        # Get or create Stripe customer
        customer_id = user_data.get('stripeCustomerId')
        
        if customer_id:
            try:
                customer = stripe.Customer.retrieve(customer_id)
            except stripe.error.StripeError:
                customer = None
        else:
            customer = None
            
        if not customer:
            customer = stripe.Customer.create(
                email=email,
                metadata={'firebaseUserId': user_id}
            )
            user_ref.set({
                'stripeCustomerId': customer.id
            }, merge=True)
        
        # Create subscription
        subscription = stripe.Subscription.create(
            customer=customer.id,
            items=[{'price': price_id}],
            payment_behavior='default_incomplete',
            payment_settings={'save_default_payment_method': 'on_subscription'},
            expand=['latest_invoice.payment_intent']
        )
        
        # Update user premium status
        user_ref.set({
            'isPremium': True,
            'subscriptionId': subscription.id,
            'subscriptionStatus': subscription.status
        }, merge=True)
        
        # Get payment intent client secret
        invoice = subscription.latest_invoice
        payment_intent = invoice['payment_intent']
        
        return {
            'clientSecret': payment_intent['client_secret'],
            'customerId': customer.id,
            'subscriptionId': subscription.id
        }
        
    except stripe.error.StripeError as e:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message=f"Stripe error: {str(e)}"
        )
    except Exception as e:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message=f"Error creating subscription: {str(e)}"
        )


@https_fn.on_call(cors=cors_options)
def createPaymentIntent(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    Create a one-time payment intent for lifetime premium.
    
    Expected data:
    - amount: Amount in cents
    - currency: Currency code (e.g., 'usd')
    - userId: Firebase User ID
    - email: User email
    """
    if not req.auth:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.UNAUTHENTICATED,
            message="User must be authenticated"
        )
    
    amount = req.data.get('amount')
    currency = req.data.get('currency', 'usd')
    user_id = req.data.get('userId')
    email = req.data.get('email')
    
    if not all([amount, user_id, email]):
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="Missing required fields: amount, userId, email"
        )
    
    try:
        db = firestore.client()
        user_ref = db.collection('users').document(user_id)
        user_doc = user_ref.get()
        user_data = user_doc.to_dict() if user_doc.exists else {}
        
        # Get or create Stripe customer
        customer_id = user_data.get('stripeCustomerId')
        
        if customer_id:
            try:
                customer = stripe.Customer.retrieve(customer_id)
            except stripe.error.StripeError:
                customer = None
        else:
            customer = None
            
        if not customer:
            customer = stripe.Customer.create(
                email=email,
                metadata={'firebaseUserId': user_id}
            )
            user_ref.set({
                'stripeCustomerId': customer.id
            }, merge=True)
        
        # Create payment intent
        payment_intent = stripe.PaymentIntent.create(
            amount=amount,
            currency=currency,
            customer=customer.id,
            metadata={
                'userId': user_id,
                'type': 'lifetime_premium'
            },
            automatic_payment_methods={'enabled': True}
        )
        
        return {
            'clientSecret': payment_intent.client_secret,
            'customerId': customer.id
        }
        
    except stripe.error.StripeError as e:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message=f"Stripe error: {str(e)}"
        )
    except Exception as e:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message=f"Error creating payment intent: {str(e)}"
        )


@https_fn.on_call(cors=cors_options)
def cancelSubscription(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    Cancel a user's subscription.
    
    Expected data:
    - userId: Firebase User ID
    """
    if not req.auth:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.UNAUTHENTICATED,
            message="User must be authenticated"
        )
    
    user_id = req.data.get('userId')
    
    if not user_id:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="Missing required field: userId"
        )
    
    try:
        db = firestore.client()
        user_ref = db.collection('users').document(user_id)
        user_doc = user_ref.get()
        
        if not user_doc.exists:
            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.NOT_FOUND,
                message="User not found"
            )
        
        user_data = user_doc.to_dict()
        subscription_id = user_data.get('subscriptionId')
        
        if not subscription_id:
            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.NOT_FOUND,
                message="No active subscription found"
            )
        
        # Cancel subscription at period end
        subscription = stripe.Subscription.modify(
            subscription_id,
            cancel_at_period_end=True
        )
        
        # Update user status
        user_ref.set({
            'subscriptionStatus': subscription.status
        }, merge=True)
        
        return {
            'success': True,
            'message': 'Subscription will be cancelled at period end'
        }
        
    except stripe.error.StripeError as e:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message=f"Stripe error: {str(e)}"
        )
    except Exception as e:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message=f"Error cancelling subscription: {str(e)}"
        )


@https_fn.on_call(cors=cors_options)
def getSubscriptionStatus(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    Get user's subscription status.
    
    Expected data:
    - userId: Firebase User ID
    """
    if not req.auth:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.UNAUTHENTICATED,
            message="User must be authenticated"
        )
    
    user_id = req.data.get('userId')
    
    if not user_id:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="Missing required field: userId"
        )
    
    try:
        db = firestore.client()
        user_ref = db.collection('users').document(user_id)
        user_doc = user_ref.get()
        
        if not user_doc.exists:
            return {
                'isPremium': False,
                'subscriptionStatus': None
            }
        
        user_data = user_doc.to_dict()
        subscription_id = user_data.get('subscriptionId')
        
        if subscription_id:
            try:
                subscription = stripe.Subscription.retrieve(subscription_id)
                
                # Update Firestore with latest status
                user_ref.set({
                    'subscriptionStatus': subscription.status,
                    'isPremium': subscription.status in ['active', 'trialing']
                }, merge=True)
                
                return {
                    'isPremium': subscription.status in ['active', 'trialing'],
                    'subscriptionStatus': subscription.status,
                    'currentPeriodEnd': subscription.current_period_end
                }
            except stripe.error.StripeError:
                pass
        
        return {
            'isPremium': user_data.get('isPremium', False),
            'subscriptionStatus': user_data.get('subscriptionStatus')
        }
        
    except Exception as e:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message=f"Error getting subscription status: {str(e)}"
        )


@https_fn.on_request(cors=options.CorsOptions(cors_origins="*", cors_methods=["post"]))
def stripeWebhook(req: https_fn.Request) -> https_fn.Response:
    """
    Handle Stripe webhook events.
    
    This endpoint receives events from Stripe when subscriptions are updated,
    payments succeed/fail, etc.
    """
    # Only accept POST requests
    if req.method != 'POST':
        return https_fn.Response("Method not allowed. Use POST.", status=405)
    
    payload = req.get_data()
    sig_header = req.headers.get('Stripe-Signature')
    
    # Get webhook secret from environment variables
    webhook_secret = os.getenv('STRIPE_WEBHOOK_SECRET')
    if not webhook_secret:
        return https_fn.Response("Webhook secret not configured", status=500)
    
    # If no signature header, we can't verify (might be a test)
    if not sig_header:
        return https_fn.Response("No Stripe signature found", status=400)
    
    try:
        event = stripe.Webhook.construct_event(
            payload, sig_header, webhook_secret
        )
    except ValueError as e:
        return https_fn.Response(f"Invalid payload: {str(e)}", status=400)
    except Exception as e:
        # Catch signature verification errors
        return https_fn.Response(f"Invalid signature: {str(e)}", status=400)
    
    # Handle the event
    event_type = event['type']
    data = event['data']['object']
    
    db = firestore.client()
    
    try:
        if event_type == 'checkout.session.completed':
            # Checkout session completed - subscription created via web
            customer_id = data.get('customer')
            subscription_id = data.get('subscription')
            metadata = data.get('metadata', {})
            user_id = metadata.get('userId')
            
            if user_id and subscription_id:
                user_ref = db.collection('users').document(user_id)
                user_ref.set({
                    'stripeCustomerId': customer_id,
                    'subscriptionId': subscription_id,
                    'subscriptionStatus': 'active',
                    'isPremium': True
                }, merge=True)
        
        elif event_type == 'customer.subscription.updated':
            # Update subscription status
            customer_id = data.get('customer')
            subscription_status = data.get('status')
            
            # Find user by customer ID
            users = db.collection('users').where('stripeCustomerId', '==', customer_id).limit(1).stream()
            for user in users:
                user.reference.set({
                    'subscriptionStatus': subscription_status,
                    'isPremium': subscription_status in ['active', 'trialing']
                }, merge=True)
        
        elif event_type == 'customer.subscription.deleted':
            # Subscription cancelled
            customer_id = data.get('customer')
            
            users = db.collection('users').where('stripeCustomerId', '==', customer_id).limit(1).stream()
            for user in users:
                user.reference.set({
                    'isPremium': False,
                    'subscriptionStatus': 'cancelled'
                }, merge=True)
        
        elif event_type == 'payment_intent.succeeded':
            # One-time payment succeeded (lifetime premium)
            metadata = data.get('metadata', {})
            user_id = metadata.get('userId')
            payment_type = metadata.get('type')
            
            if user_id and payment_type == 'lifetime_premium':
                user_ref = db.collection('users').document(user_id)
                user_ref.set({
                    'isPremium': True,
                    'subscriptionType': 'lifetime'
                }, merge=True)
        
        return https_fn.Response("Success", status=200)
        
    except Exception as e:
        print(f"Error handling webhook: {str(e)}")
        return https_fn.Response(f"Error: {str(e)}", status=500)
