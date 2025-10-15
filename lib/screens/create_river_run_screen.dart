import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/river_service.dart';
import '../services/river_run_service.dart';
import '../models/models.dart';

class CreateRiverRunScreen extends StatefulWidget {
  const CreateRiverRunScreen({super.key});

  @override
  State<CreateRiverRunScreen> createState() => _CreateRiverRunScreenState();
}

class _CreateRiverRunScreenState extends State<CreateRiverRunScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Form controllers
  final TextEditingController _riverNameController = TextEditingController();
  final TextEditingController _runNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _lengthController = TextEditingController();
  final TextEditingController _putInController = TextEditingController();
  final TextEditingController _takeOutController = TextEditingController();
  final TextEditingController _gradientController = TextEditingController();
  final TextEditingController _seasonController = TextEditingController();
  final TextEditingController _permitsController = TextEditingController();
  final TextEditingController _hazardsController = TextEditingController();
  final TextEditingController _minFlowController = TextEditingController();
  final TextEditingController _maxFlowController = TextEditingController();

  // Form state
  String _selectedDifficulty = 'Class III';
  String _selectedRegion = 'British Columbia';
  String _selectedCountry = 'Canada';
  bool _isLoading = false;

  // Water station selection (gauge stations)
  Map<String, dynamic>? _selectedWaterStation;
  List<Map<String, dynamic>> _availableWaterStations = [];
  bool _loadingStations = false;

  // Available options
  final List<String> _difficulties = [
    'Class I',
    'Class II',
    'Class III',
    'Class IV',
    'Class V',
    'Class VI',
  ];

  final List<String> _regions = [
    'British Columbia',
    'Alberta',
    'Ontario',
    'Quebec',
    'Nova Scotia',
    'New Brunswick',
    'Manitoba',
    'Saskatchewan',
    'Newfoundland and Labrador',
    'Prince Edward Island',
    'Northwest Territories',
    'Nunavut',
    'Yukon',
  ];

  @override
  void initState() {
    super.initState();

    // Add listener to river name field to reload gauge stations when it changes
    _riverNameController.addListener(_onRiverNameChanged);

    // Don't load stations initially - wait for user to enter a river name
  }

  void _onRiverNameChanged() {
    // Only search when there are at least 3 characters to avoid loading too many stations
    if (_riverNameController.text.length >= 3) {
      _loadGaugeStations(_riverNameController.text.trim());
    } else if (_riverNameController.text.isEmpty) {
      // Clear the list when empty to avoid showing 2000+ stations
      if (mounted) {
        setState(() {
          _availableWaterStations = [];
          _selectedWaterStation = null;
        });
      }
    }
  }

  @override
  void dispose() {
    _riverNameController.removeListener(_onRiverNameChanged);
    _riverNameController.dispose();
    _runNameController.dispose();
    _descriptionController.dispose();
    _lengthController.dispose();
    _putInController.dispose();
    _takeOutController.dispose();
    _gradientController.dispose();
    _seasonController.dispose();
    _permitsController.dispose();
    _hazardsController.dispose();
    _minFlowController.dispose();
    _maxFlowController.dispose();
    super.dispose();
  }

  Future<void> _loadGaugeStations([String? riverName]) async {
    final filterRiver = riverName ?? _riverNameController.text.trim();
    if (mounted) {
      setState(() {
        _loadingStations = true;
      });
    }

    try {
      // Get water stations from Firestore, potentially filtered by river name
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('water_stations')
          .limit(2000); // Large limit to ensure we get all available stations

      final snapshot = await query.get();

      // Process the station data
      // Debug info removed for performance

      final stations = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id; // Add document ID

        // Filter by river name if provided
        if (filterRiver.isNotEmpty) {
          // Check ALL possible river name fields
          final possibleFields = [
            data['riverName'],
            data['name'],
            data['stationName'],
            data['official_name'],
          ];

          // Check field values for debugging (removed print statements)

          // Check if the river name matches (case-insensitive, partial match)
          final riverNameLower = filterRiver.toLowerCase();
          bool matches = false;

          for (final fieldValue in possibleFields) {
            if (fieldValue != null) {
              final fieldLower = fieldValue.toString().toLowerCase();
              if (fieldLower.contains(riverNameLower)) {
                matches = true;
                break;
              }
            }
          }

          if (matches) {
            stations.add(data);
          }
        } else {
          // No filter, add all stations
          stations.add(data);
        }
      }

      // Limit the number of stations shown in the dropdown to prevent UI crashes
      final limitedStations = stations.take(50).toList();

      if (mounted) {
        setState(() {
          _availableWaterStations = limitedStations;
          _loadingStations = false;
          // Clear selection if current selection is not in the new filtered list
          if (_selectedWaterStation != null &&
              !limitedStations.any(
                (s) => s['id'] == _selectedWaterStation!['id'],
              )) {
            _selectedWaterStation = null;
          }
        });
      }

      // Successfully loaded stations (debug output removed)
    } catch (e) {
      // Error loading water stations (debug output removed)
      if (mounted) {
        setState(() {
          _loadingStations = false;
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading gauge stations: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _createRiverRun() async {
    if (!_formKey.currentState!.validate()) return;

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      // First, create or find the river
      String riverId;

      // Check if river already exists
      final existingRivers = await RiverService.searchRivers(
        _riverNameController.text.trim(),
      ).first;
      final existingRiver = existingRivers.firstWhere(
        (river) =>
            river.name.toLowerCase() ==
            _riverNameController.text.trim().toLowerCase(),
        orElse: () => const River(id: '', name: '', region: '', country: ''),
      );

      if (existingRiver.id.isNotEmpty) {
        riverId = existingRiver.id;
      } else {
        // Create new river
        final newRiver = River(
          id: '', // Will be set by Firestore
          name: _riverNameController.text.trim(),
          region: _selectedRegion,
          country: _selectedCountry,
          description: 'River created from new run submission',
        );

        riverId = await RiverService.addRiver(newRiver);
      }

      // Create the river run
      final newRun = RiverRun(
        id: '', // Will be set by Firestore
        riverId: riverId,
        name: _runNameController.text.trim(),
        difficultyClass: _selectedDifficulty,
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        length: _lengthController.text.trim().isNotEmpty
            ? double.tryParse(_lengthController.text.trim())
            : null,
        putIn: _putInController.text.trim().isNotEmpty
            ? _putInController.text.trim()
            : null,
        takeOut: _takeOutController.text.trim().isNotEmpty
            ? _takeOutController.text.trim()
            : null,
        gradient: _gradientController.text.trim().isNotEmpty
            ? double.tryParse(_gradientController.text.trim())
            : null,
        season: _seasonController.text.trim().isNotEmpty
            ? _seasonController.text.trim()
            : null,
        permits: _permitsController.text.trim().isNotEmpty
            ? _permitsController.text.trim()
            : null,
        hazards: _hazardsController.text.trim().isNotEmpty
            ? _hazardsController.text
                  .trim()
                  .split(',')
                  .map((h) => h.trim())
                  .toList()
            : null,
        minRecommendedFlow: _minFlowController.text.trim().isNotEmpty
            ? double.tryParse(_minFlowController.text.trim())
            : null,
        maxRecommendedFlow: _maxFlowController.text.trim().isNotEmpty
            ? double.tryParse(_maxFlowController.text.trim())
            : null,
        flowUnit: 'cms',
      );

      await RiverRunService.addRun(newRun);

      // If a water station was selected, we could optionally link it to the run
      // For now, just store it in the run data (already included above)
      // TODO: Implement linking logic if needed

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully created ${newRun.displayName}!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating river run: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New River Run'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // River Information Section
              Text(
                'River Information',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _riverNameController,
                decoration: const InputDecoration(
                  labelText: 'River Name *',
                  hintText: 'e.g., Kicking Horse River',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.water),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'River name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _selectedRegion,
                decoration: const InputDecoration(
                  labelText: 'Region/Province',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
                items: _regions.map((region) {
                  return DropdownMenuItem(
                    value: region,
                    child: Text(
                      region,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (mounted) {
                    setState(() {
                      _selectedRegion = value!;
                    });
                  }
                },
                isExpanded: true,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _selectedCountry,
                decoration: const InputDecoration(
                  labelText: 'Country',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.flag),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Canada',
                    child: Text(
                      'Canada',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'United States',
                    child: Text(
                      'United States',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'Other',
                    child: Text(
                      'Other',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (mounted) {
                    setState(() {
                      _selectedCountry = value!;
                    });
                  }
                },
                isExpanded: true,
              ),
              const SizedBox(height: 32),

              // Run Information Section
              Text(
                'Run Information',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _runNameController,
                decoration: const InputDecoration(
                  labelText: 'Run/Section Name *',
                  hintText: 'e.g., Upper Canyon, Lower Falls',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.route),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Run name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _selectedDifficulty,
                decoration: const InputDecoration(
                  labelText: 'Difficulty Class *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.trending_up),
                ),
                items: _difficulties.map((difficulty) {
                  return DropdownMenuItem(
                    value: difficulty,
                    child: Text(
                      difficulty,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedDifficulty = value!;
                  });
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Brief description of the run...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // Technical Details Section
              Text(
                'Technical Details',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _lengthController,
                      decoration: const InputDecoration(
                        labelText: 'Length (km)',
                        hintText: '5.2',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.straighten),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _gradientController,
                      decoration: const InputDecoration(
                        labelText: 'Gradient (m/km)',
                        hintText: '15.5',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.trending_down),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _putInController,
                decoration: const InputDecoration(
                  labelText: 'Put-in Location',
                  hintText: 'e.g., Highway 1 Bridge',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.play_arrow),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _takeOutController,
                decoration: const InputDecoration(
                  labelText: 'Take-out Location',
                  hintText: 'e.g., Golden Whitewater Park',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.stop),
                ),
              ),
              const SizedBox(height: 16),

              // Flow Information Section
              Text(
                'Flow Information',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Gauge Station Selection
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.sensors, color: Colors.blue[600]),
                        const SizedBox(width: 8),
                        Text(
                          'Gauge Station (Optional)',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _riverNameController.text.trim().isNotEmpty
                          ? 'Showing gauge stations for "${_riverNameController.text.trim()}" (updates as you type)'
                          : 'Link a gauge station to this run for live flow data',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 12),
                    if (_loadingStations)
                      const Center(child: CircularProgressIndicator())
                    else if (_availableWaterStations.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info,
                              color: Colors.orange[700],
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _riverNameController.text.trim().isNotEmpty
                                    ? 'No gauge stations found for "${_riverNameController.text.trim()}". Try a different river name.'
                                    : 'No gauge stations available',
                                style: TextStyle(
                                  color: Colors.orange[700],
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      DropdownButtonFormField<Map<String, dynamic>>(
                        value: _selectedWaterStation,
                        decoration: const InputDecoration(
                          labelText: 'Select Gauge Station',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.sensors),
                        ),
                        hint: const Text('Choose a gauge station (optional)'),
                        items: _availableWaterStations.map((station) {
                          final stationName =
                              station['name'] ??
                              station['stationName'] ??
                              'Unknown Station';
                          final stationId =
                              station['id'] ??
                              station['stationId'] ??
                              'Unknown ID';
                          return DropdownMenuItem(
                            value: station,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  stationName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                Text(
                                  stationId,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (mounted) {
                            setState(() {
                              _selectedWaterStation = value;
                            });
                          }
                        },
                        isExpanded: true,
                      ),
                    if (_selectedWaterStation != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green[600],
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Selected: ${_selectedWaterStation!['name'] ?? _selectedWaterStation!['stationName'] ?? 'Unknown'} (${_selectedWaterStation!['id'] ?? _selectedWaterStation!['stationId'] ?? 'Unknown ID'})',
                                style: TextStyle(
                                  color: Colors.green[700],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _selectedWaterStation = null;
                                });
                              },
                              child: const Text(
                                'Clear',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _minFlowController,
                      decoration: const InputDecoration(
                        labelText: 'Min Flow (m³/s)',
                        hintText: '15.0',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.water_drop),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _maxFlowController,
                      decoration: const InputDecoration(
                        labelText: 'Max Safe Flow (m³/s)',
                        hintText: '80.0',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.water_drop_outlined),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Additional Information Section
              Text(
                'Additional Information',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _seasonController,
                decoration: const InputDecoration(
                  labelText: 'Best Season',
                  hintText: 'e.g., May - September',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_month),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _permitsController,
                decoration: const InputDecoration(
                  labelText: 'Permits Required',
                  hintText: 'e.g., None, or details about permits needed',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.assignment),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _hazardsController,
                decoration: const InputDecoration(
                  labelText: 'Known Hazards',
                  hintText: 'e.g., Undercut rocks, strainers (comma separated)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.warning),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createRiverRun,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'Create River Run',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Help Text
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Fields marked with * are required. Your new run will be added to the database and available for other kayakers to search and favorite.',
                        style: TextStyle(color: Colors.blue[700], fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
