import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
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
    _pageController = PageController(initialPage: _selectedIndex);
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
                    context.read<ThemeProvider>().toggleTheme();
                  } else if (value == 'premium') {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const PremiumSettingsScreen(),
                      ),
                    );
                  } else if (value == 'logout') {
                    await userProvider.signOut();
                    if (context.mounted) {
                      Navigator.pushReplacementNamed(context, '/');
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
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: _screens,
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
          BottomNavigationBarItem(icon: Icon(Icons.kayaking), label: 'Logbook'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Find Runs'),
        ],
      ),
    );
  }
}
