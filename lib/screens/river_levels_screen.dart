import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/live_water_data_service.dart';
import '../services/favorite_rivers_service.dart';
import 'station_search_screen.dart';
import 'river_detail_screen.dart';

class RiverLevelsScreen extends StatefulWidget {
  const RiverLevelsScreen({super.key});

  @override
  State<RiverLevelsScreen> createState() => _RiverLevelsScreenState();
}

class _RiverLevelsScreenState extends State<RiverLevelsScreen> {
  List<Map<String, dynamic>> _rivers = [];
  List<String> _favoriteStationIds = [];
  String? _error;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  void _loadFavorites() {
    FavoriteRiversService.getFavoriteRiversDetails().listen((favoriteDetails) {
      setState(() {
        _favoriteStationIds = favoriteDetails
            .map((r) => r['stationId'] as String)
            .toList();
      });
      // Reload river data when favorites change with the original names
      _loadRiverData(favoriteDetails);
    });
  }

  void _loadRiverData([List<Map<String, dynamic>>? favoriteDetails]) async {
    if (_favoriteStationIds.isEmpty) {
      setState(() {
        _rivers = [];
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Get live data for all favorite stations
      final liveDataResults = <Map<String, dynamic>>[];

      for (final stationId in _favoriteStationIds) {
        // Find the original favorite details for this station
        final originalDetails = favoriteDetails?.firstWhere(
          (detail) => detail['stationId'] == stationId,
          orElse: () => <String, dynamic>{},
        );

        // Get live data for this station
        final liveData = await LiveWaterDataService.fetchStationData(stationId);

        // Create merged data using original name from favorites
        final mergedData = <String, dynamic>{
          'stationId': stationId,
          'riverName': originalDetails?['name'] ?? 'Unknown River',
          'section': originalDetails?['section'] ?? '',
          'location': originalDetails?['location'] ?? 'Unknown Location',
          'difficulty': originalDetails?['difficulty'] ?? 'Unknown',
          'minRunnable': originalDetails?['minRunnable'],
          'maxSafe': originalDetails?['maxSafe'],
          // Live data
          'flowRate': liveData?['flowRate'] ?? 0.0,
          'waterLevel': liveData?['waterLevel'] ?? 0.0,
          'temperature': liveData?['temperature'] ?? 0.0,
          'lastUpdated':
              liveData?['lastUpdated'] ?? DateTime.now().toIso8601String(),
          'dataSource': liveData != null ? 'live' : 'unavailable',
          'isLive': liveData != null,
          'status': _determineStatus(
            liveData?['flowRate'] ?? 0.0,
            originalDetails?['minRunnable'],
            originalDetails?['maxSafe'],
          ),
        };

        liveDataResults.add(mergedData);
      }

      setState(() {
        _rivers = liveDataResults;
        _error = null;
      });
    } catch (e) {
      print('❌ Error loading river data: $e');
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _determineStatus(
    double flowRate,
    dynamic minRunnable,
    dynamic maxSafe,
  ) {
    if (minRunnable == null || maxSafe == null) {
      return 'Unknown';
    }

    final min = (minRunnable as num).toDouble();
    final max = (maxSafe as num).toDouble();

    if (flowRate < min) {
      return 'Too Low';
    } else if (flowRate > max) {
      return 'Too High';
    } else {
      return 'Runnable';
    }
  }

  Future<void> _refreshData() async {
    // Get the current favorite details to preserve names
    final favoriteDetails =
        await FavoriteRiversService.getFavoriteRiversDetails().first;
    _loadRiverData(favoriteDetails);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('River levels updated'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _toggleFavorite(Map<String, dynamic> river) async {
    final stationId =
        river['stationId'] as String? ?? river['id'] as String? ?? '';

    if (stationId.isEmpty) {
      print('❌ Error: No station ID found in river data: $river');
      return;
    }

    try {
      await FavoriteRiversService.removeFavorite(stationId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${river['riverName']} removed from favorites'),
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
    final section = river['section'] as String? ?? '';
    final difficulty = river['difficulty'] as String? ?? 'Class II';
    final currentFlowRate = river['flowRate'] as double?;

    final riverNameController = TextEditingController(text: riverName);
    final sectionController = TextEditingController(text: section);
    final notesController = TextEditingController();
    final waterLevelController = TextEditingController(
      text: currentFlowRate != null
          ? '${currentFlowRate.toStringAsFixed(1)} m³/s'
          : '',
    );

    String selectedDifficulty = difficulty;

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
                TextField(
                  controller: sectionController,
                  decoration: const InputDecoration(
                    labelText: 'Section/Run',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on),
                  ),
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
                        'section': sectionController.text.trim(),
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
                        builder: (context) => const StationSearchScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Add Stations'),
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
                : _rivers.isEmpty
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
                          'No Favorite Stations Yet',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add water stations to see live data here',
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
                                    const StationSearchScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.search),
                          label: const Text('Find Stations'),
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
                      if (_rivers.isNotEmpty)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color:
                                (_rivers.first['dataSource'] == 'live'
                                        ? Colors.green
                                        : Colors.orange)
                                    .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color:
                                  (_rivers.first['dataSource'] == 'live'
                                          ? Colors.green
                                          : Colors.orange)
                                      .withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _rivers.first['dataSource'] == 'live'
                                    ? Icons.live_tv
                                    : Icons.info_outline,
                                color: _rivers.first['dataSource'] == 'live'
                                    ? Colors.green[700]
                                    : Colors.orange[700],
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _rivers.first['dataSource'] == 'live'
                                      ? 'Showing live data from Environment Canada'
                                      : 'Data temporarily unavailable - please try again later',
                                  style: TextStyle(
                                    color: _rivers.first['dataSource'] == 'live'
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
                          itemCount: _rivers.length,
                          itemBuilder: (context, index) {
                            final river = _rivers[index];
                            final flowRate = river['flowRate'] as double?;
                            final status =
                                river['status'] as String? ?? 'unknown';
                            final dataSource =
                                river['dataSource'] as String? ?? 'unknown';

                            Color statusColor =
                                river['statusColor'] as Color? ?? Colors.grey;
                            IconData statusIcon;

                            switch (status.toLowerCase()) {
                              case 'too low':
                                statusIcon = Icons.trending_down;
                                break;
                              case 'low':
                                statusIcon = Icons.trending_down;
                                break;
                              case 'good':
                                statusIcon = Icons.check_circle;
                                break;
                              case 'high':
                                statusIcon = Icons.trending_up;
                                break;
                              case 'too high':
                                statusIcon = Icons.trending_up;
                                break;
                              default:
                                statusIcon = Icons.help_outline;
                            }

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          RiverDetailScreen(riverData: river),
                                    ),
                                  );
                                },
                                leading: IconButton(
                                  icon: const Icon(
                                    Icons.add,
                                    color: Colors.blue,
                                  ),
                                  onPressed: () => _showLogDescentDialog(river),
                                  tooltip: 'Log Descent',
                                ),
                                title: Text(
                                  river['riverName'] as String? ??
                                      'Unknown River',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Text(
                                    //   river['stationName'] as String? ??
                                    //       'Unknown Station',
                                    //   style: const TextStyle(fontSize: 13),
                                    // ),
                                    //   Text('Province: ${river['province']}'),
                                    if (flowRate != null)
                                      Text(
                                        'Flow: ${flowRate.toStringAsFixed(2)} m³/s',
                                      ),
                                    //  Text('Status: $status'),
                                    Row(
                                      children: [
                                        Icon(
                                          dataSource == 'live'
                                              ? Icons.live_tv
                                              : Icons.auto_graph,
                                          size: 12,
                                          color: dataSource == 'live'
                                              ? Colors.green
                                              : Colors.amber.shade700,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            river['lastUpdate'] as String? ??
                                                (dataSource == 'live'
                                                    ? 'Live data'
                                                    : 'Simulated data'),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: dataSource == 'live'
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
                                      onPressed: () => _toggleFavorite(river),
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
