import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../utils/live_data_tester.dart';
import '../utils/test_live_data_simple.dart';
import 'logbook_screen.dart';
import 'favourites_screen.dart';
import 'river_run_search_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // #todo: Implement lazy loading of screens to improve initial load time
  // Only initialize screens when first accessed
  final List<Widget> _screens = [
    const FavouritesScreen(),
    const LogBookScreen(),
    const RiverRunSearchScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BrownClaw - Kayaking Hub'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          Consumer<UserProvider>(
            builder: (context, userProvider, child) {
              final user = userProvider.user;
              return PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'theme') {
                    context.read<ThemeProvider>().toggleTheme();
                  } else if (value == 'logout') {
                    await userProvider.signOut();
                    if (context.mounted) {
                      Navigator.pushReplacementNamed(context, '/');
                    }
                  } else if (value == 'test_live_data') {
                    // #todo: Remove debug options before production deployment
                    // Debug: Test live data functionality
                    if (kDebugMode) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Testing live data...')),
                      );
                      await LiveDataTester.testKnownStations();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Live data test complete'),
                          ),
                        );
                      }
                    }
                  } else if (value == 'test_simple_fetch') {
                    // #todo: Remove debug options before production deployment
                    // Debug: Test simple direct fetch
                    if (kDebugMode) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Testing simple fetch...'),
                        ),
                      );
                      await TestLiveDataSimple.testDirectFetch();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Simple fetch test complete'),
                          ),
                        );
                      }
                    }
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
                  if (kDebugMode)
                    const PopupMenuItem(
                      value: 'test_live_data',
                      child: Row(
                        children: [
                          Icon(Icons.refresh),
                          SizedBox(width: 8),
                          Text('Test Live Data'),
                        ],
                      ),
                    ),
                  if (kDebugMode)
                    const PopupMenuItem(
                      value: 'test_simple_fetch',
                      child: Row(
                        children: [
                          Icon(Icons.sensors),
                          SizedBox(width: 8),
                          Text('Test Simple Fetch'),
                        ],
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
                ],
                child: CircleAvatar(
                  backgroundColor: Colors.deepPurple,
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
      body: _screens[_selectedIndex],
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
          BottomNavigationBarItem(icon: Icon(Icons.kayaking), label: 'Logbook'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Find Runs'),
        ],
      ),
    );
  }
}
