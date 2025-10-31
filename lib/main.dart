import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/auth_screen.dart';
import 'screens/main_screen.dart';
import 'providers/providers.dart';
import 'services/analytics_service.dart';
import 'utils/performance_logger.dart';

void main() async {
  // Mark the very start of app initialization
  PerformanceLogger.markAppStart();

  WidgetsFlutterBinding.ensureInitialized();
  PerformanceLogger.log('flutter_binding_initialized');

  // 🔇 PRODUCTION: Disable ALL prints in release mode (production builds)
  // This override ensures NO debug output appears in production deployments
  if (!kDebugMode) {
    // Override debugPrint to be completely silent in production
    debugPrint = (String? message, {int? wrapWidth}) {
      // Silent in production - no debug output
    };

    // Note: Flutter's print() function calls debugPrint internally in release builds
    // This means ALL print() and debugPrint() calls are silenced in production
    //
    // ✅ Benefits:
    // - Cleaner production logs (no spam)
    // - Better performance (no string processing)
    // - No sensitive debug info leaking to production
    // - Professional user experience
    //
    // 🛠️ For debugging production issues:
    // - Use Firebase Analytics for user behavior tracking
    // - Use Firebase Crashlytics for error reporting
    // - Use PerformanceLogger for performance metrics
    // - Add specific production logging if needed (not debug prints)
  }
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  PerformanceLogger.log('firebase_initialized');

  // Note: Stripe is only used on web (premium purchases via web only)
  // Android will use Google Play Billing in a future update

  // Log app open event
  await AnalyticsService.logAppOpen();
  PerformanceLogger.log('analytics_logged');

  runApp(const MainApp());
  PerformanceLogger.log('runApp_called');
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    PerformanceLogger.log('main_app_build_started');

    return MultiProvider(
      providers: [
        // Caching provider - foundation for all data caching
        ChangeNotifierProvider(
          create: (_) {
            PerformanceLogger.log('cache_provider_creating');
            final provider = CacheProvider();
            // Initialize cache from persistent storage asynchronously
            provider.ensureInitialized();
            PerformanceLogger.log('cache_provider_created');
            return provider;
          },
        ),
        // #todo: Consider adding StationProvider for centralized station data
        ChangeNotifierProvider(
          create: (_) {
            PerformanceLogger.log('user_provider_creating');
            final provider = UserProvider();
            PerformanceLogger.log('user_provider_created');
            return provider;
          },
        ),
        // RiverRunProvider with CacheProvider dependency for persistent cache
        ChangeNotifierProxyProvider<CacheProvider, RiverRunProvider>(
          create: (context) {
            PerformanceLogger.log('river_run_provider_creating');
            final cacheProvider = context.read<CacheProvider>();
            final provider = RiverRunProvider(cacheProvider: cacheProvider);
            PerformanceLogger.log('river_run_provider_created');
            return provider;
          },
          update: (context, cacheProvider, previous) {
            PerformanceLogger.log('river_run_provider_updating');
            // Reuse existing provider if available, otherwise create new
            return previous ?? RiverRunProvider(cacheProvider: cacheProvider);
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            PerformanceLogger.log('favorites_provider_creating');
            final provider = FavoritesProvider();
            PerformanceLogger.log('favorites_provider_created');
            return provider;
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            PerformanceLogger.log('theme_provider_creating');
            final provider = ThemeProvider();
            PerformanceLogger.log('theme_provider_created');
            return provider;
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            PerformanceLogger.log('live_water_data_provider_creating');
            final provider = LiveWaterDataProvider();
            PerformanceLogger.log('live_water_data_provider_created');
            return provider;
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            PerformanceLogger.log('logbook_provider_creating');
            final provider = LogbookProvider();
            PerformanceLogger.log('logbook_provider_created');
            return provider;
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            PerformanceLogger.log('premium_provider_creating');
            final provider = PremiumProvider();
            PerformanceLogger.log('premium_provider_created');
            return provider;
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            PerformanceLogger.log('transalta_provider_creating');
            final provider = TransAltaProvider();
            PerformanceLogger.log('transalta_provider_created');
            return provider;
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            PerformanceLogger.log('version_provider_creating');
            final provider = VersionProvider();
            PerformanceLogger.log('version_provider_created');
            return provider;
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            PerformanceLogger.log('historical_water_data_provider_creating');
            final provider = HistoricalWaterDataProvider();
            // Initialize cache from persistent storage asynchronously
            provider.ensureInitialized();
            PerformanceLogger.log('historical_water_data_provider_created');
            return provider;
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            PerformanceLogger.log('weather_provider_creating');
            final provider = WeatherProvider();
            // Initialize cache from persistent storage asynchronously
            provider.ensureInitialized();
            PerformanceLogger.log('weather_provider_created');
            return provider;
          },
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          PerformanceLogger.log('material_app_building');
          return MaterialApp(
            title: 'Brown Paw - Whitewater Logbook',
            theme: themeProvider.lightTheme,
            darkTheme: themeProvider.darkTheme,
            themeMode: themeProvider.themeMode,
            navigatorObservers: [AnalyticsService.observer],
            // #todo: Remove artificial width constraint for mobile-first design
            builder: (context, child) {
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: child!,
                ),
              );
            },
            home: const HomePage(),
          );
        },
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    PerformanceLogger.log('home_page_build_started');

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          PerformanceLogger.log('auth_state_waiting');
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          PerformanceLogger.log('user_authenticated_loading_main_screen');
          return const MainScreen();
        }

        PerformanceLogger.log('user_not_authenticated_loading_auth_screen');
        return const AuthScreen();
      },
    );
  }
}
