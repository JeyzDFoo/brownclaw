import 'package:flutter/material.dart';
import '../services/live_water_data_service.dart';
import '../services/favorite_rivers_service.dart';
import 'station_search_screen.dart';

class RiverLevelsScreen extends StatefulWidget {
  const RiverLevelsScreen({super.key});

  @override
  State<RiverLevelsScreen> createState() => _RiverLevelsScreenState();
}

class _RiverLevelsScreenState extends State<RiverLevelsScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _rivers = [];
  List<String> _favoriteStationIds = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRiverData();
    _loadFavorites();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _loadFavorites() {
    FavoriteRiversService.getUserFavorites().listen((favorites) {
      setState(() {
        _favoriteStationIds = favorites;
      });
      // Reload river data when favorites change
      _loadRiverData();
    });
  }

  void _loadRiverData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load data for favorite stations with live data
      final enrichedData = await LiveWaterDataService.getEnrichedStationsData(
        _favoriteStationIds,
      );

      setState(() {
        _rivers = enrichedData;
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

  Future<void> _refreshData() async {
    _loadRiverData();

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
    final stationId = river['stationId'] as String;
    final isFavorite = _favoriteStationIds.contains(stationId);

    try {
      if (isFavorite) {
        await FavoriteRiversService.removeFavorite(stationId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${river['name']} removed from favorites'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        await FavoriteRiversService.addFavorite(stationId, river);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${river['name']} added to favorites'),
              backgroundColor: Colors.green,
            ),
          );
        }
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Favorite Rivers'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const StationSearchScreen(),
                ),
              );
            },
            tooltip: 'Add new stations',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Refresh data',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading data',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
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
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const StationSearchScreen(),
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
                                : 'Data temporarily unavailable',
                            style: TextStyle(
                              color: _rivers.first['dataSource'] == 'live'
                                  ? Colors.green[700]
                                  : Colors.orange[700],
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
                      final status = river['status'] as String? ?? 'unknown';
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
                          leading: CircleAvatar(
                            backgroundColor: statusColor.withOpacity(0.1),
                            child: Icon(statusIcon, color: statusColor),
                          ),
                          title: Text(
                            river['riverName'] as String? ?? 'Unknown River',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                river['stationName'] as String? ??
                                    'Unknown Station',
                                style: const TextStyle(fontSize: 13),
                              ),
                              Text('Province: ${river['province']}'),
                              if (flowRate != null)
                                Text(
                                  'Flow: ${flowRate.toStringAsFixed(2)} m³/s',
                                ),
                              Text('Status: $status'),
                              Row(
                                children: [
                                  Icon(
                                    dataSource == 'live'
                                        ? Icons.live_tv
                                        : Icons.info,
                                    size: 12,
                                    color: dataSource == 'live'
                                        ? Colors.green
                                        : Colors.orange,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    dataSource == 'live'
                                        ? 'Live data'
                                        : 'Data unavailable',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: dataSource == 'live'
                                          ? Colors.green
                                          : Colors.orange,
                                      fontWeight: FontWeight.bold,
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
                                onPressed: () => _toggleFavorite(river),
                              ),
                              // Status badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: statusColor.withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
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
    );
  }
}
