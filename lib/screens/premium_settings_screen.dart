import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../services/stripe_service.dart';
import 'premium_purchase_screen.dart';

class PremiumSettingsScreen extends StatefulWidget {
  const PremiumSettingsScreen({super.key});

  @override
  State<PremiumSettingsScreen> createState() => _PremiumSettingsScreenState();
}

class _PremiumSettingsScreenState extends State<PremiumSettingsScreen> {
  bool _isCancelling = false;

  String _formatDate(DateTime? date) {
    if (date == null) return 'the end of your billing period';
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Future<void> _showCancelConfirmation(
    BuildContext context,
    PremiumProvider premiumProvider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Subscription?'),
        content: const Text(
          'Your premium features will remain active until the end of your current billing period. You can resubscribe at any time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Subscription'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancel Subscription'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _isCancelling = true;
      });

      try {
        await StripeService().cancelSubscription();

        if (mounted) {
          // Refresh premium status
          await premiumProvider.refreshPremiumStatus();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Subscription cancelled.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error cancelling subscription: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isCancelling = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.workspace_premium, color: Colors.amber.shade700),
            const SizedBox(width: 8),
            const Text('Premium'),
          ],
        ),
      ),
      body: Consumer<PremiumProvider>(
        builder: (context, premiumProvider, child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            premiumProvider.isPremium
                                ? Icons.workspace_premium
                                : Icons.lock,
                            color: premiumProvider.isPremium
                                ? Colors.amber
                                : Colors.grey,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  premiumProvider.isPremium
                                      ? 'Premium Active'
                                      : 'Free Account',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  premiumProvider.isPremium
                                      ? 'You have access to all features'
                                      : 'Upgrade to unlock extended historical data',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),
                      const Text(
                        'Premium Features:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildFeatureItem(
                        '14-day historical data',
                        premiumProvider.isPremium,
                      ),
                      _buildFeatureItem(
                        '30-day historical data',
                        premiumProvider.isPremium,
                      ),
                      _buildFeatureItem(
                        'Full year (365-day) historical data',
                        premiumProvider.isPremium,
                      ),
                      _buildFeatureItem(
                        'Advanced Brown',
                        premiumProvider.isPremium,
                      ),
                      // Developer Testing Toggle (only visible in debug mode)
                      if (kDebugMode) ...[
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),
                        const Text(
                          'Developer Testing:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          title: const Text('Toggle Premium Status (Dev Only)'),
                          subtitle: const Text(
                            'This is for testing purposes only',
                            style: TextStyle(fontSize: 12),
                          ),
                          value: premiumProvider.isPremium,
                          onChanged: (value) async {
                            await premiumProvider.setPremiumStatus(value);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    value
                                        ? 'Premium activated!'
                                        : 'Premium deactivated',
                                  ),
                                  backgroundColor: value
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                              );
                            }
                          },
                          activeColor: Colors.amber,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Subscription Management Card - for both premium and non-premium users
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        premiumProvider.isPremium
                            ? 'Manage Subscription'
                            : 'Get Premium',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        premiumProvider.isPremium
                            ? (premiumProvider.cancelAtPeriodEnd
                                  ? 'Your subscription has been cancelled and will end on ${_formatDate(premiumProvider.currentPeriodEnd)}. You can resubscribe at any time.'
                                  : 'Need to cancel? Your premium features will remain active until the end of your current billing period.')
                            : 'Unlock extended historical data and advanced features with Premium.',
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 16),
                      if (premiumProvider.isPremium &&
                          !premiumProvider.cancelAtPeriodEnd)
                        OutlinedButton.icon(
                          onPressed: _isCancelling
                              ? null
                              : () => _showCancelConfirmation(
                                  context,
                                  premiumProvider,
                                ),
                          icon: _isCancelling
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.cancel_outlined),
                          label: Text(
                            _isCancelling
                                ? 'Cancelling...'
                                : 'Cancel Subscription',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        )
                      else if (premiumProvider.isPremium &&
                          premiumProvider.cancelAtPeriodEnd)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.orange.shade700,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Cancellation scheduled',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.orange.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    const PremiumPurchaseScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.workspace_premium),
                          label: const Text('Subscribe to Premium'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFeatureItem(String text, bool isPremium) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            isPremium ? Icons.check_circle : Icons.lock,
            color: isPremium ? Colors.green : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: isPremium ? null : Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
