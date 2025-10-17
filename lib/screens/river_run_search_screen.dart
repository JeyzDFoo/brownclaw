import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/river_run_service.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import 'create_river_run_screen.dart';
import 'river_detail_screen.dart';
import 'logbook_entry_screen.dart';

class RiverRunSearchScreen extends StatefulWidget {
  const RiverRunSearchScreen({super.key});

  @override
  State<RiverRunSearchScreen> createState() => _RiverRunSearchScreenState();
}

class _RiverRunSearchScreenState extends State<RiverRunSearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<RiverRunWithStations> _riverRuns = [];
  List<RiverRunWithStations> _filteredRuns = [];
  bool _isLoading = false;
  String _selectedDifficulty = 'All Difficulties';
  String _selectedRegion = 'All Regions';

  List<String> _availableDifficulties = ['All Difficulties'];
  List<String> _availableRegions = ['All Regions'];

  // Convert RiverRunWithStations to legacy format for RiverDetailScreen
  Map<String, dynamic> _convertRunToLegacyFormat(
    RiverRunWithStations runWithStations,
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

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Load all runs (including those without live data)
      final allRuns = await RiverRunService.getAllRunsWithStations().first;

      setState(() {
        _riverRuns = allRuns;
        _filteredRuns = allRuns;
      });

      // Load all difficulty classes
      final difficulties = await RiverRunService.getAllDifficultyClasses();
      setState(() {
        _availableDifficulties = ['All Difficulties', ...difficulties];
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading river runs: $e')));
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged() {
    if (_searchController.text.length < 2 &&
        _searchController.text.isNotEmpty) {
      return; // Don't search for single characters
    }
    _filterRuns();
  }

  void _filterRuns() {
    final query = _searchController.text.toLowerCase();
    final filteredRuns = _riverRuns.where((runWithStations) {
      // Filter by search query
      final matchesQuery =
          query.isEmpty ||
          runWithStations.run.name.toLowerCase().contains(query) ||
          (runWithStations.river?.name.toLowerCase().contains(query) ?? false);

      // Filter by difficulty
      final matchesDifficulty =
          _selectedDifficulty == 'All Difficulties' ||
          runWithStations.run.difficultyClass == _selectedDifficulty;

      // Filter by region (if we have river info)
      final matchesRegion =
          _selectedRegion == 'All Regions' ||
          (runWithStations.river?.region == _selectedRegion);

      return matchesQuery && matchesDifficulty && matchesRegion;
    }).toList();

    setState(() {
      _filteredRuns = filteredRuns;
    });
  }

  Future<void> _toggleFavorite(RiverRunWithStations runWithStations) async {
    try {
      // Use FavoritesProvider for automatic UI updates
      await context.read<FavoritesProvider>().toggleFavorite(
        runWithStations.run.id,
      );

      final isFavorite = context.read<FavoritesProvider>().isFavorite(
        runWithStations.run.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isFavorite
                  ? '${runWithStations.run.displayName} added to favorites'
                  : '${runWithStations.run.displayName} removed from favorites',
            ),
            backgroundColor: isFavorite ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating favorites: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Search and filter section
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search bar
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search river runs...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                // Filter dropdowns
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedDifficulty,
                        decoration: const InputDecoration(
                          labelText: 'Difficulty',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: _availableDifficulties.map((difficulty) {
                          return DropdownMenuItem(
                            value: difficulty,
                            child: Text(difficulty),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedDifficulty = value ?? 'All Difficulties';
                          });
                          _filterRuns();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedRegion,
                        decoration: const InputDecoration(
                          labelText: 'Region',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: _availableRegions.map((region) {
                          return DropdownMenuItem(
                            value: region,
                            child: Text(region),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedRegion = value ?? 'All Regions';
                          });
                          _filterRuns();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Results section
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredRuns.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.kayaking, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          _searchController.text.isNotEmpty
                              ? 'No runs match your search'
                              : 'No river runs available',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (_searchController.text.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              _searchController.clear();
                              _filterRuns();
                            },
                            child: const Text('Clear search'),
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredRuns.length,
                    itemBuilder: (context, index) {
                      final runWithStations = _filteredRuns[index];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: IconButton(
                            icon: const Icon(Icons.add, color: Colors.blue),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => LogbookEntryScreen(
                                    prefilledRun: runWithStations,
                                  ),
                                ),
                              );
                            },
                            tooltip: 'Log Descent',
                          ),
                          title: Text(
                            runWithStations.river?.name ?? 'Unknown River',
                            style: const TextStyle(fontWeight: FontWeight.bold),
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
                              if (runWithStations.river?.region != null)
                                Text(
                                  runWithStations.river!.region,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              if (runWithStations.run.description != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  runWithStations.run.description!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    runWithStations.hasLiveData
                                        ? Icons.wifi
                                        : Icons.wifi_off,
                                    size: 16,
                                    color: runWithStations.hasLiveData
                                        ? Colors.green
                                        : Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    runWithStations.hasLiveData
                                        ? 'Live data available'
                                        : 'No live data',
                                    style: TextStyle(
                                      color: runWithStations.hasLiveData
                                          ? Colors.green
                                          : Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (runWithStations.currentDischarge !=
                                      null) ...[
                                    const SizedBox(width: 12),
                                    Text(
                                      '${runWithStations.currentDischarge!.toStringAsFixed(1)} m³/s',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                          trailing: Consumer<FavoritesProvider>(
                            builder: (context, favoritesProvider, child) {
                              final isFavorite = favoritesProvider.isFavorite(
                                runWithStations.run.id,
                              );

                              return IconButton(
                                icon: Icon(
                                  isFavorite
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: isFavorite ? Colors.red : Colors.grey,
                                ),
                                onPressed: () =>
                                    _toggleFavorite(runWithStations),
                              );
                            },
                          ),
                          onTap: () {
                            // Navigate to the same detail screen used in favorites
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
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (context) => const CreateRiverRunScreen(),
            ),
          );

          // If a new run was created, refresh the data
          if (result == true) {
            _loadInitialData();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Create New Run'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
    );
  }
}
