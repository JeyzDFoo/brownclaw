import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import 'premium_purchase_screen.dart';

class PremiumSettingsScreen extends StatelessWidget {
  const PremiumSettingsScreen({super.key});

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
                        '7-day historical data',
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
                        'Advanced analytics',
                        premiumProvider.isPremium,
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),
                      // Testing toggle (for development)
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
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (!premiumProvider.isPremium)
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const PremiumPurchaseScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.workspace_premium),
                  label: const Text('Upgrade to Premium'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.all(16),
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
                color: isPremium ? Colors.black : Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
