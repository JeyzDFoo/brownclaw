import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/river_run_service.dart';

class EditRiverRunScreen extends StatefulWidget {
  final Map<String, dynamic> riverData;

  const EditRiverRunScreen({super.key, required this.riverData});

  @override
  State<EditRiverRunScreen> createState() => _EditRiverRunScreenState();
}

class _EditRiverRunScreenState extends State<EditRiverRunScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  RiverRun? _riverRun;

  // Form controllers
  late TextEditingController _runNameController;
  late TextEditingController _descriptionController;
  late TextEditingController _lengthController;
  late TextEditingController _putInController;
  late TextEditingController _takeOutController;
  late TextEditingController _gradientController;
  late TextEditingController _seasonController;
  late TextEditingController _permitsController;
  late TextEditingController _hazardsController;
  late TextEditingController _minFlowController;
  late TextEditingController _maxFlowController;
  late TextEditingController _optimalMinController;
  late TextEditingController _optimalMaxController;

  String? _selectedDifficulty;
  final List<String> _difficulties = [
    'Class I',
    'Class II',
    'Class III',
    'Class IV',
    'Class V',
    'Class VI',
    'Class II-III',
    'Class III-IV',
    'Class IV-V',
    'Class V-VI',
  ];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadRunData();
  }

  void _initializeControllers() {
    _runNameController = TextEditingController();
    _descriptionController = TextEditingController();
    _lengthController = TextEditingController();
    _putInController = TextEditingController();
    _takeOutController = TextEditingController();
    _gradientController = TextEditingController();
    _seasonController = TextEditingController();
    _permitsController = TextEditingController();
    _hazardsController = TextEditingController();
    _minFlowController = TextEditingController();
    _maxFlowController = TextEditingController();
    _optimalMinController = TextEditingController();
    _optimalMaxController = TextEditingController();
  }

  Future<void> _loadRunData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Extract section info
      final section = widget.riverData['section'];
      final sectionName = section is Map ? section['name'] : section;
      final difficulty = section is Map
          ? section['difficulty']
          : widget.riverData['difficulty'];

      // Get the station ID to find the run
      final stationId = widget.riverData['stationId'] as String?;

      if (stationId != null && stationId.isNotEmpty) {
        // Try to get run by station ID
        final runId = await RiverRunService.getRunIdByStationId(stationId);

        if (runId != null) {
          final run = await RiverRunService.getRunById(runId);

          if (run != null) {
            setState(() {
              _riverRun = run;
              _runNameController.text = run.name;
              _descriptionController.text = run.description ?? '';
              _lengthController.text = run.length != null
                  ? run.length.toString()
                  : '';
              _putInController.text = run.putIn ?? '';
              _takeOutController.text = run.takeOut ?? '';
              _gradientController.text = run.gradient != null
                  ? run.gradient.toString()
                  : '';
              _seasonController.text = run.season ?? '';
              _permitsController.text = run.permits ?? '';
              _hazardsController.text = run.hazards != null
                  ? run.hazards!.join(', ')
                  : '';
              _minFlowController.text = run.minRecommendedFlow != null
                  ? run.minRecommendedFlow.toString()
                  : '';
              _maxFlowController.text = run.maxRecommendedFlow != null
                  ? run.maxRecommendedFlow.toString()
                  : '';
              _optimalMinController.text = run.optimalFlowMin != null
                  ? run.optimalFlowMin.toString()
                  : '';
              _optimalMaxController.text = run.optimalFlowMax != null
                  ? run.optimalFlowMax.toString()
                  : '';
              _selectedDifficulty = run.difficultyClass;
              _isLoading = false;
            });
            return;
          }
        }
      }

      // Fallback: populate from riverData
      setState(() {
        _runNameController.text = sectionName?.toString() ?? '';
        _selectedDifficulty = difficulty?.toString();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading run data: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
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
    _optimalMinController.dispose();
    _optimalMaxController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    if (_riverRun == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot save: Run data not loaded'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final updatedRun = _riverRun!.copyWith(
        name: _runNameController.text.trim(),
        difficultyClass: _selectedDifficulty!,
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
        optimalFlowMin: _optimalMinController.text.trim().isNotEmpty
            ? double.tryParse(_optimalMinController.text.trim())
            : null,
        optimalFlowMax: _optimalMaxController.text.trim().isNotEmpty
            ? double.tryParse(_optimalMaxController.text.trim())
            : null,
      );

      await RiverRunService.updateRun(updatedRun);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('River run updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(
          context,
        ).pop(true); // Return true to indicate changes were saved
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating river run: $e'),
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
        title: const Text('Edit River Run'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: _isLoading && _riverRun == null
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Admin notice
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.admin_panel_settings,
                            color: Colors.blue[700],
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Admin Mode: Editing river run details',
                              style: TextStyle(
                                color: Colors.blue[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Run Information
                    Text(
                      'Run Information',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
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
                          child: Text(difficulty),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedDifficulty = value!;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Difficulty is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Describe the run characteristics',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),

                    // Physical Details
                    Text(
                      'Physical Details',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _lengthController,
                            decoration: const InputDecoration(
                              labelText: 'Length (km)',
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
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.landscape),
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
                        prefixIcon: Icon(Icons.place),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _takeOutController,
                      decoration: const InputDecoration(
                        labelText: 'Take-out Location',
                        hintText: 'e.g., Town Park',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.flag),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Flow Information
                    Text(
                      'Flow Information',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
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
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.arrow_downward),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _maxFlowController,
                            decoration: const InputDecoration(
                              labelText: 'Max Flow (m³/s)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.arrow_upward),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _optimalMinController,
                            decoration: const InputDecoration(
                              labelText: 'Optimal Min (m³/s)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.check_circle_outline),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _optimalMaxController,
                            decoration: const InputDecoration(
                              labelText: 'Optimal Max (m³/s)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.check_circle),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Additional Information
                    Text(
                      'Additional Information',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _seasonController,
                      decoration: const InputDecoration(
                        labelText: 'Best Season',
                        hintText: 'e.g., April-October, Spring runoff',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_month),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _permitsController,
                      decoration: const InputDecoration(
                        labelText: 'Permits Required',
                        hintText: 'e.g., None, or permit details',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.assignment),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _hazardsController,
                      decoration: const InputDecoration(
                        labelText: 'Known Hazards',
                        hintText:
                            'Comma-separated (e.g., Undercut rocks, strainers)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.warning),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 32),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveChanges,
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
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Save Changes',
                                style: TextStyle(fontSize: 16),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }
}
