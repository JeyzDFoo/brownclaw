import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import '../services/river_service.dart';
import '../services/river_run_service.dart';

class LogbookEntryScreen extends StatefulWidget {
  const LogbookEntryScreen({super.key});

  @override
  State<LogbookEntryScreen> createState() => _LogbookEntryScreenState();
}

class _LogbookEntryScreenState extends State<LogbookEntryScreen> {
  final _riverSearchController = TextEditingController();
  final _runSearchController = TextEditingController();
  final _notesController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Selected values
  River? _selectedRiver;
  RiverRun? _selectedRun;
  DateTime _selectedDate = DateTime.now();

  // Search results
  List<River> _riverSearchResults = [];
  List<RiverRun> _runSearchResults = [];
  bool _isSearchingRivers = false;
  bool _isSearchingRuns = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _riverSearchController.dispose();
    _runSearchController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _searchRivers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _riverSearchResults = [];
        _isSearchingRivers = false;
      });
      return;
    }

    setState(() {
      _isSearchingRivers = true;
    });

    try {
      final results = await RiverService.searchRivers(query).first;
      setState(() {
        _riverSearchResults = results;
        _isSearchingRivers = false;
      });
    } catch (e) {
      setState(() {
        _isSearchingRivers = false;
      });
    }
  }

  void _searchRuns(String query) async {
    if (query.isEmpty || _selectedRiver == null) {
      setState(() {
        _runSearchResults = [];
        _isSearchingRuns = false;
      });
      return;
    }

    setState(() {
      _isSearchingRuns = true;
    });

    try {
      final results = await RiverRunService.getRunsForRiver(
        _selectedRiver!.id,
      ).first;
      final filteredResults = results
          .where((run) => run.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
      setState(() {
        _runSearchResults = filteredResults;
        _isSearchingRuns = false;
      });
    } catch (e) {
      setState(() {
        _isSearchingRuns = false;
      });
    }
  }

  void _selectRiver(River river) {
    setState(() {
      _selectedRiver = river;
      _riverSearchController.text = river.name;
      _riverSearchResults = [];
      // Clear run selection when river changes
      _selectedRun = null;
      _runSearchController.clear();
      _runSearchResults = [];
    });
  }

  void _selectRun(RiverRun run) {
    setState(() {
      _selectedRun = run;
      _runSearchController.text = run.name;
      _runSearchResults = [];
    });
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

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _firestore.collection('river_descents').add({
        'riverRunId': _selectedRun!.id,
        'riverName': _selectedRiver!.name, // Keep for backward compatibility
        'section': _selectedRun!.name, // Keep for backward compatibility
        'difficulty': _selectedRun!.difficultyClass, // Get from run data
        'notes': _notesController.text.trim(),
        'userId': user.uid,
        'userEmail': user.email,
        'userName': user.displayName ?? user.email?.split('@')[0] ?? 'Kayaker',
        'timestamp': FieldValue.serverTimestamp(),
        'date': _selectedDate.toIso8601String().split('T')[0],
        'runDate': _selectedDate.toIso8601String().split('T')[0],
      });

      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Log entry added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding entry: $e')));
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log River Descent'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
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

            // River Search
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _riverSearchController,
                  decoration: InputDecoration(
                    labelText: 'River Name',
                    hintText: 'Search for a river...',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.water),
                    suffixIcon: _isSearchingRivers
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
                  onChanged: _searchRivers,
                ),
                if (_riverSearchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _riverSearchResults.length,
                      itemBuilder: (context, index) {
                        final river = _riverSearchResults[index];
                        return ListTile(
                          dense: true,
                          title: Text(river.name),
                          subtitle: Text('${river.region}, ${river.country}'),
                          onTap: () => _selectRiver(river),
                        );
                      },
                    ),
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
                        ? 'Search for a run on ${_selectedRiver!.name}...'
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
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
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
                  ],
                ),
              ),
            if (_selectedRiver != null || _selectedRun != null)
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
                label: Text(_isSubmitting ? 'Saving...' : 'Log Descent'),
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
}
