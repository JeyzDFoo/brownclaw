import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LogBookScreen extends StatefulWidget {
  const LogBookScreen({super.key});

  @override
  State<LogBookScreen> createState() => _LogBookScreenState();
}

class _LogBookScreenState extends State<LogBookScreen> {
  final _riverNameController = TextEditingController();
  final _sectionController = TextEditingController();
  final _notesController = TextEditingController();
  final _waterLevelController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _selectedDifficulty = 'Class II';

  @override
  void dispose() {
    _riverNameController.dispose();
    _sectionController.dispose();
    _notesController.dispose();
    _waterLevelController.dispose();
    super.dispose();
  }

  Future<void> _addLogEntry() async {
    if (_riverNameController.text.trim().isEmpty ||
        _sectionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in river name and section')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('river_descents').add({
        'riverName': _riverNameController.text.trim(),
        'section': _sectionController.text.trim(),
        'difficulty': _selectedDifficulty,
        'waterLevel': _waterLevelController.text.trim(),
        'notes': _notesController.text.trim(),
        'userId': user.uid,
        'userEmail': user.email,
        'userName': user.displayName ?? user.email?.split('@')[0] ?? 'Kayaker',
        'timestamp': FieldValue.serverTimestamp(),
        'date': DateTime.now().toIso8601String().split(
          'T',
        )[0], // Store date for easier querying
      });
      _riverNameController.clear();
      _sectionController.clear();
      _notesController.clear();
      _waterLevelController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Log entry added successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error adding entry: $e')));
    }
  }

  Future<void> _deleteLogEntry(String entryId) async {
    try {
      await _firestore.collection('river_descents').doc(entryId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('River descent deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting descent: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Add Entry Section
        Card(
          elevation: 4,
          margin: const EdgeInsets.all(16.0),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Log River Descent',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _riverNameController,
                  decoration: const InputDecoration(
                    labelText: 'River Name',
                    hintText: 'e.g., Kicking Horse River',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.water),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _sectionController,
                  decoration: const InputDecoration(
                    labelText: 'Section/Run',
                    hintText: 'e.g., Upper',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedDifficulty,
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
                      _selectedDifficulty = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _waterLevelController,
                  decoration: const InputDecoration(
                    labelText: 'Water Level',
                    hintText: 'e.g., 2.5 ft, Medium, High',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.height),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    hintText: 'How was your run? Any highlights or tips?',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.notes),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _addLogEntry,
                    icon: const Icon(Icons.add),
                    label: const Text('Log Descent'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ), // Entries List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('river_descents')
                .where(
                  'userId',
                  isEqualTo: FirebaseAuth.instance.currentUser?.uid,
                )
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                print('Error snapshot: ${snapshot.error}');
                return Center(child: Text('Error!: ${snapshot.error}'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.kayaking, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No river descents logged yet',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Start logging your kayaking adventures!',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final currentUser = FirebaseAuth.instance.currentUser;
                  final timestamp = data['timestamp'] as Timestamp?;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.water,
                                color: Theme.of(context).primaryColor,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  data['riverName'] ?? 'Unknown River',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                              if (data['userId'] == currentUser?.uid)
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => _deleteLogEntry(doc.id),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                data['section'] ?? 'Unknown Section',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Icon(
                                Icons.trending_up,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                data['difficulty'] ?? 'Unknown',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          if (data['waterLevel']?.toString().isNotEmpty ==
                              true) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.height,
                                  size: 16,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Water Level: ${data['waterLevel']}',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ],
                          if (data['notes']?.toString().isNotEmpty == true) ...[
                            const SizedBox(height: 8),
                            Text(
                              data['notes'],
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(
                                Icons.person,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                data['userName'] ?? 'Unknown Kayaker',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                Icons.access_time,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                timestamp != null
                                    ? _formatTimestamp(timestamp.toDate())
                                    : 'Just now',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
