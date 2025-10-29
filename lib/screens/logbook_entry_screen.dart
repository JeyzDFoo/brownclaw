import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import '../services/river_service.dart';
import '../services/river_run_service.dart';

class LogbookEntryScreen extends StatefulWidget {
  final RiverRunWithStations? prefilledRun;

  const LogbookEntryScreen({super.key, this.prefilledRun});

  @override
  State<LogbookEntryScreen> createState() => _LogbookEntryScreenState();
}

class _LogbookEntryScreenState extends State<LogbookEntryScreen> {
  final _riverSearchController = TextEditingController();
  final _runSearchController = TextEditingController();
  final _notesController = TextEditingController();

  // Selected values
  River? _selectedRiver;
  RiverRun? _selectedRun;
  DateTime _selectedDate = DateTime.now();
  double _rating = 0.0; // Rating from 0 to 3 stars

  // Water level data
  double? _waterLevel;
  double? _discharge;
  bool _isLoadingWaterData = false;

  // Run search results
  List<RiverRun> _runSearchResults = [];
  List<RiverRun> _allRunsForSelectedRiver = []; // Store all runs for filtering
  bool _isSearchingRuns = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();

    // Check if we're in edit mode via provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final logbookProvider = context.read<LogbookProvider>();

      if (logbookProvider.isEditMode &&
          logbookProvider.editingEntryData != null) {
        _loadEditingData(logbookProvider.editingEntryData!);
      } else if (widget.prefilledRun != null) {
        // Pre-fill with data if provided
        _selectedRiver = widget.prefilledRun!.river;
        _selectedRun = widget.prefilledRun!.run;
        if (_selectedRiver != null) {
          _riverSearchController.text = _selectedRiver!.name;
        }
        if (_selectedRun != null) {
          _runSearchController.text = _selectedRun!.name;
          // Fetch water level data for the prefilled run
          _fetchWaterLevelForDate();
        }
      }
    });
  }

  void _loadEditingData(Map<String, dynamic> data) async {
    setState(() {
      // Load notes
      _notesController.text = data['notes'] ?? '';

      // Load rating
      if (data['rating'] != null) {
        _rating = (data['rating'] as num).toDouble();
      }

      // Load date
      if (data['runDate'] != null) {
        try {
          _selectedDate = DateTime.parse(data['runDate']);
        } catch (e) {
          // Keep default date if parsing fails
        }
      }

      // Load water level data
      _waterLevel = data['waterLevel'];
      _discharge = data['discharge'];
    });

    // Fetch the actual River and RiverRun objects from the database
    if (data['riverRunId'] != null) {
      try {
        // Get the run by ID
        final run = await RiverRunService.getRunById(data['riverRunId']);
        if (run != null) {
          setState(() {
            _selectedRun = run;
            _runSearchController.text = run.name;
          });

          // Get the river for this run
          final river = await RiverService.getRiverById(run.riverId);
          if (river != null) {
            setState(() {
              _selectedRiver = river;
              _riverSearchController.text = river.name;
            });
          }
        }
      } catch (e) {
        // If we can't fetch the data, fall back to display names
        if (mounted) {
          setState(() {
            if (data['riverName'] != null) {
              _riverSearchController.text = data['riverName'];
            }
            if (data['section'] != null) {
              _runSearchController.text = data['section'];
            }
          });
        }
      }
    } else {
      // Fallback: just display the names without actual objects
      setState(() {
        if (data['riverName'] != null) {
          _riverSearchController.text = data['riverName'];
        }
        if (data['section'] != null) {
          _runSearchController.text = data['section'];
        }
      });
    }
  }

  @override
  void dispose() {
    _riverSearchController.dispose();
    _runSearchController.dispose();
    _notesController.dispose();
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

  void _searchRuns(String query) async {
    if (_selectedRiver == null) {
      setState(() {
        _runSearchResults = [];
        _isSearchingRuns = false;
      });
      return;
    }

    // If query is empty, show all runs for the river
    if (query.isEmpty) {
      setState(() {
        _runSearchResults = _allRunsForSelectedRiver;
        _isSearchingRuns = false;
      });
      return;
    }

    // Filter the already-loaded runs
    final filteredResults = _allRunsForSelectedRiver
        .where((run) => run.name.toLowerCase().contains(query.toLowerCase()))
        .toList();

    setState(() {
      _runSearchResults = filteredResults;
      _isSearchingRuns = false;
    });
  }

  void _selectRiver(River river) async {
    setState(() {
      _selectedRiver = river;
      _riverSearchController.text = river.name;
      // Clear run selection when river changes
      _selectedRun = null;
      _runSearchController.clear();
      _runSearchResults = [];
      _allRunsForSelectedRiver = [];
      _isSearchingRuns = true; // Show loading state
    });

    // Automatically fetch all runs for the selected river
    try {
      final runs = await RiverRunService.getRunsForRiver(river.id).first;
      setState(() {
        _allRunsForSelectedRiver = runs;
        _runSearchResults = runs; // Show all runs initially
        _isSearchingRuns = false;
      });

      // Auto-select if there's only one run
      if (runs.length == 1) {
        _selectRun(runs.first);
      }
    } catch (e) {
      setState(() {
        _isSearchingRuns = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading runs: $e')));
      }
    }
  }

  void _selectRun(RiverRun run) {
    setState(() {
      _selectedRun = run;
      _runSearchController.text = run.name;
      _runSearchResults = [];
    });

    // Fetch water level data for the selected run and date
    _fetchWaterLevelForDate();
  }

  Future<void> _fetchWaterLevelForDate() async {
    if (_selectedRun?.stationId == null) {
      // No station ID available for this run
      setState(() {
        _waterLevel = null;
        _discharge = null;
        _isLoadingWaterData = false;
      });
      return;
    }

    setState(() {
      _isLoadingWaterData = true;
    });

    try {
      // Use HistoricalWaterDataProvider for stale-while-revalidate caching
      final historicalProvider = context.read<HistoricalWaterDataProvider>();

      List<Map<String, dynamic>> data;

      // Fetch historical data for the selected date
      // Provider handles caching and uses appropriate API based on date
      data = await historicalProvider.fetchHistoricalData(
        _selectedRun!.stationId!,
        startDate: _selectedDate,
        endDate: _selectedDate,
      );

      if (data.isNotEmpty) {
        final dayData = data.first;
        setState(() {
          _waterLevel = dayData['level']?.toDouble();
          _discharge = dayData['discharge']?.toDouble();
        });
      } else {
        setState(() {
          _waterLevel = null;
          _discharge = null;
        });
      }
    } catch (e) {
      print('Error fetching water level data: $e');
      setState(() {
        _waterLevel = null;
        _discharge = null;
      });
    } finally {
      setState(() {
        _isLoadingWaterData = false;
      });
    }
  }

  Future<void> _submitLogEntry() async {
    if (_selectedRiver == null || _selectedRun == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both river and run')),
      );
      return;
    }

    final user = context.read<UserProvider>().user;
    if (user == null) return;

    final logbookProvider = context.read<LogbookProvider>();
    final isEditMode = logbookProvider.isEditMode;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final entryData = {
        'riverRunId': _selectedRun!.id,
        'riverName': _selectedRiver!.name, // Keep for backward compatibility
        'section': _selectedRun!.name, // Keep for backward compatibility
        'difficulty': _selectedRun!.difficultyClass, // Get from run data
        'notes': _notesController.text.trim(),
        'rating': _rating, // Emoji rating
        'userId': user.uid,
        'userEmail': user.email,
        'userName': user.displayName ?? user.email?.split('@')[0] ?? 'Kayaker',
        'date': _selectedDate.toIso8601String().split('T')[0],
        'runDate': _selectedDate.toIso8601String().split('T')[0],
        // Water level data
        'waterLevel': _waterLevel,
        'discharge': _discharge,
        'stationId': _selectedRun!.stationId,
      };

      if (isEditMode && logbookProvider.editingEntryId != null) {
        // Update existing entry
        await logbookProvider.updateEntry(
          logbookProvider.editingEntryId!,
          entryData,
        );

        if (mounted) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Log entry updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Add new entry (include timestamp for new entries only)
        entryData['timestamp'] = FieldValue.serverTimestamp();
        await logbookProvider.addEntry(entryData);

        if (mounted) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Log entry added successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving entry: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final logbookProvider = context.watch<LogbookProvider>();
    final isEditMode = logbookProvider.isEditMode;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              isEditMode ? Icons.edit_note : Icons.add_circle_outline,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(isEditMode ? 'Edit River Descent' : 'Log River Descent'),
          ],
        ),
        elevation: 0,
        scrolledUnderElevation: 3,
        actions: [
          if (_isSubmitting)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Picker
            InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  setState(() {
                    _selectedDate = date;
                  });
                  // Fetch water level data for the new date
                  _fetchWaterLevelForDate();
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Run Date',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(
                  '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                ),
              ),
            ),
            const SizedBox(height: 16),

            // River Search with Autocomplete
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Autocomplete<River>(
                  optionsBuilder: (TextEditingValue textEditingValue) async {
                    if (textEditingValue.text.isEmpty) {
                      return const Iterable<River>.empty();
                    }
                    return await _getSuggestedRivers(textEditingValue.text);
                  },
                  displayStringForOption: (River river) => river.name,
                  onSelected: (River river) {
                    _selectRiver(river);
                  },
                  fieldViewBuilder:
                      (
                        BuildContext context,
                        TextEditingController fieldController,
                        FocusNode focusNode,
                        VoidCallback onFieldSubmitted,
                      ) {
                        // Sync our controller with the autocomplete controller
                        if (_riverSearchController.text.isNotEmpty &&
                            fieldController.text !=
                                _riverSearchController.text) {
                          fieldController.text = _riverSearchController.text;
                        }

                        return TextFormField(
                          controller: fieldController,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                            labelText: 'River Name',
                            hintText: 'Start typing to see suggestions...',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.water),
                            suffixIcon: _selectedRiver != null
                                ? Icon(Icons.check_circle, color: Colors.green)
                                : null,
                          ),
                          onChanged: (value) {
                            _riverSearchController.text = value;
                            // Clear selection if user modifies the text
                            if (_selectedRiver != null &&
                                value != _selectedRiver!.name) {
                              setState(() {
                                _selectedRiver = null;
                                _selectedRun = null;
                                _runSearchController.clear();
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
              ],
            ),
            const SizedBox(height: 16),

            // Run Search
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _runSearchController,
                  enabled: _selectedRiver != null,
                  decoration: InputDecoration(
                    labelText: 'Section/Run',
                    hintText: _selectedRiver != null
                        ? _runSearchResults.isNotEmpty
                              ? 'Select a run or search to filter...'
                              : 'Loading runs for ${_selectedRiver!.name}...'
                        : 'Select a river first',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.location_on),
                    suffixIcon: _isSearchingRuns
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: Padding(
                              padding: EdgeInsets.all(12.0),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                  ),
                  onChanged: _searchRuns,
                ),
                if (_runSearchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _runSearchResults.length,
                      itemBuilder: (context, index) {
                        final run = _runSearchResults[index];
                        return ListTile(
                          dense: true,
                          title: Text(run.name),
                          subtitle: Text(
                            '${run.difficultyClass} • ${run.length?.toStringAsFixed(1) ?? '?'} km',
                          ),
                          onTap: () => _selectRun(run),
                        );
                      },
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Display selected river and run info
            if (_selectedRiver != null || _selectedRun != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Selected:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (_selectedRiver != null)
                      Text('River: ${_selectedRiver!.name}'),
                    if (_selectedRun != null)
                      Text(
                        'Run: ${_selectedRun!.name} (${_selectedRun!.difficultyClass})',
                      ),
                    if (_selectedRun?.stationId != null) ...[
                      const SizedBox(height: 8),
                      if (_isLoadingWaterData)
                        const Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text('Loading water data...'),
                          ],
                        )
                      else if (_discharge != null || _waterLevel != null) ...[
                        Text(
                          'Water Conditions (${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}):',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        if (_discharge != null)
                          Text(
                            '  Discharge: ${_discharge!.toStringAsFixed(2)} m³/s',
                          ),
                        if (_waterLevel != null)
                          Text('  Level: ${_waterLevel!.toStringAsFixed(2)} m'),
                      ] else
                        Text(
                          'No water data available for ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            if (_selectedRiver != null || _selectedRun != null)
              const SizedBox(height: 16),

            // Rating Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.teal.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('😊', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Text(
                        'Rate your run',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Bad/Poor
                      _buildEmojiButton(emoji: '😢', label: 'Poor', value: 1.0),
                      // Okay/Average
                      _buildEmojiButton(emoji: '😐', label: 'Okay', value: 2.0),
                      // Good/Great
                      _buildEmojiButton(
                        emoji: '😊',
                        label: 'Great',
                        value: 3.0,
                      ),
                    ],
                  ),
                  if (_rating > 0) ...[
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.teal.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _getRatingLabel(_rating),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.teal[700],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Notes field
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText: 'How was your run? Any highlights or tips?',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.notes),
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 24),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitLogEntry,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(
                  _isSubmitting
                      ? (isEditMode ? 'Updating...' : 'Saving...')
                      : (isEditMode ? 'Update' : 'Save'),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Help text
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Select a river and run from the database to automatically fill in difficulty and other metadata.',
                      style: TextStyle(color: Colors.blue[700], fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmojiButton({
    required String emoji,
    required String label,
    required double value,
  }) {
    final isSelected = _rating == value;
    return InkWell(
      onTap: () {
        setState(() {
          _rating = value;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.teal.withOpacity(0.15)
              : Colors.grey.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.teal : Colors.grey.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(emoji, style: TextStyle(fontSize: isSelected ? 44 : 40)),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.teal[700] : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getRatingLabel(double rating) {
    if (rating == 1.0) return 'Poor run 😢';
    if (rating == 2.0) return 'Okay run 😐';
    if (rating == 3.0) return 'Great run! 😊';
    return 'Rated';
  }
}
