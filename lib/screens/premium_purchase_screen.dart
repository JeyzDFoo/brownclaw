import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../services/stripe_service.dart';
import '../services/analytics_service.dart';
import '../providers/providers.dart';

class PremiumPurchaseScreen extends StatefulWidget {
  const PremiumPurchaseScreen({super.key});

  @override
  State<PremiumPurchaseScreen> createState() => _PremiumPurchaseScreenState();
}

class _PremiumPurchaseScreenState extends State<PremiumPurchaseScreen> {
  bool _isProcessing = false;
  String? _errorMessage;

  // Stripe Price ID for $2.29/month subscription
  static const String monthlyPriceId =
      'price_1SJfs2AdlcDQOrDhClFs3rTf'; // Premium Monthly - $2.29/month

  @override
  Widget build(BuildContext context) {
    // On Android, show coming soon message (Google Play Billing required)
    if (!kIsWeb) {
      return Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.workspace_premium, color: Colors.white),
              const SizedBox(width: 8),
              const Text('Premium'),
            ],
          ),
          backgroundColor: Colors.amber.shade700,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.construction, size: 80, color: Colors.amber),
                const SizedBox(height: 24),
                const Text(
                  'Premium Subscriptions\nComing Soon!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  'Premium features will be available for purchase through Google Play Store in a future update.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),
                Text(
                  'In the meantime, visit brownclaw.com on the web to upgrade!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Web version with Stripe checkout
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.workspace_premium, color: Colors.white),
            const SizedBox(width: 8),
            const Text('Upgrade to Premium'),
          ],
        ),
        backgroundColor: Colors.amber.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            const Icon(Icons.workspace_premium, size: 80, color: Colors.amber),
            const SizedBox(height: 16),
            const Text(
              'Unlock Premium Features',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Get access to extended historical data and advanced analytics',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),

            // Features List
            const Text(
              'Premium Features:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildFeatureItem('📊 7-day historical data view'),
            _buildFeatureItem('📈 30-day historical data view'),
            _buildFeatureItem('📉 Full year (365-day) historical view'),
            _buildFeatureItem('🎯 Advanced flow statistics'),
            _buildFeatureItem('⚡ Priority data updates'),
            _buildFeatureItem('🔔 Custom flow alerts (coming soon)'),
            const SizedBox(height: 32),

            // Pricing Card
            const Text(
              'Simple, Affordable Pricing:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Monthly Plan - Only option
            _buildPricingCard(
              title: 'Premium Monthly',
              price: '\$2.29',
              period: '/month',
              description: 'Cancel anytime. No questions asked.',
              isPopular: true,
              badge: 'BEST VALUE',
              onTap: () => _handleSubscription(monthlyPriceId, 'Monthly'),
            ),
            const SizedBox(height: 24),

            // Error Message
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            // Footer
            Text(
              'Secure payment powered by Stripe',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Cancel anytime. No questions asked.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 24),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }

  Widget _buildPricingCard({
    required String title,
    required String price,
    required String period,
    required String description,
    required bool isPopular,
    String? badge,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: isPopular ? 8 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isPopular ? Colors.amber : Colors.grey.shade300,
          width: isPopular ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: _isProcessing ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    price,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      period,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
              if (_isProcessing) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(color: Colors.amber),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSubscription(String priceId, String planName) async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    // Log purchase initiation
    await AnalyticsService.logPurchaseInitiated(priceId, 2.29);

    try {
      final success = await StripeService().createSubscription(
        priceId: priceId,
      );

      if (success && mounted) {
        // Log successful purchase
        await AnalyticsService.logPurchaseCompleted(priceId, 2.29);

        // Refresh premium status
        await context.read<PremiumProvider>().refreshPremiumStatus();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🎉 Welcome to Premium! ($planName plan)'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
          Navigator.of(context).pop(); // Return to previous screen
        }
      }
    } catch (e) {
      // Log purchase failure
      await AnalyticsService.logError('Purchase failed: ${e.toString()}');

      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }
}
