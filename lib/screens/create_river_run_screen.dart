import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/river_service.dart';
import '../services/river_run_service.dart';
import '../services/gauge_station_service.dart';
import '../providers/providers.dart';
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

  // River selection
  River? _selectedRiver;

  // Water station selection (gauge stations)
  WaterStation? _selectedWaterStation;
  List<WaterStation> _availableWaterStations = [];
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

  // Get suggestions for rivers based on user input
  Future<List<River>> _getSuggestedRivers(String query) async {
    if (query.isEmpty) return [];

    try {
      final results = await RiverService.searchRivers(query).first;
      return results;
    } catch (e) {
      return [];
    }
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

      final stations = <WaterStation>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();

        // Create WaterStation object
        final station = WaterStation.fromMap(data, doc.id);

        // Filter by river name if provided
        if (filterRiver.isNotEmpty) {
          // Check ALL possible river name fields
          final possibleFields = [
            station.riverName,
            station.stationName,
            station.officialName,
          ];

          // Check field values for debugging (removed print statements)

          // Check if the river name matches (case-insensitive, partial match)
          final riverNameLower = filterRiver.toLowerCase();
          bool matches = false;

          for (final fieldValue in possibleFields) {
            if (fieldValue != null) {
              final fieldLower = fieldValue.toLowerCase();
              if (fieldLower.contains(riverNameLower)) {
                matches = true;
                break;
              }
            }
          }

          if (matches) {
            stations.add(station);
          }
        } else {
          // No filter, add all stations
          stations.add(station);
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
                (s) => s.documentId == _selectedWaterStation!.documentId,
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

      // Check if river already exists (same name + same region)
      final existingRivers = await RiverService.searchRivers(
        _riverNameController.text.trim(),
      ).first;
      final existingRiver = existingRivers.firstWhere(
        (river) =>
            river.name.toLowerCase() ==
                _riverNameController.text.trim().toLowerCase() &&
            river.region.toLowerCase() == _selectedRegion.toLowerCase(),
        orElse: () => const River(id: '', name: '', region: '', country: ''),
      );

      if (existingRiver.id.isNotEmpty) {
        // Found duplicate - show dialog
        if (mounted) {
          setState(() {
            _isLoading = false;
          });

          final shouldContinue = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('⚠️ Duplicate River'),
              content: Text(
                'A river named "${_riverNameController.text.trim()}" already exists in $_selectedRegion.\n\n'
                'Would you like to add a run to the existing river?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Use Existing River'),
                ),
              ],
            ),
          );

          if (shouldContinue != true) {
            return; // User cancelled
          }

          setState(() {
            _isLoading = true;
          });
        }

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

      // Check if a run with the same name already exists on this river
      final existingRunId = await RiverRunService.findExistingRun(
        riverId: riverId,
        name: _runNameController.text.trim(),
      );

      if (existingRunId != null) {
        // Found duplicate run - show dialog
        if (mounted) {
          setState(() {
            _isLoading = false;
          });

          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('⚠️ Duplicate Run'),
              content: Text(
                'A run named "${_runNameController.text.trim()}" already exists on this river.\n\n'
                'Please choose a different name for your run.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return; // Don't create duplicate
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
        stationId: _selectedWaterStation?.stationId,
      );

      final runId = await context.read<RiverRunProvider>().addRiverRun(newRun);

      // If a water station was selected, create a proper gauge station record
      if (_selectedWaterStation != null) {
        try {
          final stationData = _selectedWaterStation!;
          final stationId = stationData.stationId;

          if (stationId.isNotEmpty) {
            // Check if gauge station already exists
            final existingStation = await GaugeStationService.getStationById(
              stationId,
            );

            if (existingStation == null) {
              // Create new gauge station record
              final gaugeStation = GaugeStation(
                stationId: stationId,
                name: stationData.stationName,
                riverRunId: runId, // Link to the created run (legacy field)
                associatedRiverRunIds: [runId], // New field for multiple runs
                latitude: stationData.latitude ?? 0.0,
                longitude: stationData.longitude ?? 0.0,
                agency: 'Environment Canada',
                region: _selectedRegion,
                country: _selectedCountry,
                isActive: true,
                parameters: ['discharge', 'water_level'],
                dataUrl: null, // No dataUrl in WaterStation model
              );

              await GaugeStationService.addStation(gaugeStation);

              if (kDebugMode) {
                print('✅ Created new gauge station $stationId for run $runId');
              }
            } else {
              // Update existing station to include this run
              await GaugeStationService.addRunToStation(stationId, runId);

              if (kDebugMode) {
                print(
                  '✅ Added run $runId to existing gauge station $stationId',
                );
              }
            }

            // Trigger initial live data update for this station
            try {
              await GaugeStationService.updateStationLiveData(stationId);
              if (kDebugMode) {
                print('✅ Triggered live data update for station $stationId');
              }
            } catch (e) {
              if (kDebugMode) {
                print('⚠️ Could not fetch initial live data: $e');
              }
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ Error setting up gauge station: $e');
          }
          // Don't fail the whole operation if station setup fails
        }
      }

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

              // River Name with Autocomplete
              Autocomplete<River>(
                optionsBuilder: (TextEditingValue textEditingValue) async {
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<River>.empty();
                  }
                  return await _getSuggestedRivers(textEditingValue.text);
                },
                displayStringForOption: (River river) => river.name,
                onSelected: (River river) {
                  setState(() {
                    _selectedRiver = river;
                    _riverNameController.text = river.name;
                    _selectedRegion = river.region;
                    _selectedCountry = river.country;
                  });
                  // Reload gauge stations for the selected river
                  _loadGaugeStations(river.name);
                },
                fieldViewBuilder:
                    (
                      BuildContext context,
                      TextEditingController fieldController,
                      FocusNode focusNode,
                      VoidCallback onFieldSubmitted,
                    ) {
                      // Sync our controller with the autocomplete controller
                      if (_riverNameController.text.isNotEmpty &&
                          fieldController.text != _riverNameController.text) {
                        fieldController.text = _riverNameController.text;
                      }

                      return TextFormField(
                        controller: fieldController,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          labelText: 'River Name *',
                          hintText: 'Start typing to see suggestions...',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.water),
                          suffixIcon: _selectedRiver != null
                              ? Icon(Icons.check_circle, color: Colors.green)
                              : null,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'River name is required';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          _riverNameController.text = value;
                          // Clear selection if user modifies the text
                          if (_selectedRiver != null &&
                              value != _selectedRiver!.name) {
                            setState(() {
                              _selectedRiver = null;
                            });
                          }
                        },
                      );
                    },
                optionsViewBuilder:
                    (
                      BuildContext context,
                      AutocompleteOnSelected<River> onSelected,
                      Iterable<River> options,
                    ) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4.0,
                          borderRadius: BorderRadius.circular(4),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxHeight: 200,
                              maxWidth: 400,
                            ),
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (BuildContext context, int index) {
                                final River river = options.elementAt(index);
                                return ListTile(
                                  dense: true,
                                  title: Text(river.name),
                                  subtitle: Text(
                                    '${river.region}, ${river.country}',
                                  ),
                                  onTap: () {
                                    onSelected(river);
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                      );
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
                      DropdownButtonFormField<WaterStation>(
                        value: _selectedWaterStation,
                        decoration: const InputDecoration(
                          labelText: 'Select Gauge Station',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.sensors),
                        ),
                        hint: const Text('Choose a gauge station (optional)'),
                        menuMaxHeight: 400,
                        items: _availableWaterStations.map((station) {
                          return DropdownMenuItem(
                            value: station,
                            child: Text(
                              '${station.stationName} (${station.stationId})',
                              style: const TextStyle(
                                fontWeight: FontWeight.w400,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
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
                                'Selected: ${_selectedWaterStation!.displayName}',
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
