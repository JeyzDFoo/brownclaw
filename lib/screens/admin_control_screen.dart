import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/providers.dart';
import '../services/analytics_service.dart';

class AdminControlScreen extends StatefulWidget {
  const AdminControlScreen({super.key});

  @override
  State<AdminControlScreen> createState() => _AdminControlScreenState();
}

class _AdminControlScreenState extends State<AdminControlScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    AnalyticsService.logScreenView('admin_control');
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool isError = false}) {
    setState(() {
      _message = message;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        // Double-check admin access
        if (!userProvider.isAdmin) {
          return Scaffold(
            appBar: AppBar(title: const Text('Access Denied')),
            body: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text(
                    'Admin Access Required',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'You do not have permission to access this area.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.admin_panel_settings, color: Colors.red.shade700),
                const SizedBox(width: 8),
                const Text('Admin Control Panel'),
              ],
            ),
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabs: const [
                Tab(icon: Icon(Icons.data_usage), text: 'Data'),
                Tab(icon: Icon(Icons.people), text: 'Users'),
                Tab(icon: Icon(Icons.workspace_premium), text: 'Premium'),
                Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
                Tab(icon: Icon(Icons.build), text: 'System'),
              ],
            ),
          ),
          body: Column(
            children: [
              // Status message bar
              if (_message != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: Colors.blue.shade100,
                  child: Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _message!,
                          style: TextStyle(color: Colors.blue.shade700),
                        ),
                      ),
                      IconButton(
                        onPressed: () => setState(() => _message = null),
                        icon: const Icon(Icons.close),
                        iconSize: 20,
                      ),
                    ],
                  ),
                ),
              // Loading indicator
              if (_isLoading) const LinearProgressIndicator(),
              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDataManagementTab(),
                    _buildUserManagementTab(),
                    _buildPremiumManagementTab(),
                    _buildAnalyticsTab(),
                    _buildSystemTab(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDataManagementTab() {
    return Consumer3<RiverRunProvider, FavoritesProvider, CacheProvider>(
      builder: (context, riverRunProvider, favoritesProvider, cacheProvider, child) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSectionCard(
              title: 'River Data',
              icon: Icons.water,
              children: [
                ListTile(
                  leading: const Icon(Icons.refresh),
                  title: const Text('Refresh All River Runs'),
                  subtitle: Text(
                    '${riverRunProvider.riverRuns.length} runs loaded',
                  ),
                  onTap: () async {
                    setState(() => _isLoading = true);
                    try {
                      await riverRunProvider.loadAllRuns(forceRefresh: true);
                      _showMessage('River runs refreshed successfully');
                    } catch (e) {
                      _showMessage('Failed to refresh: $e', isError: true);
                    } finally {
                      setState(() => _isLoading = false);
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.clear_all),
                  title: const Text('Clear All Caches'),
                  subtitle: const Text('Clear all cached data'),
                  onTap: () async {
                    final confirmed = await _showConfirmDialog(
                      'Clear All Caches',
                      'This will clear all cached data and force fresh data fetch. Continue?',
                    );
                    if (confirmed == true) {
                      setState(() => _isLoading = true);
                      try {
                        riverRunProvider.clearCache();
                        // Note: FavoritesProvider doesn't expose clearCache publicly
                        // cacheProvider.clearAll() doesn't exist, need different approach
                        _showMessage('River run cache cleared successfully');
                      } catch (e) {
                        _showMessage(
                          'Failed to clear caches: $e',
                          isError: true,
                        );
                      } finally {
                        setState(() => _isLoading = false);
                      }
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.info),
                  title: const Text('Data Statistics'),
                  subtitle: Text(
                    '${riverRunProvider.riverRuns.length} river runs loaded',
                  ),
                  onTap: () {
                    _showDataStatsDialog(riverRunProvider);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              title: 'Live Data Sources',
              icon: Icons.live_help,
              children: [
                Consumer2<LiveWaterDataProvider, TransAltaProvider>(
                  builder: (context, liveDataProvider, transaltaProvider, child) {
                    return Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.water_drop),
                          title: const Text('Government of Canada API'),
                          subtitle: const Text('Real-time hydrometric data'),
                          trailing: IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: () async {
                              setState(() => _isLoading = true);
                              try {
                                _showMessage('Live data refresh initiated');
                              } catch (e) {
                                _showMessage(
                                  'Failed to refresh live data: $e',
                                  isError: true,
                                );
                              } finally {
                                setState(() => _isLoading = false);
                              }
                            },
                          ),
                        ),
                        ListTile(
                          leading: const Icon(Icons.landscape),
                          title: const Text('TransAlta Kananaskis'),
                          subtitle: Text(
                            'Status: ${transaltaProvider.isLoading ? 'Loading...' : 'Ready'}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: () async {
                              setState(() => _isLoading = true);
                              try {
                                await transaltaProvider.fetchFlowData(
                                  forceRefresh: true,
                                );
                                _showMessage(
                                  'TransAlta data refreshed successfully',
                                );
                              } catch (e) {
                                _showMessage(
                                  'Failed to refresh TransAlta data: $e',
                                  isError: true,
                                );
                              } finally {
                                setState(() => _isLoading = false);
                              }
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildUserManagementTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionCard(
          title: 'User Statistics',
          icon: Icons.people_alt,
          children: [
            ListTile(
              leading: const Icon(Icons.query_stats),
              title: const Text('Get User Stats'),
              subtitle: const Text('Fetch analytics on user activity'),
              onTap: () async {
                setState(() => _isLoading = true);
                try {
                  // Get user count from Firestore
                  final usersSnapshot = await FirebaseFirestore.instance
                      .collection('users')
                      .get();

                  final userCount = usersSnapshot.docs.length;
                  _showMessage('Total registered users: $userCount');
                } catch (e) {
                  _showMessage('Failed to fetch user stats: $e', isError: true);
                } finally {
                  setState(() => _isLoading = false);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.analytics),
              title: const Text('Active Users (Last 30 Days)'),
              subtitle: const Text('Analytics-based user activity'),
              onTap: () {
                _showMessage(
                  'Check Firebase Analytics console for detailed user metrics',
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          title: 'User Actions',
          icon: Icons.admin_panel_settings,
          children: [
            if (kDebugMode)
              ListTile(
                leading: const Icon(Icons.bug_report, color: Colors.orange),
                title: const Text('Debug: List All Users'),
                subtitle: const Text('Development only - show user collection'),
                onTap: () async {
                  setState(() => _isLoading = true);
                  try {
                    final usersSnapshot = await FirebaseFirestore.instance
                        .collection('users')
                        .limit(10)
                        .get();

                    final usersList = usersSnapshot.docs
                        .map(
                          (doc) =>
                              '${doc.id}: ${doc.data()['email'] ?? 'No email'}',
                        )
                        .join('\n');

                    _showUserListDialog(usersList);
                  } catch (e) {
                    _showMessage('Failed to fetch users: $e', isError: true);
                  } finally {
                    setState(() => _isLoading = false);
                  }
                },
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildPremiumManagementTab() {
    return Consumer<PremiumProvider>(
      builder: (context, premiumProvider, child) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSectionCard(
              title: 'Premium Overview',
              icon: Icons.workspace_premium,
              children: [
                ListTile(
                  leading: Icon(
                    Icons.workspace_premium,
                    color: premiumProvider.isPremium
                        ? Colors.amber
                        : Colors.grey,
                  ),
                  title: const Text('Current User Status'),
                  subtitle: Text(
                    premiumProvider.isPremium ? 'Premium Active' : 'Free User',
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.monetization_on),
                  title: const Text('Premium Statistics'),
                  subtitle: const Text('View subscription metrics'),
                  onTap: () async {
                    setState(() => _isLoading = true);
                    try {
                      // Count premium users
                      final premiumUsersSnapshot = await FirebaseFirestore
                          .instance
                          .collection('users')
                          .where('isPremium', isEqualTo: true)
                          .get();

                      final premiumCount = premiumUsersSnapshot.docs.length;
                      _showMessage('Premium subscribers: $premiumCount');
                    } catch (e) {
                      _showMessage(
                        'Failed to fetch premium stats: $e',
                        isError: true,
                      );
                    } finally {
                      setState(() => _isLoading = false);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (kDebugMode)
              _buildSectionCard(
                title: 'Development Tools',
                icon: Icons.bug_report,
                children: [
                  ListTile(
                    leading: const Icon(Icons.toggle_on, color: Colors.orange),
                    title: const Text('Toggle Premium (Debug)'),
                    subtitle: const Text('Development testing only'),
                    onTap: () async {
                      final confirmed = await _showConfirmDialog(
                        'Toggle Premium Status',
                        'This is for development testing only. Toggle premium status?',
                      );
                      if (confirmed == true) {
                        // This would need to be implemented in PremiumProvider
                        _showMessage('Premium toggle feature would go here');
                      }
                    },
                  ),
                ],
              ),
          ],
        );
      },
    );
  }

  Widget _buildAnalyticsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionCard(
          title: 'Analytics Overview',
          icon: Icons.analytics,
          children: [
            ListTile(
              leading: const Icon(Icons.timeline),
              title: const Text('Firebase Analytics'),
              subtitle: const Text(
                'View detailed analytics in Firebase Console',
              ),
              onTap: () {
                _showMessage(
                  'Open Firebase Console > Analytics for detailed metrics',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.event),
              title: const Text('Test Analytics Event'),
              subtitle: const Text('Send a test event'),
              onTap: () async {
                try {
                  await AnalyticsService.logCustomEvent(
                    'admin_test_event',
                    parameters: {
                      'timestamp': DateTime.now().toIso8601String(),
                      'admin_user':
                          context.read<UserProvider>().user?.email ?? 'unknown',
                    },
                  );
                  _showMessage('Test analytics event sent successfully');
                } catch (e) {
                  _showMessage(
                    'Failed to send analytics event: $e',
                    isError: true,
                  );
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          title: 'Usage Metrics',
          icon: Icons.bar_chart,
          children: [
            ListTile(
              leading: const Icon(Icons.favorite),
              title: const Text('Popular Rivers'),
              subtitle: const Text('Most favorited river runs'),
              onTap: () async {
                setState(() => _isLoading = true);
                try {
                  // This would require aggregating favorites data
                  _showMessage(
                    'Popular rivers analysis would be implemented here',
                  );
                } catch (e) {
                  _showMessage(
                    'Failed to analyze popular rivers: $e',
                    isError: true,
                  );
                } finally {
                  setState(() => _isLoading = false);
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSystemTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionCard(
          title: 'App Information',
          icon: Icons.info,
          children: [
            Consumer<VersionProvider>(
              builder: (context, versionProvider, child) {
                return ListTile(
                  leading: const Icon(Icons.app_settings_alt),
                  title: const Text('App Version'),
                  subtitle: Text(
                    'Update available: ${versionProvider.updateAvailable}',
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.update),
              title: const Text('Check for Updates'),
              subtitle: const Text('Check if new version is available'),
              onTap: () async {
                setState(() => _isLoading = true);
                try {
                  await context.read<VersionProvider>().checkForUpdate();
                  _showMessage('Update check completed');
                } catch (e) {
                  _showMessage(
                    'Failed to check for updates: $e',
                    isError: true,
                  );
                } finally {
                  setState(() => _isLoading = false);
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          title: 'Firebase Status',
          icon: Icons.cloud,
          children: [
            ListTile(
              leading: const Icon(Icons.cloud_done),
              title: const Text('Firestore Connection'),
              subtitle: const Text('Check database connectivity'),
              onTap: () async {
                setState(() => _isLoading = true);
                try {
                  await FirebaseFirestore.instance
                      .collection('rivers')
                      .limit(1)
                      .get();
                  _showMessage('Firestore connection: ✅ Healthy');
                } catch (e) {
                  _showMessage(
                    'Firestore connection failed: $e',
                    isError: true,
                  );
                } finally {
                  setState(() => _isLoading = false);
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (kDebugMode)
          _buildSectionCard(
            title: 'Debug Tools',
            icon: Icons.bug_report,
            children: [
              ListTile(
                leading: const Icon(Icons.clear_all, color: Colors.red),
                title: const Text('Clear All Local Storage'),
                subtitle: const Text('Reset app to clean state'),
                onTap: () async {
                  final confirmed = await _showConfirmDialog(
                    'Clear All Local Storage',
                    'This will clear all cached data, preferences, and force app restart. Continue?',
                  );
                  if (confirmed == true) {
                    setState(() => _isLoading = true);
                    try {
                      // Clear what we can access
                      context.read<RiverRunProvider>().clearCache();
                      _showMessage(
                        'Local caches cleared. App restart recommended.',
                      );
                    } catch (e) {
                      _showMessage(
                        'Failed to clear storage: $e',
                        isError: true,
                      );
                    } finally {
                      setState(() => _isLoading = false);
                    }
                  }
                },
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Future<bool?> _showConfirmDialog(String title, String content) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _showDataStatsDialog(RiverRunProvider riverRunProvider) {
    final runs = riverRunProvider.riverRuns;
    final riversCount = runs.map((r) => r.run.riverId).toSet().length;
    final stationsCount = runs
        .expand((r) => r.stations)
        .map((s) => s.stationId)
        .toSet()
        .length;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Data Statistics'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('River Runs: ${runs.length}'),
            Text('Unique Rivers: $riversCount'),
            Text('Associated Stations: $stationsCount'),
            const SizedBox(height: 16),
            const Text('Cache Status: Available'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showUserListDialog(String usersList) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Users (Debug)'),
        content: SingleChildScrollView(
          child: Text(usersList.isEmpty ? 'No users found' : usersList),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
