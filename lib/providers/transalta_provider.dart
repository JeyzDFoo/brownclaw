import 'package:flutter/foundation.dart';
import '../models/transalta_flow_data.dart';
import '../services/transalta_service.dart';

/// Provider for managing TransAlta Barrier Dam flow data
///
/// Centralizes API calls and caching for TransAlta data used across
/// the app (favorites list, river detail screen, etc.)
class TransAltaProvider extends ChangeNotifier {
  TransAltaFlowData? _flowData;
  DateTime? _lastFetchTime;
  bool _isLoading = false;
  String? _error;

  // Cache duration - matches service cache
  static const Duration _cacheDuration = Duration(minutes: 15);

  TransAltaFlowData? get flowData => _flowData;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasData => _flowData != null;

  /// Get cached data age in minutes
  int? get cacheAgeMinutes {
    if (_lastFetchTime == null) return null;
    return DateTime.now().difference(_lastFetchTime!).inMinutes;
  }

  /// Check if cache is still valid
  bool get isCacheValid {
    if (_lastFetchTime == null || _flowData == null) return false;
    final age = DateTime.now().difference(_lastFetchTime!);
    return age < _cacheDuration;
  }

  /// Fetch flow data from TransAlta API
  ///
  /// [forceRefresh] - Bypass cache and fetch fresh data
  Future<void> fetchFlowData({bool forceRefresh = false}) async {
    // Return cached data if valid and not forcing refresh
    if (!forceRefresh && isCacheValid) {
      debugPrint(
        'TransAltaProvider: Using cached data (${cacheAgeMinutes}min old)',
      );
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('TransAltaProvider: Fetching flow data from API...');
      final data = await transAltaService.fetchFlowData(
        forceRefresh: forceRefresh,
      );

      if (data != null) {
        _flowData = data;
        _lastFetchTime = DateTime.now();
        _error = null;
        debugPrint(
          'TransAltaProvider: Successfully fetched ${data.forecasts.length} days of data',
        );
      } else {
        _error = 'Unable to fetch flow data';
        debugPrint('TransAltaProvider: API returned null');
      }
    } catch (e) {
      _error = 'Error fetching flow data: $e';
      debugPrint('TransAltaProvider: Error - $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get today's flow periods above threshold
  List<HighFlowPeriod> getTodayFlowPeriods({double threshold = 20.0}) {
    if (_flowData == null) return [];

    return _flowData!
        .getHighFlowHours(threshold: threshold)
        .where((period) => period.dayNumber == 0)
        .toList();
  }

  /// Get flow summary for today (formatted for list tile)
  String getTodayFlowSummary({double threshold = 20.0}) {
    if (_flowData == null) {
      return 'Loading...';
    }

    final todayPeriods = getTodayFlowPeriods(threshold: threshold);

    if (todayPeriods.isEmpty) {
      return 'No flow today';
    }

    // Format the periods
    if (todayPeriods.length == 1) {
      final period = todayPeriods.first;
      return '${period.arrivalTimeRange} • ${period.flowRangeString}';
    } else {
      // Multiple periods - show count
      final totalHours = todayPeriods.fold(0, (sum, p) => sum + p.totalHours);
      return '${todayPeriods.length} periods • ${totalHours}h total';
    }
  }

  /// Get current flow entry
  HourlyFlowEntry? getCurrentFlow() {
    return _flowData?.currentFlow;
  }

  /// Get all high flow periods across all forecast days
  List<HighFlowPeriod> getAllFlowPeriods({double threshold = 20.0}) {
    if (_flowData == null) return [];
    return _flowData!.getHighFlowHours(threshold: threshold);
  }

  /// Clear cached data
  void clearCache() {
    _flowData = null;
    _lastFetchTime = null;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}
