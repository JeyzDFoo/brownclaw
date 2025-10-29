import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../widgets/update_banner.dart';
import '../services/analytics_service.dart';
import '../utils/performance_logger.dart';
import 'logbook_screen.dart';
import 'favourites_screen.dart';
import 'river_run_search_screen.dart';
import 'premium_settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    PerformanceLogger.log('main_screen_init_state');

    _pageController = PageController(initialPage: _selectedIndex);

    // Check for app updates on startup (web only)
    Future.microtask(() {
      if (mounted) {
        PerformanceLogger.log('checking_for_updates');
        context.read<VersionProvider>().checkForUpdate();
      }
    });

    // Log when first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PerformanceLogger.log('main_screen_first_frame_rendered');
      PerformanceLogger.printSummary();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // #todo: Implement lazy loading of screens to improve initial load time
  // Only initialize screens when first accessed
  List<Widget> get _screens => [
    FavouritesScreen(onNavigateToSearch: () => _onItemTapped(2)),
    const LogBookScreen(),
    const RiverRunSearchScreen(),
  ];

  // Page names for dynamic AppBar title
  final List<String> _pageNames = ['Favourites', 'Logbook', 'Find Runs'];

  void _onItemTapped(int index) {
    // Log tab navigation
    AnalyticsService.logTabNavigation(_pageNames[index], index);

    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VersionProvider>(
      builder: (context, versionProvider, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(_pageNames[_selectedIndex]),
            actions: [
              Consumer<UserProvider>(
                builder: (context, userProvider, child) {
                  final user = userProvider.user;
                  return PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'theme') {
                        final themeProvider = context.read<ThemeProvider>();
                        themeProvider.toggleTheme();
                        // Log theme change
                        await AnalyticsService.logThemeToggle(
                          themeProvider.isDarkMode ? 'dark' : 'light',
                        );
                        await AnalyticsService.logMenuAction('theme_toggle');
                      } else if (value == 'premium') {
                        await AnalyticsService.logMenuAction(
                          'premium_settings',
                        );
                        await AnalyticsService.logPremiumSettingsViewed();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const PremiumSettingsScreen(),
                          ),
                        );
                      } else if (value == 'logout') {
                        await AnalyticsService.logMenuAction('logout');
                        await AnalyticsService.logSignOut();
                        await userProvider.signOut();
                        if (context.mounted) {
                          Navigator.pushReplacementNamed(context, '/');
                        }
                      } else if (value == 'delete_account') {
                        await AnalyticsService.logMenuAction('delete_account');
                        _showDeleteAccountDialog(context, userProvider);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'theme',
                        child: Consumer<ThemeProvider>(
                          builder: (context, themeProvider, child) {
                            return Row(
                              children: [
                                Icon(
                                  themeProvider.isDarkMode
                                      ? Icons.light_mode
                                      : Icons.dark_mode,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  themeProvider.isDarkMode
                                      ? 'Light Mode'
                                      : 'Dark Mode',
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      // Premium menu - only show on web
                      if (kIsWeb)
                        PopupMenuItem(
                          value: 'premium',
                          child: Consumer<PremiumProvider>(
                            builder: (context, premiumProvider, child) {
                              return Row(
                                children: [
                                  Icon(
                                    premiumProvider.isPremium
                                        ? Icons.workspace_premium
                                        : Icons.lock,
                                    color: premiumProvider.isPremium
                                        ? Colors.amber
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    premiumProvider.isPremium
                                        ? 'Premium Active'
                                        : 'Premium Settings',
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'logout',
                        child: Row(
                          children: [
                            Icon(Icons.logout),
                            SizedBox(width: 8),
                            Text('Sign Out'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete_account',
                        child: Row(
                          children: [
                            Icon(Icons.delete_forever, color: Colors.red),
                            SizedBox(width: 8),
                            Text(
                              'Delete Account',
                              style: TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    ],
                    child: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Text(
                        (user?.displayName?.isNotEmpty == true)
                            ? user!.displayName![0].toUpperCase()
                            : (user?.email?.isNotEmpty == true)
                            ? user!.email![0].toUpperCase()
                            : 'U',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 16),
            ],
          ),
          body: Column(
            children: [
              // Show update banner if update is available
              if (versionProvider.showUpdateBanner)
                UpdateBanner(
                  message: versionProvider.updateMessage,
                  changelog: versionProvider.changelog,
                  onDismiss: () => versionProvider.dismissUpdateBanner(),
                ),
              // Main content
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  children: _screens,
                ),
              ),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: Colors.blue,
            unselectedItemColor: Colors.grey,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.favorite),
                label: 'Favourites',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.kayaking),
                label: 'Logbook',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.search),
                label: 'Find Runs',
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteAccountDialog(
    BuildContext context,
    UserProvider userProvider,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.red),
              SizedBox(width: 8),
              Text('Delete Account'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to delete your account?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text('This will permanently delete:'),
              SizedBox(height: 8),
              Text('• Your logbook entries'),
              Text('• Your favorite rivers'),
              Text('• All your personal data'),
              SizedBox(height: 16),
              Text(
                'This action cannot be undone.',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _deleteAccount(context, userProvider);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete Account'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteAccount(
    BuildContext context,
    UserProvider userProvider,
  ) async {
    try {
      // Show loading indicator
      if (!context.mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Delete user account (this will also trigger Firestore deletion via security rules)
      await userProvider.deleteAccount();

      // Log analytics
      await AnalyticsService.logMenuAction('account_deleted');

      // Close loading dialog and navigate to auth screen
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        Navigator.pushReplacementNamed(context, '/');
      }
    } catch (e) {
      // Close loading dialog if open
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Show error
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting account: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }

      // Log error
      await AnalyticsService.logError(
        'Account deletion failed: ${e.toString()}',
      );
    }
  }
}
