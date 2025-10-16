import 'package:flutter/material.dart';
import '../services/firestore_station_service.dart';
import '../services/user_favorites_service.dart';
import '../services/river_run_service.dart';

class StationSearchScreen extends StatefulWidget {
  const StationSearchScreen({super.key});

  @override
  State<StationSearchScreen> createState() => _StationSearchScreenState();
}

class _StationSearchScreenState extends State<StationSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FirestoreStationService _stationService = FirestoreStationService();

  List<StationModel> _stations = [];
  List<StationModel> _filteredStations = [];
  Map<String, Map<String, dynamic>> _riverData = {};
  Set<String> _favoriteStationIds = {};
  bool _isLoading = false;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _loadFavorites();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    // Cancel any active queries when navigating away
    _stationService.cancelActiveQueries();
    super.dispose();
  }

  void _loadInitialData() async {
    // Prevent multiple concurrent loads
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Load stations from Firestore with better error handling
      final stations = await _stationService.getAllStations();
      if (mounted) {
        setState(() {
          _stations = stations;
          _filteredStations = stations;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading initial data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading stations: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _loadFavorites() {
    UserFavoritesService.getUserFavoriteStationIds().listen((
      favoriteStationIds,
    ) {
      setState(() {
        _favoriteStationIds = favoriteStationIds.toSet();
      });
    });
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _filteredStations = _stations;
        _isSearching = false;
      });
      return;
    }

    _performSearch(query);
  }

  void _performSearch(String query) async {
    setState(() {
      _isSearching = true;
    });

    try {
      final results = await _stationService.searchStationsByName(query);
      if (mounted) {
        _filteredStations = results;
      }
    } catch (e) {
      print('❌ Error searching stations: $e');
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  Future<void> _toggleFavorite(String stationId) async {
    final station = _filteredStations.firstWhere((s) => s.id == stationId);

    try {
      if (_favoriteStationIds.contains(stationId)) {
        await UserFavoritesService.removeFavoriteByStationId(stationId);
        // setState will be updated by the stream listener
      } else {
        // Create a river run from station data and add to favorites
        final runId = await RiverRunService.createRunFromStationData(
          stationId,
          station.name,
        );
        await UserFavoritesService.addFavoriteRun(runId);
        // setState will be updated by the stream listener
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

  void _showStationDetailsDialog(Map<String, dynamic> stationData) {
    final flowRate = stationData['flowRate'] as double?;
    final dataSource = stationData['dataSource'] as String? ?? 'unknown';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(stationData['riverName'] as String),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                stationData['stationName'] as String,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('Station ID: ${stationData['stationId']}'),
              Text('Province: ${stationData['province']}'),
              const SizedBox(height: 12),
              if (flowRate != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Flow Rate: ${flowRate.toStringAsFixed(2)} m³/s',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text('Status: ${stationData['status']}'),
                      Text(
                        'Data: ${dataSource == 'live' ? 'Live' : 'Unavailable'}',
                        style: TextStyle(
                          color: dataSource == 'live'
                              ? Colors.green
                              : Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _toggleFavorite(stationData['stationId'] as String);
            },
            icon: Icon(
              _favoriteStationIds.contains(stationData['stationId'])
                  ? Icons.favorite
                  : Icons.favorite_border,
            ),
            label: Text(
              _favoriteStationIds.contains(stationData['stationId'])
                  ? 'Remove Favorite'
                  : 'Add Favorite',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(StationModel station) {
    final riverData = _riverData[station.id];
    if (riverData == null) return Colors.grey;

    final status = riverData['status'] as String? ?? '';
    switch (status.toLowerCase()) {
      case 'normal':
        return Colors.green;
      case 'high':
        return Colors.orange;
      case 'very high':
        return Colors.red;
      case 'low':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(StationModel station) {
    final riverData = _riverData[station.id];
    if (riverData == null) return 'No data';

    final status = riverData['status'] as String? ?? 'Unknown';
    final flow = riverData['flow'] as double?;

    if (flow != null) {
      return '$status (${flow.toStringAsFixed(2)} m³/s)';
    }
    return status;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Water Stations'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search rivers, stations, or provinces...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),

          // Results
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.teal),
                  )
                : _filteredStations.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchController.text.isEmpty
                              ? Icons.search
                              : Icons.search_off,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchController.text.isEmpty
                              ? 'Search for Canadian water stations'
                              : 'No stations found for "${_searchController.text}"',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredStations.length,
                    itemBuilder: (context, index) {
                      final station = _filteredStations[index];
                      final isFavorite = _favoriteStationIds.contains(
                        station.id,
                      );
                      final riverData = _riverData[station.id];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getStatusColor(station),
                            child: Text(
                              station.id.substring(0, 2),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            station.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${station.id} • ${station.province == 'null' ? 'Unknown Province' : station.province}',
                              ),
                              if (station.isWhitewater &&
                                  station.section != null)
                                Text(
                                  '${station.section} • ${station.difficulty}',
                                  style: TextStyle(
                                    color: Colors.blue[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _getStatusText(station),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _getStatusColor(station),
                                    ),
                                  ),
                                  if (riverData?['timestamp'] != null)
                                    Text(
                                      riverData!['timestamp'],
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                ],
                              ),
                              IconButton(
                                icon: Icon(
                                  isFavorite ? Icons.star : Icons.star_border,
                                  color: isFavorite
                                      ? Colors.amber
                                      : Colors.grey,
                                ),
                                onPressed: () => _toggleFavorite(station.id),
                              ),
                            ],
                          ),
                          onTap: () {
                            // Show station details using the existing dialog
                            _showStationDetailsDialog({
                              'riverName': station.name,
                              'stationName': station.name,
                              'stationId': station.id,
                              'province': station.province,
                              'status': _getStatusText(station),
                              'dataSource': 'firestore',
                            });
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
