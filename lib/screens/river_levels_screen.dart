import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/live_water_data_service.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import 'river_run_search_screen.dart';
import 'river_detail_screen.dart';

class RiverLevelsScreen extends StatefulWidget {
  const RiverLevelsScreen({super.key});

  @override
  State<RiverLevelsScreen> createState() => _RiverLevelsScreenState();
}

class _RiverLevelsScreenState extends State<RiverLevelsScreen> {
  // #todo: MAJOR REFACTOR NEEDED - Move all live data management to LiveWaterDataProvider
  // Currently this screen is doing too much:
  // 1. Managing API calls directly (should be in provider)
  // 2. Caching live data locally (should be in provider)
  // 3. Rate limiting logic (should be in provider)
  // 4. Deduplication logic (partially moved to service, should be fully in provider)
  // 5. Multiple concurrent refresh triggers causing API spam
  //
  // SOLUTION: Complete migration to use LiveWaterDataProvider for:
  // - Centralized caching across app
  // - Automatic deduplication of requests
  // - Rate limiting per station
  // - Reactive UI updates via ChangeNotifier
  // - Proper error state management
  //
  // This will eliminate the repeated API calls and improve performance significantly.

  Set<String> _lastFavoriteRunIds = {}; // Track the actual favorite run IDs
  Set<String> _updatingRunIds =
      {}; // Track which runs are currently updating (remove after refactor)
  Map<String, LiveWaterData> _liveDataCache =
      {}; // Temporary until provider migration (remove after refactor)

