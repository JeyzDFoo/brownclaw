import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import '../services/analytics_service.dart';
import '../utils/performance_logger.dart';
import 'river_run_search_screen.dart';
import 'river_detail_screen.dart';
import 'logbook_entry_screen.dart';

class FavouritesScreen extends StatefulWidget {
  final VoidCallback? onNavigateToSearch;

  const FavouritesScreen({super.key, this.onNavigateToSearch});

  @override
  State<FavouritesScreen> createState() => _FavouritesScreenState();
}

class _FavouritesScreenState extends State<FavouritesScreen>
    with AutomaticKeepAliveClientMixin {
  Set<String> _previousFavoriteIds = {};
  bool _hasInitializedTransAlta = false;
  bool _isPostFrameCallbackScheduled =
      false; // Track if callback is already scheduled

  @override
  bool get wantKeepAlive => true; // Keep state alive when navigating away

  @override
  void initState() {
    super.initState();
    PerformanceLogger.log('favourites_screen_init_state');
    // Initial load will happen in build via Consumer
  }

  // Check if favorites have changed and trigger reload if needed
  void _checkAndReloadFavorites(
    Set<String> currentFavoriteIds,
    RiverRunProvider riverRunProvider,
    LiveWaterDataProvider liveDataProvider,
  ) {
    if (_previousFavoriteIds.length != currentFavoriteIds.length ||
        !_previousFavoriteIds.containsAll(currentFavoriteIds)) {
      PerformanceLogger.log(
        'favourites_loading_started',
        detail: '${currentFavoriteIds.length} favorites',
      );

      _previousFavoriteIds = Set.from(currentFavoriteIds);

      // 🔥 STALE-WHILE-REVALIDATE: Fire and forget - don't await!
      // UI shows immediately with cached data, updates when fresh data arrives
      if (currentFavoriteIds.isNotEmpty) {
        Future.microtask(() async {
          if (mounted) {
            await riverRunProvider.loadFavoriteRuns(currentFavoriteIds);
            PerformanceLogger.log('favourites_runs_loaded');

            // After loading runs, fetch live data for the stations IN BACKGROUND
            final runs = riverRunProvider.favoriteRuns;
            final stationIds = runs
                .map((r) => r.run.stationId)
                .whereType<String>()
                .where((id) => id.isNotEmpty)
                .toList();

            if (stationIds.isNotEmpty && mounted) {
              // 🔥 DON'T AWAIT - Let it update in background
              // Provider will notifyListeners() when data arrives
              liveDataProvider.fetchMultipleStations(stationIds).then((_) {
                if (mounted) {
                  PerformanceLogger.log('favourites_live_data_loaded');
                }
              });
            }
          }
        });
      }
    }
  }

  // ✅ REFACTOR COMPLETE: All live data management now handled by LiveWaterDataProvider
  // This screen is now a pure UI layer that:
  // - Uses Consumer4 to reactively get data from providers
  // - Gets cached live data via liveDataProvider.getLiveData()
  // - Triggers fetches via liveDataProvider.fetchStationData()
  // - No local state for API management, caching, or rate limiting
  // All data logic properly separated into provider layer for better testability and reuse.

  /// Helper to get flow status from live data
  String _getFlowStatus(
    RiverRunWithStations runWithStations,
    LiveWaterData? liveData,
    LiveWaterDataProvider liveDataProvider,
  ) {
    final discharge = liveData?.flowRate;

    if (discharge == null) {
      final stationId = runWithStations.run.stationId;
      if (stationId != null && stationId.isNotEmpty) {
        // 🔥 STALE-WHILE-REVALIDATE: Only show "Loading..." if actively fetching
        // Otherwise show "No Data" - data will update when it arrives
        if (liveDataProvider.isUpdating(stationId)) {
          return 'Loading...';
        }
        // Check if there's an error
        final error = liveDataProvider.getError(stationId);
        if (error != null) {
          return 'Error';
        }
      }
      return 'No Data';
    }

    final minFlow = runWithStations.run.minRecommendedFlow;
    final maxFlow = runWithStations.run.maxRecommendedFlow;

    if (minFlow != null && maxFlow != null) {
      if (discharge < minFlow) {
        return 'Too Low';
      } else if (discharge > maxFlow) {
        return 'Too High';
      } else {
        return 'Runnable ✓';
      }
    }

    return 'Live';
  }

  /// Helper to check if we have live data
  bool _hasLiveData(
    RiverRunWithStations runWithStations,
    LiveWaterData? liveData,
  ) {
    return liveData != null && liveData.flowRate != null;
  }

  /// Helper to get current discharge from live data
  double? _getCurrentDischarge(
    RiverRunWithStations runWithStations,
    LiveWaterData? liveData,
  ) {
    return liveData?.flowRate ?? runWithStations.currentDischarge;
  }

  /// Helper to check if this is a Kananaskis river
  bool _isKananaskis(RiverRunWithStations runWithStations) {
    final riverName = runWithStations.river?.name ?? '';
    return riverName.toLowerCase().contains('kananaskis');
  }

  /// Helper to get today's Kananaskis flow summary from TransAlta provider
  String _getKananaskisFlowSummary(TransAltaProvider transAltaProvider) {
    if (transAltaProvider.isLoading) {
      return 'Loading...';
    }

    if (transAltaProvider.error != null) {
      return 'Flow data error';
    }

    if (!transAltaProvider.hasData) {
      return 'Flow data unavailable';
    }

    return transAltaProvider.getTodayFlowSummary(threshold: 20.0);
  }

  /// Helper to get current water level from live data
  double? _getCurrentWaterLevel(
    RiverRunWithStations runWithStations,
    LiveWaterData? liveData,
  ) {
    return liveData?.waterLevel;
  }

  // Convert new RiverRunWithStations to legacy format for compatibility
  // #todo: Remove this method by updating RiverDetailScreen to accept RiverRunWithStations directly
  // This conversion exists only because RiverDetailScreen still expects Map<String, dynamic>
  // instead of typed models. Eliminating this would improve type safety and reduce mapping bugs.
  Map<String, dynamic> _convertRunToLegacyFormat(
    RiverRunWithStations runWithStations,
    LiveWaterData? liveData,
    LiveWaterDataProvider liveDataProvider,
  ) {
    final primaryStation = runWithStations.primaryStation;
    final stationId =
        primaryStation?.stationId ?? runWithStations.run.stationId;

    return {
      'runId': runWithStations.run.id, // Add runId for Firestore stream
      'stationId': stationId,
      'riverName': runWithStations.river?.name ?? runWithStations.run.name,
      'section': {
        'name': runWithStations.run.name,
        'difficulty': runWithStations.run.difficultyClass,
      },
      'hasValidStation':
          stationId != null &&
          stationId.isNotEmpty &&
          RegExp(r'^[A-Z0-9]+$').hasMatch(stationId.toUpperCase()),
      'location': runWithStations.run.putIn ?? 'Unknown Location',
      'difficulty': runWithStations.run.difficultyClass,
      'minRunnable': runWithStations.run.minRecommendedFlow ?? 0.0,
      'maxSafe': runWithStations.run.maxRecommendedFlow ?? 1000.0,
      'flowRate': _getCurrentDischarge(runWithStations, liveData) ?? 0.0,
      'waterLevel': _getCurrentWaterLevel(runWithStations, liveData) ?? 0.0,
      'temperature': primaryStation?.currentTemperature ?? 0.0,
      'lastUpdated':
          runWithStations.lastDataUpdate?.toIso8601String() ??
          DateTime.now().toIso8601String(),
      'dataSource': _hasLiveData(runWithStations, liveData)
          ? 'live'
          : 'unavailable',
      'isLive': _hasLiveData(runWithStations, liveData),
      'status': _getFlowStatus(runWithStations, liveData, liveDataProvider),
    };
  }

  Future<void> _retryLoad() async {
    // Clear error state and cache to trigger fresh reload
    context.read<RiverRunProvider>().clearCache();
    context.read<RiverRunProvider>().clearError();

    // Reset previous favorites to force reload
    _previousFavoriteIds.clear();

    // The rebuild will trigger _checkAndReloadFavorites automatically
    setState(() {});
  }

  Future<void> _toggleFavorite(RiverRunWithStations runWithStations) async {
    try {
      await context.read<FavoritesProvider>().toggleFavorite(
        runWithStations.run.id,
      );

      // Log favorite removal
      await AnalyticsService.logFavoriteRemoved(
        runWithStations.run.id,
        runWithStations.run.displayName,
      );

      // Reload favorites list after toggling
      final favoriteIds = context.read<FavoritesProvider>().favoriteRunIds;
      if (mounted) {
        await context.read<RiverRunProvider>().loadFavoriteRuns(favoriteIds);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${runWithStations.run.displayName} removed from favorites',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating favorites: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    // 🔥 OPTIMIZED: Consumer4 with LiveWaterDataProvider and TransAltaProvider - Pure reactive pattern!
    return Consumer4<
      FavoritesProvider,
      RiverRunProvider,
      LiveWaterDataProvider,
      TransAltaProvider
    >(
      builder:
          (
            context,
            favoritesProvider,
            riverRunProvider,
            liveDataProvider,
            transAltaProvider,
            child,
          ) {
            final favoriteIds = favoritesProvider.favoriteRunIds;
            final favoriteRuns = riverRunProvider.favoriteRuns;
            final isLoading = riverRunProvider.isLoading;
            final error = riverRunProvider.error;

            // Check if favorites have changed and reload if needed
            // Only schedule callback if favorites actually changed AND callback not already scheduled
            final favoritesChanged =
                _previousFavoriteIds.length != favoriteIds.length ||
                !_previousFavoriteIds.containsAll(favoriteIds);

            if (favoritesChanged && !_isPostFrameCallbackScheduled) {
              _isPostFrameCallbackScheduled = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _isPostFrameCallbackScheduled = false; // Reset for next change
                _checkAndReloadFavorites(
                  favoriteIds,
                  riverRunProvider,
                  liveDataProvider,
                );
              });
            }

            // Fetch TransAlta data once if we have any Kananaskis rivers in favorites
            if (!_hasInitializedTransAlta &&
                favoriteRuns.any((run) => _isKananaskis(run))) {
              if (!transAltaProvider.hasData && !transAltaProvider.isLoading) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!_hasInitializedTransAlta && mounted) {
                    _hasInitializedTransAlta = true;
                    transAltaProvider.fetchFlowData();
                  }
                });
              }
            }

            return Scaffold(
              body: Column(
                children: [
                  Expanded(
                    child: isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Colors.teal,
                            ),
                          )
                        : error != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 64,
                                  color: Colors.red[300],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Error loading data',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineSmall,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  error,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: Colors.grey[600]),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: _retryLoad,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Retry'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : favoriteRuns.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.favorite_border,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No Favorite River Runs Yet',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Add favorite river runs to see live flow data here',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  onPressed: widget.onNavigateToSearch,
                                  icon: const Icon(Icons.search),
                                  label: const Text('Find River Runs'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            children: [
                              // Rivers list
                              Expanded(
                                child: ListView.builder(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  itemCount: favoriteRuns.length,
                                  itemBuilder: (context, index) {
                                    final runWithStations = favoriteRuns[index];

                                    // 🔥 STALE-WHILE-REVALIDATE: Use cached data directly from provider
                                    // Consumer4 rebuilds when riverRunProvider updates, giving us fresh data
                                    // No need for StreamBuilder - it bypasses cache and creates unnecessary Firestore listeners
                                    final currentRunWithStations =
                                        runWithStations;

                                    final stationId =
                                        currentRunWithStations.run.stationId;

                                    // 🔥 Get live data from provider (cached)
                                    final liveData = stationId != null
                                        ? liveDataProvider.getLiveData(
                                            stationId,
                                          )
                                        : null;

                                    final currentDischarge =
                                        _getCurrentDischarge(
                                          currentRunWithStations,
                                          liveData,
                                        );
                                    final hasLiveData = _hasLiveData(
                                      currentRunWithStations,
                                      liveData,
                                    );
                                    final flowStatus = _getFlowStatus(
                                      currentRunWithStations,
                                      liveData,
                                      liveDataProvider,
                                    );

                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      child: ListTile(
                                        onTap: () async {
                                          // Log river detail view from favorites
                                          await AnalyticsService.logRiverRunViewed(
                                            runWithStations.run.id,
                                            runWithStations.run.displayName,
                                          );

                                          if (kDebugMode) {
                                            print(
                                              '🚀 Navigating to RiverDetailScreen with run: ${runWithStations.run.displayName}',
                                            );
                                          }
                                          await Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  RiverDetailScreen(
                                                    riverData:
                                                        _convertRunToLegacyFormat(
                                                          currentRunWithStations,
                                                          liveData,
                                                          liveDataProvider,
                                                        ),
                                                  ),
                                            ),
                                          );

                                          // Refresh favorites when returning in case run was edited or deleted
                                          if (mounted) {
                                            final favoritesProvider = context
                                                .read<FavoritesProvider>();
                                            final riverRunProvider = context
                                                .read<RiverRunProvider>();
                                            final liveDataProvider = context
                                                .read<LiveWaterDataProvider>();

                                            // Reload favorites
                                            final favoriteIds =
                                                favoritesProvider
                                                    .favoriteRunIds;
                                            if (favoriteIds.isNotEmpty) {
                                              await riverRunProvider
                                                  .loadFavoriteRuns(
                                                    favoriteIds,
                                                  );

                                              // Refresh live data for stations
                                              final runs =
                                                  riverRunProvider.favoriteRuns;
                                              final stationIds = runs
                                                  .map((r) => r.run.stationId)
                                                  .whereType<String>()
                                                  .where((id) => id.isNotEmpty)
                                                  .toList();

                                              if (stationIds.isNotEmpty) {
                                                await liveDataProvider
                                                    .fetchMultipleStations(
                                                      stationIds,
                                                    );
                                              }
                                            }
                                          }
                                        },
                                        leading: IconButton(
                                          icon: const Icon(
                                            Icons.add,
                                            color: Colors.blue,
                                          ),
                                          onPressed: () {
                                            // Log logbook entry creation from favorites
                                            AnalyticsService.logLogbookEntryCreated(
                                              currentRunWithStations
                                                  .run
                                                  .displayName,
                                            );

                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    LogbookEntryScreen(
                                                      prefilledRun:
                                                          currentRunWithStations,
                                                    ),
                                              ),
                                            );
                                          },
                                          tooltip: 'Log Descent',
                                        ),
                                        title: Text(
                                          currentRunWithStations.river?.name ??
                                              'Unknown River',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${currentRunWithStations.run.name} - ${currentRunWithStations.run.difficultyClass}',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            // Show Kananaskis-specific flow info or regular flow info
                                            _isKananaskis(
                                                  currentRunWithStations,
                                                )
                                                ? Builder(
                                                    builder: (context) {
                                                      final flowInfo =
                                                          _getKananaskisFlowSummary(
                                                            transAltaProvider,
                                                          );
                                                      final hasFlowToday =
                                                          !flowInfo.contains(
                                                            'No flow',
                                                          ) &&
                                                          !flowInfo.contains(
                                                            'unavailable',
                                                          ) &&
                                                          !flowInfo.contains(
                                                            'error',
                                                          ) &&
                                                          !flowInfo.contains(
                                                            'Loading',
                                                          );

                                                      return Row(
                                                        children: [
                                                          Icon(
                                                            Icons.water_drop,
                                                            size: 14,
                                                            color: hasFlowToday
                                                                ? Colors
                                                                      .blue[600]
                                                                : Colors
                                                                      .grey[600],
                                                          ),
                                                          const SizedBox(
                                                            width: 6,
                                                          ),
                                                          Expanded(
                                                            child: Text(
                                                              'Today: $flowInfo',
                                                              style: TextStyle(
                                                                fontSize: 13,
                                                                color:
                                                                    hasFlowToday
                                                                    ? Colors
                                                                          .blue[700]
                                                                    : Colors
                                                                          .grey[600],
                                                                fontWeight:
                                                                    hasFlowToday
                                                                    ? FontWeight
                                                                          .w500
                                                                    : FontWeight
                                                                          .normal,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      );
                                                    },
                                                  )
                                                : Row(
                                                    children: [
                                                      Icon(
                                                        hasLiveData
                                                            ? Icons.live_tv
                                                            : Icons
                                                                  .info_outline,
                                                        size: 14,
                                                        color: hasLiveData
                                                            ? Colors.green[600]
                                                            : Colors
                                                                  .orange[600],
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Expanded(
                                                        child: Text(
                                                          currentDischarge !=
                                                                  null
                                                              ? 'Flow: ${currentDischarge.toStringAsFixed(2)} m³/s • $flowStatus'
                                                              : 'Status: $flowStatus',
                                                          style: TextStyle(
                                                            fontSize: 13,
                                                            color: hasLiveData
                                                                ? Colors
                                                                      .green[700]
                                                                : Colors
                                                                      .grey[600],
                                                            fontWeight:
                                                                hasLiveData
                                                                ? FontWeight
                                                                      .w500
                                                                : FontWeight
                                                                      .normal,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                          ],
                                        ),

                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // Remove from favorites button
                                            IconButton(
                                              icon: const Icon(
                                                Icons.favorite,
                                                color: Colors.red,
                                              ),
                                              onPressed: () => _toggleFavorite(
                                                currentRunWithStations,
                                              ),
                                              tooltip: 'Remove from favorites',
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
              floatingActionButton: FloatingActionButton.extended(
                heroTag: 'favourites_fab',
                onPressed: () {
                  if (widget.onNavigateToSearch != null) {
                    widget.onNavigateToSearch!();
                  } else {
                    // Fallback to navigation if callback not provided
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const RiverRunSearchScreen(),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Favourite'),
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
            );
          },
    );
  }
}
