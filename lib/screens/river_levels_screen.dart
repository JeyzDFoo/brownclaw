import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/river_run_service.dart';
import '../services/gauge_station_service.dart';
import '../services/user_favorites_service.dart';
import '../models/models.dart';
import 'river_run_search_screen.dart';
import 'river_detail_screen.dart';

class RiverLevelsScreen extends StatefulWidget {
  const RiverLevelsScreen({super.key});

  @override
  State<RiverLevelsScreen> createState() => _RiverLevelsScreenState();
}

class _RiverLevelsScreenState extends State<RiverLevelsScreen> {
  List<RiverRunWithStations> _favoriteRuns = [];
  List<String> _favoriteRunIds = [];
  String? _error;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  void _loadFavorites() {
    UserFavoritesService.getUserFavoriteRunIds().listen((favoriteRunIds) {
      setState(() {
        _favoriteRunIds = favoriteRunIds;
      });
      _loadFavoriteRunsData();
    });
  }

  void _loadFavoriteRunsData() async {
    if (_favoriteRunIds.isEmpty) {
      setState(() {
        _favoriteRuns = [];
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final favoriteRunsWithStations = <RiverRunWithStations>[];

      for (final runId in _favoriteRunIds) {
        final runWithStations = await RiverRunService.getRunWithStations(runId);
        if (runWithStations != null) {
          // Update live data for all stations in this run
          for (final station in runWithStations.stations) {
            await GaugeStationService.updateStationLiveData(station.stationId);
          }
          // Get updated run with fresh live data
          final updatedRunWithStations =
              await RiverRunService.getRunWithStations(runId);
          if (updatedRunWithStations != null) {
            favoriteRunsWithStations.add(updatedRunWithStations);
          }
        }
      }

      setState(() {
        _favoriteRuns = favoriteRunsWithStations;
        _error = null;
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading favorite runs data: $e');
      }
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Convert new RiverRunWithStations to legacy format for compatibility
  Map<String, dynamic> _convertRunToLegacyFormat(
    RiverRunWithStations runWithStations,
  ) {
    final primaryStation = runWithStations.primaryStation;
    final stationId = primaryStation?.stationId ?? runWithStations.run.id;

    if (kDebugMode) {
      print('🔄 Converting run to legacy format:');
      print('   Run ID: ${runWithStations.run.id}');
      print('   River Name: ${runWithStations.river?.name}');
      print('   Run Name: ${runWithStations.run.name}');
      print('   Number of Stations: ${runWithStations.stations.length}');
      if (runWithStations.stations.isNotEmpty) {
        for (int i = 0; i < runWithStations.stations.length; i++) {
          final station = runWithStations.stations[i];
          print(
            '   Station $i: ${station.stationId} (hasLiveData: ${station.hasLiveData})',
          );
        }
      }
      print('   Primary Station ID: ${primaryStation?.stationId}');
      print('   Final Station ID: $stationId');
      print('   Has Live Data: ${runWithStations.hasLiveData}');
    }

    return {
      'stationId': stationId,
      'riverName': runWithStations.river?.name ?? runWithStations.run.name,
      'section': {
        'name': runWithStations.run.name,
        'difficulty': runWithStations.run.difficultyClass,
      },
      'hasValidStation':
          primaryStation != null && primaryStation.stationId.isNotEmpty,
      'location': runWithStations.run.putIn ?? 'Unknown Location',
      'difficulty': runWithStations.run.difficultyClass,
      'minRunnable': runWithStations.run.minRecommendedFlow ?? 0.0,
      'maxSafe': runWithStations.run.maxRecommendedFlow ?? 1000.0,
      'flowRate': runWithStations.currentDischarge ?? 0.0,
      'waterLevel': runWithStations.currentWaterLevel ?? 0.0,
      'temperature': primaryStation?.currentTemperature ?? 0.0,
      'lastUpdated':
          runWithStations.lastDataUpdate?.toIso8601String() ??
          DateTime.now().toIso8601String(),
      'dataSource': runWithStations.hasLiveData ? 'live' : 'unavailable',
      'isLive': runWithStations.hasLiveData,
      'status': runWithStations.flowStatus,
    };
  }

  Future<void> _refreshData() async {
    _loadFavoriteRunsData();

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
      await UserFavoritesService.removeFavoriteRun(runWithStations.run.id);
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

                final user = FirebaseAuth.instance.currentUser;
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
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.teal),
                  )
                : _error != null
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
                          _error!,
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
                : _favoriteRuns.isEmpty
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
                      if (_favoriteRuns.isNotEmpty)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color:
                                (_favoriteRuns.first.hasLiveData
                                        ? Colors.green
                                        : Colors.orange)
                                    .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color:
                                  (_favoriteRuns.first.hasLiveData
                                          ? Colors.green
                                          : Colors.orange)
                                      .withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _favoriteRuns.first.hasLiveData
                                    ? Icons.live_tv
                                    : Icons.info_outline,
                                color: _favoriteRuns.first.hasLiveData
                                    ? Colors.green[700]
                                    : Colors.orange[700],
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _favoriteRuns.first.hasLiveData
                                      ? 'Showing live data from Environment Canada'
                                      : 'Data temporarily unavailable - please try again later',
                                  style: TextStyle(
                                    color: _favoriteRuns.first.hasLiveData
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
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _favoriteRuns.length,
                          itemBuilder: (context, index) {
                            final runWithStations = _favoriteRuns[index];
                            final currentDischarge =
                                runWithStations.currentDischarge;
                            final hasLiveData = runWithStations.hasLiveData;

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
                                      builder: (context) => RiverDetailScreen(
                                        riverData: _convertRunToLegacyFormat(
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
                                    _convertRunToLegacyFormat(runWithStations),
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${runWithStations.run.name} - ${runWithStations.run.difficultyClass}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    if (currentDischarge != null)
                                      Text(
                                        'Flow: ${currentDischarge.toStringAsFixed(2)} m³/s',
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    //  Text('Status: $status'),
                                    Row(
                                      children: [
                                        Icon(
                                          hasLiveData
                                              ? Icons.live_tv
                                              : Icons.auto_graph,
                                          size: 12,
                                          color: hasLiveData
                                              ? Colors.green
                                              : Colors.amber.shade700,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            runWithStations.lastDataUpdate
                                                    ?.toIso8601String() ??
                                                (hasLiveData
                                                    ? 'Live data'
                                                    : 'No recent data'),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: hasLiveData
                                                  ? Colors.green
                                                  : Colors.amber.shade700,
                                              fontWeight: FontWeight.bold,
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
                                    // Log descent button

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
  }
}
