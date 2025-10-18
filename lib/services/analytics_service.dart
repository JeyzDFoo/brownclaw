import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Service for logging analytics events throughout the app
class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  static FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  // User Events
  static Future<void> logLogin(String method) async {
    await _analytics.logLogin(loginMethod: method);
    if (kDebugMode) print('📊 Analytics: User logged in via $method');
  }

  static Future<void> logSignUp(String method) async {
    await _analytics.logSignUp(signUpMethod: method);
    if (kDebugMode) print('📊 Analytics: User signed up via $method');
  }

  static Future<void> setUserId(String userId) async {
    await _analytics.setUserId(id: userId);
    if (kDebugMode) print('📊 Analytics: User ID set to $userId');
  }

  static Future<void> setUserProperty(String name, String value) async {
    await _analytics.setUserProperty(name: name, value: value);
    if (kDebugMode) print('📊 Analytics: User property $name = $value');
  }

  // River Run Events
  static Future<void> logRiverRunAdded(String riverId, String riverName) async {
    await _analytics.logEvent(
      name: 'river_run_added',
      parameters: {
        'river_id': riverId,
        'river_name': riverName,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
    if (kDebugMode) print('📊 Analytics: River run added for $riverName');
  }

  static Future<void> logRiverRunViewed(
    String riverId,
    String riverName,
  ) async {
    await _analytics.logEvent(
      name: 'river_run_viewed',
      parameters: {'river_id': riverId, 'river_name': riverName},
    );
    if (kDebugMode) print('📊 Analytics: River run viewed for $riverName');
  }

  static Future<void> logRiverRunEdited(String riverId) async {
    await _analytics.logEvent(
      name: 'river_run_edited',
      parameters: {'river_id': riverId},
    );
    if (kDebugMode) print('📊 Analytics: River run edited');
  }

  static Future<void> logRiverRunDeleted(String riverId) async {
    await _analytics.logEvent(
      name: 'river_run_deleted',
      parameters: {'river_id': riverId},
    );
    if (kDebugMode) print('📊 Analytics: River run deleted');
  }

  // Favorites Events
  static Future<void> logFavoriteAdded(String riverId, String riverName) async {
    await _analytics.logEvent(
      name: 'favorite_added',
      parameters: {'river_id': riverId, 'river_name': riverName},
    );
    if (kDebugMode) print('📊 Analytics: Favorite added for $riverName');
  }

  static Future<void> logFavoriteRemoved(
    String riverId,
    String riverName,
  ) async {
    await _analytics.logEvent(
      name: 'favorite_removed',
      parameters: {'river_id': riverId, 'river_name': riverName},
    );
    if (kDebugMode) print('📊 Analytics: Favorite removed for $riverName');
  }

  // Premium/Subscription Events
  static Future<void> logPurchaseInitiated(
    String productId,
    double price,
  ) async {
    await _analytics.logEvent(
      name: 'purchase_initiated',
      parameters: {'product_id': productId, 'price': price, 'currency': 'CAD'},
    );
    if (kDebugMode) print('📊 Analytics: Purchase initiated for $productId');
  }

  static Future<void> logPurchaseCompleted(
    String productId,
    double price,
  ) async {
    await _analytics.logPurchase(
      currency: 'CAD',
      value: price,
      items: [
        AnalyticsEventItem(itemId: productId, itemName: 'Premium Subscription'),
      ],
    );
    if (kDebugMode) print('📊 Analytics: Purchase completed for $productId');
  }

  static Future<void> logSubscriptionCancelled() async {
    await _analytics.logEvent(name: 'subscription_cancelled');
    if (kDebugMode) print('📊 Analytics: Subscription cancelled');
  }

  // Screen Views
  static Future<void> logScreenView(String screenName) async {
    await _analytics.logScreenView(screenName: screenName);
    if (kDebugMode) print('📊 Analytics: Screen view - $screenName');
  }

  // Search Events
  static Future<void> logSearch(String searchTerm) async {
    await _analytics.logSearch(searchTerm: searchTerm);
    if (kDebugMode) print('📊 Analytics: Search - $searchTerm');
  }

  // Water Level Events
  static Future<void> logWaterLevelViewed(String stationId) async {
    await _analytics.logEvent(
      name: 'water_level_viewed',
      parameters: {'station_id': stationId},
    );
    if (kDebugMode) print('📊 Analytics: Water level viewed for $stationId');
  }

  // Custom Events
  static Future<void> logCustomEvent(
    String eventName, {
    Map<String, Object>? parameters,
  }) async {
    await _analytics.logEvent(name: eventName, parameters: parameters);
    if (kDebugMode) print('📊 Analytics: Custom event - $eventName');
  }

  // Share Events
  static Future<void> logShare(String contentType, String itemId) async {
    await _analytics.logShare(
      contentType: contentType,
      itemId: itemId,
      method: 'share_button',
    );
    if (kDebugMode) print('📊 Analytics: Share - $contentType');
  }

  // App Events
  static Future<void> logAppOpen() async {
    await _analytics.logAppOpen();
    if (kDebugMode) print('📊 Analytics: App opened');
  }

  // Error Tracking
  static Future<void> logError(
    String errorMessage, {
    String? stackTrace,
  }) async {
    await _analytics.logEvent(
      name: 'app_error',
      parameters: {
        'error_message': errorMessage,
        if (stackTrace != null) 'stack_trace': stackTrace,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
    if (kDebugMode) print('📊 Analytics: Error logged - $errorMessage');
  }

  // Navigation Events
  static Future<void> logTabNavigation(String tabName, int tabIndex) async {
    await _analytics.logEvent(
      name: 'tab_navigation',
      parameters: {'tab_name': tabName, 'tab_index': tabIndex},
    );
    if (kDebugMode) print('📊 Analytics: Tab navigation - $tabName');
  }

  // UI Interaction Events
  static Future<void> logThemeToggle(String newTheme) async {
    await _analytics.logEvent(
      name: 'theme_toggled',
      parameters: {'theme': newTheme},
    );
    if (kDebugMode) print('📊 Analytics: Theme toggled to $newTheme');
  }

  static Future<void> logRefreshAction(String screen) async {
    await _analytics.logEvent(
      name: 'refresh_action',
      parameters: {'screen': screen},
    );
    if (kDebugMode) print('📊 Analytics: Refresh on $screen');
  }

  // Logbook Events
  static Future<void> logLogbookEntryCreated(String riverName) async {
    await _analytics.logEvent(
      name: 'logbook_entry_created',
      parameters: {
        'river_name': riverName,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
    if (kDebugMode) print('📊 Analytics: Logbook entry created for $riverName');
  }

  static Future<void> logLogbookEntryViewed(String entryId) async {
    await _analytics.logEvent(
      name: 'logbook_entry_viewed',
      parameters: {'entry_id': entryId},
    );
    if (kDebugMode) print('📊 Analytics: Logbook entry viewed');
  }

  static Future<void> logLogbookEntryDeleted(String riverName) async {
    await _analytics.logEvent(
      name: 'logbook_entry_deleted',
      parameters: {'river_name': riverName},
    );
    if (kDebugMode) print('📊 Analytics: Logbook entry deleted for $riverName');
  }

  static Future<void> logRatingAdded(double rating, String riverName) async {
    await _analytics.logEvent(
      name: 'rating_added',
      parameters: {'rating': rating, 'river_name': riverName},
    );
    if (kDebugMode) print('📊 Analytics: Rating $rating added for $riverName');
  }

  // Chart Interaction Events
  static Future<void> logChartTimeRangeChanged(int days, String riverId) async {
    await _analytics.logEvent(
      name: 'chart_timerange_changed',
      parameters: {'days': days, 'river_id': riverId},
    );
    if (kDebugMode)
      print('📊 Analytics: Chart time range changed to $days days');
  }

  static Future<void> logChartInteraction(String interactionType) async {
    await _analytics.logEvent(
      name: 'chart_interaction',
      parameters: {'interaction_type': interactionType},
    );
    if (kDebugMode) print('📊 Analytics: Chart interaction - $interactionType');
  }

  // Premium Feature Events
  static Future<void> logPremiumPaywallViewed(String feature) async {
    await _analytics.logEvent(
      name: 'premium_paywall_viewed',
      parameters: {
        'feature': feature,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
    if (kDebugMode) print('📊 Analytics: Premium paywall viewed for $feature');
  }

  static Future<void> logPremiumSettingsViewed() async {
    await _analytics.logEvent(name: 'premium_settings_viewed');
    if (kDebugMode) print('📊 Analytics: Premium settings viewed');
  }

  // TransAlta Specific Events
  static Future<void> logTransAltaDataViewed(String riverName) async {
    await _analytics.logEvent(
      name: 'transalta_data_viewed',
      parameters: {'river_name': riverName},
    );
    if (kDebugMode) print('📊 Analytics: TransAlta data viewed for $riverName');
  }

  static Future<void> logTransAltaForecastExpanded() async {
    await _analytics.logEvent(name: 'transalta_forecast_expanded');
    if (kDebugMode) print('📊 Analytics: TransAlta forecast expanded');
  }

  // Search Events - Enhanced
  static Future<void> logRiverSearch(
    String searchTerm, {
    int? resultCount,
  }) async {
    await _analytics.logSearch(searchTerm: searchTerm);
    await _analytics.logEvent(
      name: 'river_search',
      parameters: {
        'search_term': searchTerm,
        if (resultCount != null) 'result_count': resultCount,
      },
    );
    if (kDebugMode)
      print(
        '📊 Analytics: River search - "$searchTerm" ($resultCount results)',
      );
  }

  static Future<void> logSearchFilterApplied(
    String filterType,
    String filterValue,
  ) async {
    await _analytics.logEvent(
      name: 'search_filter_applied',
      parameters: {'filter_type': filterType, 'filter_value': filterValue},
    );
    if (kDebugMode)
      print('📊 Analytics: Filter applied - $filterType: $filterValue');
  }

  // Engagement Events
  static Future<void> logDataSourceViewed(String source) async {
    await _analytics.logEvent(
      name: 'data_source_viewed',
      parameters: {'source': source},
    );
    if (kDebugMode) print('📊 Analytics: Data source viewed - $source');
  }

  static Future<void> logFeatureDiscovered(String featureName) async {
    await _analytics.logEvent(
      name: 'feature_discovered',
      parameters: {
        'feature_name': featureName,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
    if (kDebugMode) print('📊 Analytics: Feature discovered - $featureName');
  }

  // Authentication Events - Enhanced
  static Future<void> logSignInAttempt(String method) async {
    await _analytics.logEvent(
      name: 'sign_in_attempt',
      parameters: {'method': method},
    );
    if (kDebugMode) print('📊 Analytics: Sign in attempt via $method');
  }

  static Future<void> logSignInFailure(String method, String reason) async {
    await _analytics.logEvent(
      name: 'sign_in_failure',
      parameters: {'method': method, 'reason': reason},
    );
    if (kDebugMode) print('📊 Analytics: Sign in failed - $method: $reason');
  }

  static Future<void> logSignOut() async {
    await _analytics.logEvent(name: 'sign_out');
    if (kDebugMode) print('📊 Analytics: User signed out');
  }

  // Menu Actions
  static Future<void> logMenuAction(String action) async {
    await _analytics.logEvent(
      name: 'menu_action',
      parameters: {'action': action},
    );
    if (kDebugMode) print('📊 Analytics: Menu action - $action');
  }
}