  @override
  void initState() {
    super.initState();
    // Initialize _lastFavoriteRunIds to prevent duplicate loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final favoritesProvider = context.read<FavoritesProvider>();
      _lastFavoriteRunIds = Set<String>.from(favoritesProvider.favoriteRunIds);

      // Quick test of live data service in debug mode
      if (kDebugMode) {
        _testLiveDataService();
      }
    });
  }

  /// Quick test to verify LiveWaterDataService is working
  Future<void> _testLiveDataService() async {
    if (kDebugMode) {
      print('🧪 Testing LiveWaterDataService...');
      try {
        final testResult = await LiveWaterDataService.fetchStationData(
          '08MF005',
        );
        print('🧪 Test result for 08MF005: $testResult');
        if (testResult != null) {
          print('🧪 Service is working! Flow: ${testResult.formattedFlowRate}');
        } else {
          print('🧪 Service returned null - might be network or API issue');
        }
      } catch (e) {
        print('🧪 Service test failed: $e');
      }
    }
  }

  // Update live data in background with smart rate limiting
  void _updateLiveDataInBackground(List<String> favoriteRunIds) async {
    if (favoriteRunIds.isEmpty) return;

    // Wait for the river run provider to have the runs loaded
    final riverRunProvider = context.read<RiverRunProvider>();
    if (riverRunProvider.isLoading) {
      if (kDebugMode) {
        print('🌊 Waiting for runs to load before fetching live data...');
      }
      // Wait a bit and try again
      await Future.delayed(const Duration(milliseconds: 1000));
      if (!mounted) return;

      // Check again if still loading
      if (riverRunProvider.isLoading) {
        if (kDebugMode) {
          print('🌊 Still loading runs, skipping live data update');
        }
        return;
      }
    }

    // Mark all runs as updating
    setState(() {
      _updatingRunIds = Set<String>.from(favoriteRunIds);
    });

    // Add delay to let UI settle first
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      // Collect unique station IDs directly from runs' stationId field
      final Set<String> uniqueStationIds = {};
      final currentRuns = riverRunProvider.favoriteRuns;

      if (kDebugMode) {
        print(
          '🌊 Extracting station IDs from ${currentRuns.length} loaded runs...',
        );
      }

      for (final runWithStations in currentRuns) {
        final stationId = runWithStations.run.stationId;
        if (stationId != null && stationId.isNotEmpty) {
          uniqueStationIds.add(stationId);
          if (kDebugMode) {
            print(
              '   Found station ID: $stationId for ${runWithStations.run.displayName}',
            );
          }
        }
      }

      if (uniqueStationIds.isEmpty) {
        if (kDebugMode) {
          print('🌊 No station IDs found in loaded runs');
        }
        return;
      }

      if (kDebugMode) {
        print(
          '🌊 Fetching live data for ${uniqueStationIds.length} unique stations: ${uniqueStationIds.join(", ")}',
        );
      }

      // #todo: Optimize batch processing with proper error handling per station
      // #todo: Implement retry logic for failed API calls
      // #todo: Add connection state monitoring to skip updates when offline
      // Fetch live data directly using the service
      final stationList = uniqueStationIds.toList();
      const batchSize = 3; // Process max 3 stations at a time

      for (int i = 0; i < stationList.length; i += batchSize) {
        final batch = stationList.skip(i).take(batchSize);
        final batchFutures = batch.map((stationId) async {
          try {
            final liveData = await LiveWaterDataService.fetchStationData(
              stationId,
            );
            if (liveData != null) {
              // Store live data in cache
              _liveDataCache[stationId] = liveData;
              if (kDebugMode) {
                print(
                  '✅ [UI-CACHE] Got live data for $stationId: ${liveData.formattedFlowRate} (${liveData.dataAge}) [${DateTime.now().millisecondsSinceEpoch}]',
                );
              }
            }
            return liveData;
          } catch (e) {
            if (kDebugMode) {
              print('❌ Failed to fetch live data for $stationId: $e');
            }
            return null;
          }
        });

        // Process batch and wait before next batch
        await Future.wait(batchFutures);

        // Small delay between batches to be API-friendly
        if (i + batchSize < stationList.length) {
          await Future.delayed(const Duration(milliseconds: 200));
        }
      }

      // After all updates, trigger UI refresh by calling setState
      if (mounted) {
        setState(() {
          // This will rebuild the UI with the new live data cache
        });

        if (kDebugMode) {
          print('✅ Live data updated in background');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Background live data update error: $e');
      }
    } finally {
      // Clear the updating state
      if (mounted) {
        setState(() {
          _updatingRunIds.clear();
        });
      }
    }
  }

  // Get live data for a station from cache (will be moved to provider later)
  // Updated to return LiveWaterData for type safety
  LiveWaterData? _getLiveDataForStation(String? stationId) {
    if (stationId == null || stationId.isEmpty) return null;
    return _liveDataCache[stationId];
  }

  // Get current discharge from cache or RiverRunWithStations
  double? _getCurrentDischarge(RiverRunWithStations runWithStations) {
    // If run has stationId, check cache first
    final stationId = runWithStations.run.stationId;
    if (stationId != null && stationId.isNotEmpty) {
      final liveData = _getLiveDataForStation(stationId);
      if (liveData != null && liveData.flowRate != null) {
        return liveData.flowRate;
      }
    }
    // Fallback to original logic
    return runWithStations.currentDischarge;
  }

  // Get current water level from cache or RiverRunWithStations
  double? _getCurrentWaterLevel(RiverRunWithStations runWithStations) {
    // If run has stationId, check cache first
    final stationId = runWithStations.run.stationId;
    if (stationId != null && stationId.isNotEmpty) {
      final liveData = _getLiveDataForStation(stationId);
      if (liveData != null && liveData.waterLevel != null) {
        return liveData.waterLevel;
      }
    }
    // Fallback to original logic
    return runWithStations.currentWaterLevel;
  }

  // Check if run has live data (from cache or original logic)
  bool _hasLiveData(RiverRunWithStations runWithStations) {
    // If run has stationId, check if we have cached data
    final stationId = runWithStations.run.stationId;
    if (stationId != null && stationId.isNotEmpty) {
      final liveData = _getLiveDataForStation(stationId);
      return liveData != null;
    }
    // Fallback to original logic
    return runWithStations.hasLiveData;
  }

  // Get flow status
  String _getFlowStatus(RiverRunWithStations runWithStations) {
    final discharge = _getCurrentDischarge(runWithStations);
    final hasData = _hasLiveData(runWithStations);

    if (!hasData || discharge == null) {
      final stationId = runWithStations.run.stationId;
      if (stationId != null && stationId.isNotEmpty) {
        return 'Fetching...';
      }
      return 'No data';
    }

    final minFlow = runWithStations.run.minRecommendedFlow;
    final maxFlow = runWithStations.run.maxRecommendedFlow;

    if (minFlow != null && maxFlow != null) {
      if (discharge < minFlow) {
        return 'Too Low';
      } else if (discharge > maxFlow) {
        return 'Too High';
      } else {
        return 'Runnable';
      }
    }

    return 'Live';
  }

  // Convert new RiverRunWithStations to legacy format for compatibility
  // #todo: Remove this method by updating RiverDetailScreen to accept RiverRunWithStations directly
  // This conversion exists only because RiverDetailScreen still expects Map<String, dynamic>
  // instead of typed models. Eliminating this would improve type safety and reduce mapping bugs.
  Map<String, dynamic> _convertRunToLegacyFormat(
    RiverRunWithStations runWithStations,
  ) {
    final primaryStation = runWithStations.primaryStation;
    final stationId =
        primaryStation?.stationId ?? runWithStations.run.stationId;

    if (kDebugMode) {
      print('🔄 Converting run to legacy format:');
      print('   Run ID: ${runWithStations.run.id}');
      print('   River Name: ${runWithStations.river?.name}');
      print('   Run Name: ${runWithStations.run.name}');
      print('   Run Station ID: ${runWithStations.run.stationId}');
      print('   Number of Stations: ${runWithStations.stations.length}');
      if (runWithStations.stations.isNotEmpty) {
        for (int i = 0; i < runWithStations.stations.length; i++) {
          final station = runWithStations.stations[i];
          print(
            '   Station $i: ${station.stationId} (hasLiveData: ${station.hasLiveData})',
          );
        }
      }
      print('   Primary Station: $primaryStation');
      print('   Primary Station ID: ${primaryStation?.stationId}');
      print('   Final Station ID: $stationId');
      print('   Has Live Data: ${runWithStations.hasLiveData}');

      final hasValidStation =
          stationId != null &&
          stationId.isNotEmpty &&
          RegExp(r'^[A-Z0-9]+$').hasMatch(stationId.toUpperCase());
      print(
        '   Will set hasValidStation to: $hasValidStation (based on stationId validation)',
      );
    }

    return {
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
      'flowRate': _getCurrentDischarge(runWithStations) ?? 0.0,
      'waterLevel': _getCurrentWaterLevel(runWithStations) ?? 0.0,
      'temperature': primaryStation?.currentTemperature ?? 0.0,
      'lastUpdated':
          runWithStations.lastDataUpdate?.toIso8601String() ??
          DateTime.now().toIso8601String(),
      'dataSource': _hasLiveData(runWithStations) ? 'live' : 'unavailable',
      'isLive': _hasLiveData(runWithStations),
      'status': _getFlowStatus(runWithStations),
    };
  }

  Future<void> _refreshData() async {
    final favoritesProvider = context.read<FavoritesProvider>();
    final riverRunProvider = context.read<RiverRunProvider>();

    // Force reload the favorite runs
    await riverRunProvider.loadFavoriteRuns(favoritesProvider.favoriteRunIds);

    // Update live data
    _updateLiveDataInBackground(favoritesProvider.favoriteRunIds.toList());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('River levels updated'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _toggleFavorite(RiverRunWithStations runWithStations) async {
    try {
      await context.read<FavoritesProvider>().toggleFavorite(
        runWithStations.run.id,
      );
      if (mounted) {
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

  Future<void> _showLogDescentDialog(Map<String, dynamic> river) async {
    final riverName = river['riverName'] as String? ?? 'Unknown River';
    final sectionData = river['section'];
    final sectionName = sectionData is Map
        ? (sectionData['name'] as String? ?? '')
        : (sectionData as String? ?? '');
    final sectionClass = sectionData is Map
        ? (sectionData['class'] as String? ?? 'Class II')
        : (river['difficulty'] as String? ?? 'Class II');
    final currentFlowRate = river['flowRate'] as double?;

    final riverNameController = TextEditingController(text: riverName);
    final sectionController = TextEditingController(text: sectionName);
    final notesController = TextEditingController();
    final waterLevelController = TextEditingController(
      text: currentFlowRate != null
          ? '${currentFlowRate.toStringAsFixed(1)} m³/s'
          : '',
    );

    // Ensure selectedDifficulty is one of the valid dropdown values
    final validDifficulties = [
      'Class I',
      'Class II',
      'Class III',
      'Class IV',
      'Class V',
      'Class VI',
    ];
    String selectedDifficulty = validDifficulties.contains(sectionClass)
        ? sectionClass
        : 'Class II';

    List<String> existingSections = [];
    bool isLoadingSections = true;
    String? selectedSection;

    // Load existing sections for this river
    try {
      final sectionsQuery = await FirebaseFirestore.instance
          .collection('river_descents')
          .where('riverName', isEqualTo: riverName)
          .get();

      final sections = sectionsQuery.docs
          .map((doc) {
            final sectionData = doc.data()['section'];
            if (sectionData is Map) {
              return sectionData['name'] as String?;
            } else {
              return sectionData as String?;
            }
          })
          .where((section) => section != null && section.isNotEmpty)
          .cast<String>()
          .toSet()
          .toList();

      existingSections = sections..sort();
      isLoadingSections = false;

      // Pre-select section if it exists in the list
      if (sectionName.isNotEmpty && existingSections.contains(sectionName)) {
        selectedSection = sectionName;
        sectionController.text = sectionName;
      }
    } catch (e) {
      isLoadingSections = false;
    }

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Log River Descent'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: riverNameController,
                  decoration: const InputDecoration(
                    labelText: 'River Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.water),
                  ),
                ),
                const SizedBox(height: 16),
                // Section selector with dropdown and custom input
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isLoadingSections)
                      const Row(
                        children: [
                          SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Loading sections...'),
                        ],
                      )
                    else if (existingSections.isNotEmpty) ...[
                      DropdownButtonFormField<String?>(
                        value: selectedSection,
                        decoration: const InputDecoration(
                          labelText: 'Select Existing Section',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.list),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Select a section...'),
                          ),
                          ...existingSections.map(
                            (section) => DropdownMenuItem(
                              value: section,
                              child: Text(section),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            selectedSection = value;
                            if (value != null) {
                              sectionController.text = value;
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      const Center(
                        child: Text(
                          'OR',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    TextField(
                      controller: sectionController,
                      decoration: InputDecoration(
                        labelText: existingSections.isNotEmpty
                            ? 'Add New Section/Run'
                            : 'Section/Run',
                        hintText:
                            'e.g., Upper Canyon, Lower Falls, Put-in to Take-out',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.location_on),
                      ),
                      onChanged: (value) {
                        setState(() {
                          selectedSection =
                              null; // Clear dropdown selection when typing
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedDifficulty,
                  decoration: const InputDecoration(
                    labelText: 'Difficulty Class',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.trending_up),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Class I',
                      child: Text('Class I - Easy'),
                    ),
                    DropdownMenuItem(
                      value: 'Class II',
                      child: Text('Class II - Novice'),
                    ),
                    DropdownMenuItem(
                      value: 'Class III',
                      child: Text('Class III - Intermediate'),
                    ),
                    DropdownMenuItem(
                      value: 'Class IV',
                      child: Text('Class IV - Advanced'),
                    ),
                    DropdownMenuItem(
                      value: 'Class V',
                      child: Text('Class V - Expert'),
                    ),
                    DropdownMenuItem(
                      value: 'Class VI',
                      child: Text('Class VI - Extreme'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedDifficulty = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: waterLevelController,
                  decoration: const InputDecoration(
                    labelText: 'Water Level',
                    hintText: 'e.g., 2.5 ft, Medium, High',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.height),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    hintText: 'How was your run? Any highlights or tips?',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.notes),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (riverNameController.text.trim().isEmpty ||
                    sectionController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill in river name and section'),
                    ),
                  );
                  return;
                }

                final user = context.read<UserProvider>().user;
                if (user == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please sign in to log descents'),
                    ),
                  );
                  return;
                }

                try {
                  await FirebaseFirestore.instance
                      .collection('river_descents')
                      .add({
                        'riverName': riverNameController.text.trim(),
                        'section': {
                          'name': sectionController.text.trim(),
                          'class': selectedDifficulty,
                        },
                        'difficulty': selectedDifficulty,
                        'waterLevel': waterLevelController.text.trim(),
                        'notes': notesController.text.trim(),
                        'userId': user.uid,
                        'userEmail': user.email,
                        'userName':
                            user.displayName ??
                            user.email?.split('@')[0] ??
                            'Kayaker',
                        'timestamp': FieldValue.serverTimestamp(),
                        'date': DateTime.now().toIso8601String().split('T')[0],
                      });

                  if (mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('River descent logged successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error logging descent: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Log Descent'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<FavoritesProvider, RiverRunProvider>(
      builder: (context, favoritesProvider, riverRunProvider, child) {
        // Load favorites data when needed - provider handles smart caching
        final currentFavoriteIds = favoritesProvider.favoriteRunIds;
        if (!_lastFavoriteRunIds.containsAll(currentFavoriteIds) ||
            !currentFavoriteIds.containsAll(_lastFavoriteRunIds)) {
          _lastFavoriteRunIds = Set<String>.from(currentFavoriteIds);
          // Schedule loading after the current build completes to avoid spinner flash
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await riverRunProvider.loadFavoriteRuns(currentFavoriteIds);
            // Only update live data after the runs are loaded
            if (mounted) {
              _updateLiveDataInBackground(currentFavoriteIds.toList());
            }
          });
        }

        final favoriteRuns = riverRunProvider.favoriteRuns;
        final isLoading = riverRunProvider.isLoading;
        final error = riverRunProvider.error;

        // Trigger live data fetch when runs finish loading
        if (!isLoading &&
            favoriteRuns.isNotEmpty &&
            currentFavoriteIds.isNotEmpty) {
          // Check if we need to fetch live data for these runs
          final needsLiveDataUpdate = favoriteRuns.any((run) {
            final stationId = run.run.stationId;
            return stationId != null &&
                stationId.isNotEmpty &&
                !_liveDataCache.containsKey(stationId);
          });

          if (needsLiveDataUpdate) {
            // Schedule live data update after this build cycle
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                if (kDebugMode) {
                  print(
                    '🌊 Auto-triggering live data update after runs loaded',
                  );
                }
                _updateLiveDataInBackground(currentFavoriteIds.toList());
              }
            });
          }
        }

        return Scaffold(
          body: Column(
            children: [
              // Action buttons row
              Container(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const RiverRunSearchScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Add River Runs'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _refreshData,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.teal),
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
                              style: Theme.of(context).textTheme.headlineSmall,
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
                              onPressed: _refreshData,
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
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const RiverRunSearchScreen(),
                                  ),
                                );
                              },
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
                          // Data source info banner
                          if (favoriteRuns.isNotEmpty)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.all(16),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color:
                                    (favoriteRuns.first.hasLiveData
                                            ? Colors.green
                                            : Colors.orange)
                                        .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color:
                                      (favoriteRuns.first.hasLiveData
                                              ? Colors.green
                                              : Colors.orange)
                                          .withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    favoriteRuns.first.hasLiveData
                                        ? Icons.live_tv
                                        : Icons.info_outline,
                                    color: favoriteRuns.first.hasLiveData
                                        ? Colors.green[700]
                                        : Colors.orange[700],
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      favoriteRuns.first.hasLiveData
                                          ? 'Showing live data from Environment Canada'
                                          : 'Data temporarily unavailable - please try again later',
                                      style: TextStyle(
                                        color: favoriteRuns.first.hasLiveData
                                            ? Colors.green[700]
                                            : Colors.grey[600],
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          // Rivers list
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              itemCount: favoriteRuns.length,
                              itemBuilder: (context, index) {
                                final runWithStations = favoriteRuns[index];
                                final currentDischarge = _getCurrentDischarge(
                                  runWithStations,
                                );
                                final hasLiveData = _hasLiveData(
                                  runWithStations,
                                );
                                final flowStatus = _getFlowStatus(
                                  runWithStations,
                                );
                                final stationId = runWithStations.run.stationId;

                                if (kDebugMode) {
                                  print(
                                    '🎯 Rendering ListTile for ${runWithStations.run.displayName}:',
                                  );
                                  print('   Station ID: $stationId');
                                  print(
                                    '   Current Discharge: $currentDischarge',
                                  );
                                  print('   Has Live Data: $hasLiveData');
                                  print('   Flow Status: $flowStatus');
                                  if (stationId != null) {
                                    final cachedData =
                                        _liveDataCache[stationId];
                                    print('   Cached Data: $cachedData');
                                    if (cachedData != null) {
                                      print(
                                        '   Cached Flow Rate: ${cachedData.flowRate}',
                                      );
                                      print(
                                        '   Cached Formatted: ${cachedData.formattedFlowRate}',
                                      );
                                      print(
                                        '   Cached Station Name: ${cachedData.stationName}',
                                      );
                                      print(
                                        '   Cached Data Source: ${cachedData.dataSource}',
                                      );
                                      print(
                                        '   Cached Timestamp: ${cachedData.timestamp}',
                                      );
                                    }
                                  }
                                  print(
                                    '   Fallback discharge from model: ${runWithStations.currentDischarge}',
                                  );
                                }

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: ListTile(
                                    onTap: () {
                                      if (kDebugMode) {
                                        print(
                                          '🚀 Navigating to RiverDetailScreen with run: ${runWithStations.run.displayName}',
                                        );
                                      }
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              RiverDetailScreen(
                                                riverData:
                                                    _convertRunToLegacyFormat(
                                                      runWithStations,
                                                    ),
                                              ),
                                        ),
                                      );
                                    },
                                    leading: IconButton(
                                      icon: const Icon(
                                        Icons.add,
                                        color: Colors.blue,
                                      ),
                                      onPressed: () => _showLogDescentDialog(
                                        _convertRunToLegacyFormat(
                                          runWithStations,
                                        ),
                                      ),
                                      tooltip: 'Log Descent',
                                    ),
                                    title: Text(
                                      runWithStations.river?.name ??
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
                                          '${runWithStations.run.name} - ${runWithStations.run.difficultyClass}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                              hasLiveData
                                                  ? Icons.live_tv
                                                  : Icons.info_outline,
                                              size: 14,
                                              color: hasLiveData
                                                  ? Colors.green[600]
                                                  : Colors.orange[600],
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                currentDischarge != null
                                                    ? 'Flow: ${currentDischarge.toStringAsFixed(2)} m³/s • $flowStatus'
                                                    : 'Status: $flowStatus',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: hasLiveData
                                                      ? Colors.green[700]
                                                      : Colors.grey[600],
                                                  fontWeight: hasLiveData
                                                      ? FontWeight.w500
                                                      : FontWeight.normal,
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
                                        // Mini spinner when updating live data
                                        if (_updatingRunIds.contains(
                                          runWithStations.run.id,
                                        ))
                                          Container(
                                            width: 16,
                                            height: 16,
                                            margin: const EdgeInsets.only(
                                              right: 8,
                                            ),
                                            child:
                                                const CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                        Color
                                                      >(Colors.blue),
                                                ),
                                          ),

                                        // Manual refresh button for this specific run
                                        if (stationId != null &&
                                            stationId.isNotEmpty)
                                          IconButton(
                                            icon: const Icon(
                                              Icons.refresh,
                                              color: Colors.blue,
                                              size: 20,
                                            ),
                                            onPressed: () async {
                                              if (kDebugMode) {
                                                print(
                                                  '🔄 Manual refresh for station: $stationId',
                                                );
                                              }
                                              setState(() {
                                                _updatingRunIds.add(
                                                  runWithStations.run.id,
                                                );
                                              });

                                              try {
                                                final liveData =
                                                    await LiveWaterDataService.fetchStationData(
                                                      stationId,
                                                    );
                                                if (liveData != null) {
                                                  _liveDataCache[stationId] =
                                                      liveData;
                                                  if (kDebugMode) {
                                                    print(
                                                      '✅ Manual refresh success: ${liveData.formattedFlowRate}',
                                                    );
                                                  }
                                                }
                                              } catch (e) {
                                                if (kDebugMode) {
                                                  print(
                                                    '❌ Manual refresh failed: $e',
                                                  );
                                                }
                                              } finally {
                                                setState(() {
                                                  _updatingRunIds.remove(
                                                    runWithStations.run.id,
                                                  );
                                                });
                                              }
                                            },
                                            tooltip: 'Refresh live data',
                                          ),

                                        // Remove from favorites button
                                        IconButton(
                                          icon: const Icon(
                                            Icons.favorite,
                                            color: Colors.red,
                                          ),
                                          onPressed: () =>
                                              _toggleFavorite(runWithStations),
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
        );
      },
    );
  }
}
