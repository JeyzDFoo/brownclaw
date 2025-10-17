import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import '../services/river_run_service.dart';
import 'river_run_search_screen.dart';
import 'river_detail_screen.dart';

class RiverLevelsScreen extends StatefulWidget {
  const RiverLevelsScreen({super.key});

  @override
  State<RiverLevelsScreen> createState() => _RiverLevelsScreenState();
}

class _RiverLevelsScreenState extends State<RiverLevelsScreen> {
  Set<String> _previousFavoriteIds = {};

  @override
  void initState() {
    super.initState();
    // Initial load will happen in build via Consumer
  }

  // Check if favorites have changed and trigger reload if needed
  void _checkAndReloadFavorites(Set<String> currentFavoriteIds) {
    if (_previousFavoriteIds.length != currentFavoriteIds.length ||
        !_previousFavoriteIds.containsAll(currentFavoriteIds)) {
      _previousFavoriteIds = Set.from(currentFavoriteIds);

      // Only reload if not already loading
      final riverRunProvider = context.read<RiverRunProvider>();
      if (!riverRunProvider.isLoading && currentFavoriteIds.isNotEmpty) {
        Future.microtask(() {
          if (mounted) {
            riverRunProvider.loadFavoriteRuns(currentFavoriteIds);
          }
        });
      }
    }
  }

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

  // 🔥 REMOVED: No more local caches or lifecycle management - providers handle everything!
  // The screen is now PURE UI - just displays what providers give us

  // 🔥 REMOVED: Old cache-based helpers - now using provider directly in build()

  /// Helper to get flow status from live data
  String _getFlowStatus(
    RiverRunWithStations runWithStations,
    LiveWaterData? liveData,
  ) {
    final discharge = liveData?.flowRate;

    if (discharge == null) {
      final stationId = runWithStations.run.stationId;
      if (stationId != null && stationId.isNotEmpty) {
        return 'Loading...';
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
      'status': _getFlowStatus(runWithStations, liveData),
    };
  }

  Future<void> _refreshData() async {
    // 🔥 OPTIMIZED: Clear cache and let providers re-fetch automatically
    if (kDebugMode) {
      print('🔄 Manual refresh requested');
    }

    // Clear the cache to force fresh data
    RiverRunProvider.clearCache();

    // Get current favorites and reload
    final favoriteIds = context.read<FavoritesProvider>().favoriteRunIds;
    if (favoriteIds.isNotEmpty) {
      await context.read<RiverRunProvider>().loadFavoriteRuns(favoriteIds);

      // Reload live data
      final runs = context.read<RiverRunProvider>().favoriteRuns;
      final stationIds = runs
          .map((r) => r.run.stationId)
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toList();

      if (stationIds.isNotEmpty && mounted) {
        await context.read<LiveWaterDataProvider>().fetchMultipleStations(
          stationIds,
        );
      }
    }

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
    // 🔥 OPTIMIZED: Consumer3 with LiveWaterDataProvider - Pure reactive pattern!
    return Consumer3<
      FavoritesProvider,
      RiverRunProvider,
      LiveWaterDataProvider
    >(
      builder: (context, favoritesProvider, riverRunProvider, liveDataProvider, child) {
        final favoriteIds = favoritesProvider.favoriteRunIds;
        final favoriteRuns = riverRunProvider.favoriteRuns;
        final isLoading = riverRunProvider.isLoading;
        final error = riverRunProvider.error;

        // Check if favorites have changed and reload if needed
        _checkAndReloadFavorites(favoriteIds);

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
                                final runId = runWithStations.run.id;

                                // 🔥 NEW: Use StreamBuilder to watch for run changes in real-time!
                                return StreamBuilder<RiverRun?>(
                                  stream: RiverRunService.watchRunById(runId),
                                  initialData: runWithStations.run,
                                  builder: (context, runSnapshot) {
                                    // Use updated run data if available, fallback to initial
                                    final updatedRun =
                                        runSnapshot.data ?? runWithStations.run;

                                    // Rebuild runWithStations with updated run data
                                    final currentRunWithStations =
                                        RiverRunWithStations(
                                          run: updatedRun,
                                          river: runWithStations.river,
                                          stations: runWithStations.stations,
                                        );

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
                                    );

                                    if (kDebugMode) {
                                      print(
                                        '🎯 Rendering ListTile for ${currentRunWithStations.run.displayName}:',
                                      );
                                      print('   Station ID: $stationId');
                                      print(
                                        '   Current Discharge: $currentDischarge',
                                      );
                                      print('   Has Live Data: $hasLiveData');
                                      print('   Flow Status: $flowStatus');
                                      if (liveData != null) {
                                        print('   Live Data: $liveData');
                                        print(
                                          '   Live Flow Rate: ${liveData.flowRate}',
                                        );
                                        print(
                                          '   Live Formatted: ${liveData.formattedFlowRate}',
                                        );
                                        print(
                                          '   Live Station Name: ${liveData.stationName}',
                                        );
                                        print(
                                          '   Live Data Source: ${liveData.dataSource}',
                                        );
                                        print(
                                          '   Live Timestamp: ${liveData.timestamp}',
                                        );
                                      }
                                      print(
                                        '   Fallback discharge from model: ${currentRunWithStations.currentDischarge}',
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
                                                          currentRunWithStations,
                                                          liveData,
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
                                          onPressed: () =>
                                              _showLogDescentDialog(
                                                _convertRunToLegacyFormat(
                                                  currentRunWithStations,
                                                  liveData,
                                                ),
                                              ),
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
                                            // 🔥 Manual refresh button - uses provider now!
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

                                                  // Use provider's fetchStationData which handles caching
                                                  await liveDataProvider
                                                      .fetchStationData(
                                                        stationId,
                                                      );

                                                  if (mounted) {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          'Station data refreshed',
                                                        ),
                                                        backgroundColor:
                                                            Colors.green,
                                                        duration: Duration(
                                                          seconds: 1,
                                                        ),
                                                      ),
                                                    );
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
                                              onPressed: () => _toggleFavorite(
                                                currentRunWithStations,
                                              ),
                                              tooltip: 'Remove from favorites',
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }, // End of StreamBuilder builder
                                ); // End of StreamBuilder
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
