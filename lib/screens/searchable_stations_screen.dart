import 'package:flutter/material.dart';
import '../services/firestore_station_service.dart';
import '../services/canadian_water_service.dart';
import '../services/favorite_rivers_service.dart';

class NewStationSearchScreen extends StatefulWidget {
  const NewStationSearchScreen({super.key});

  @override
  State<NewStationSearchScreen> createState() => _NewStationSearchScreenState();
}

class _NewStationSearchScreenState extends State<NewStationSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FirestoreStationService _stationService = FirestoreStationService();
  // Note: FavoriteRiversService methods are static

  List<StationModel> _stations = [];
  List<StationModel> _filteredStations = [];
  Map<String, Map<String, dynamic>> _riverData = {};
  Set<String> _favoriteStationIds = {};
  bool _isLoading = false;
  bool _isSearching = false;
  String _selectedProvince = 'All Provinces';
  bool _showWhitewaterOnly = false;

  List<String> _availableProvinces = ['All Provinces'];

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
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load available provinces
      final provinces = await _stationService.getAvailableProvinces();
      _availableProvinces = ['All Provinces', ...provinces];

      // Load initial stations (whitewater + popular ones)
      final whitewater = await _stationService.getWhitewaterStations();
      final popular = await _stationService.getAllStations(limit: 50);

      // Combine and deduplicate
      final stationMap = <String, StationModel>{};
      for (final station in [...whitewater, ...popular]) {
        stationMap[station.id] = station;
      }

      final stations = stationMap.values.toList();

      setState(() {
        _stations = stations;
        _filteredStations = stations;
        _isLoading = false;
      });

      // Load river data for initial stations
      _loadRiverData();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading stations: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _loadFavorites() {
    // Listen to user favorites stream
    FavoriteRiversService.getUserFavorites().listen((favoriteIds) {
      if (mounted) {
        setState(() {
          _favoriteStationIds = favoriteIds.toSet();
        });
      }
    });
  }

  Future<void> _loadRiverData() async {
    try {
      final allRiverData = await CanadianWaterService.fetchRiverLevels();

      if (mounted) {
        final dataMap = <String, Map<String, dynamic>>{};
        for (final riverInfo in allRiverData) {
          final stationId = riverInfo['stationId'] as String?;
          if (stationId != null) {
            dataMap[stationId] = riverInfo;
          }
        }

        setState(() {
          _riverData = dataMap;
        });
      }
    } catch (e) {
      // Silently handle river data loading errors
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.length >= 2) {
      _performSearch(query);
    } else {
      _applyFilters();
    }
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isSearching = true;
    });

    try {
      final results = await _stationService.searchStationsByName(query);

      setState(() {
        _stations = results;
        _applyFilters();
        _isSearching = false;
      });

      // Load river data for search results
      _loadRiverData();
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Search failed: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredStations = _stations.where((station) {
        // Province filter
        if (_selectedProvince != 'All Provinces' &&
            station.province != _selectedProvince) {
          return false;
        }

        // Whitewater filter
        if (_showWhitewaterOnly && !station.isWhitewater) {
          return false;
        }

        return true;
      }).toList();
    });
  }

  void _onProvinceChanged(String? province) {
    setState(() {
      _selectedProvince = province ?? 'All Provinces';
      _applyFilters();
    });
  }

  void _onWhitewaterFilterChanged(bool? value) {
    setState(() {
      _showWhitewaterOnly = value ?? false;
      _applyFilters();
    });
  }

  Color _getStatusColor(StationModel station) {
    final riverData = _riverData[station.id];
    if (riverData == null) return Colors.grey;

    if (!station.isWhitewater) return Colors.blue;

    final flow = riverData['flow'] as double?;
    if (flow == null) return Colors.grey;

    final minRunnable = station.minRunnable ?? 0;
    final maxSafe = station.maxSafe ?? double.infinity;

    if (flow < minRunnable) return Colors.red;
    if (flow > maxSafe) return Colors.orange;
    return Colors.green;
  }

  String _getStatusText(StationModel station) {
    final riverData = _riverData[station.id];
    if (riverData == null) return 'No Data';

    if (!station.isWhitewater) {
      final flow = riverData['flow'] as double?;
      return flow != null ? '${flow.toStringAsFixed(1)} m³/s' : 'No Data';
    }

    final flow = riverData['flow'] as double?;
    if (flow == null) return 'No Data';

    final minRunnable = station.minRunnable ?? 0;
    final maxSafe = station.maxSafe ?? double.infinity;

    if (flow < minRunnable) return 'Too Low';
    if (flow > maxSafe) return 'Too High';
    return 'Runnable';
  }

  Future<void> _toggleFavorite(String stationId) async {
    try {
      final station = _filteredStations.firstWhere((s) => s.id == stationId);
      final riverData = _riverData[stationId] ?? {};

      if (_favoriteStationIds.contains(stationId)) {
        await FavoriteRiversService.removeFavorite(stationId);
        // setState will be updated by the stream listener
      } else {
        await FavoriteRiversService.addFavorite(stationId, {
          'name': station.name,
          'province': station.province,
          'flow': riverData['flow'] ?? 0.0,
          'status': riverData['status'] ?? 'Unknown',
          'timestamp': DateTime.now().toIso8601String(),
        });
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search and filters
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[100],
          child: Column(
            children: [
              // Search bar
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by river name, station ID, or location...',
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
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),

              // Filters row
              Row(
                children: [
                  // Province dropdown
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedProvince,
                      decoration: InputDecoration(
                        labelText: 'Province',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items: _availableProvinces.map((province) {
                        return DropdownMenuItem(
                          value: province,
                          child: Text(
                            province,
                            style: const TextStyle(fontSize: 14),
                          ),
                        );
                      }).toList(),
                      onChanged: _onProvinceChanged,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Whitewater filter
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: _showWhitewaterOnly,
                          onChanged: _onWhitewaterFilterChanged,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                        const Text(
                          'Whitewater',
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Results
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredStations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        _searchController.text.isEmpty
                            ? 'No stations loaded'
                            : 'No stations found matching "${_searchController.text}"',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Try searching for a river name, location, or station ID',
                        style: TextStyle(color: Colors.grey[500], fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadRiverData,
                  child: ListView.builder(
                    itemCount: _filteredStations.length,
                    itemBuilder: (context, index) {
                      final station = _filteredStations[index];
                      final riverData = _riverData[station.id];
                      final isFavorite = _favoriteStationIds.contains(
                        station.id,
                      );

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
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
                            // TODO: Navigate to detailed station view
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Selected: ${station.name}'),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
