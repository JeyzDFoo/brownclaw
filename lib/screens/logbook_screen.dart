import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/logbook_provider.dart';
import 'logbook_entry_screen.dart';

class LogBookScreen extends StatefulWidget {
  const LogBookScreen({super.key});

  @override
  State<LogBookScreen> createState() => _LogBookScreenState();
}

class _LogBookScreenState extends State<LogBookScreen>
    with AutomaticKeepAliveClientMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  bool get wantKeepAlive => true; // Keep state alive when navigating away

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
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return Scaffold(
      body: Consumer<UserProvider>(
        builder: (context, userProvider, child) {
          final user = userProvider.user;
          if (user == null) {
            return const Center(
              child: Text('Please sign in to view your logbook'),
            );
          }

          return StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('river_descents')
                .where('userId', isEqualTo: user.uid)
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                debugPrint('Error snapshot: ${snapshot.error}');
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
                        'Tap the + button to log your first adventure!',
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
                  final timestamp = data['timestamp'] as Timestamp?;
                  final difficulty = data['difficulty'] ?? 'Unknown';
                  const difficultyColor = Colors.teal;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          // Future: Navigate to detail view
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border(
                              left: BorderSide(
                                color: difficultyColor,
                                width: 4,
                              ),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header Section with Key Stats
                                Row(
                                  children: [
                                    // Rating Emoji as leading icon
                                    if (data['rating'] != null &&
                                        data['rating'] > 0)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 12,
                                        ),
                                        child: Text(
                                          _getRatingEmoji(
                                            (data['rating'] as num).toDouble(),
                                          ),
                                          style: const TextStyle(fontSize: 32),
                                        ),
                                      ),
                                    // Primary Info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            data['riverName'] ??
                                                'Unknown River',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleLarge
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 18,
                                                ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.location_on,
                                                size: 14,
                                                color: Colors.grey[600],
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  data['section'] ??
                                                      'Unknown Section',
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Actions Menu
                                    if (data['userId'] == user.uid)
                                      PopupMenuButton<String>(
                                        icon: Icon(
                                          Icons.more_vert,
                                          color: Colors.grey[600],
                                        ),
                                        onSelected: (value) async {
                                          if (value == 'edit') {
                                            // Set the editing entry in the provider
                                            context
                                                .read<LogbookProvider>()
                                                .setEditingEntry(doc.id, data);

                                            final result =
                                                await Navigator.of(
                                                  context,
                                                ).push(
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        const LogbookEntryScreen(),
                                                  ),
                                                );

                                            // Clear editing state when returning
                                            if (mounted) {
                                              context
                                                  .read<LogbookProvider>()
                                                  .clearEditingEntry();
                                            }

                                            if (result == true && mounted) {
                                              // Entry was edited successfully
                                            }
                                          } else if (value == 'delete') {
                                            _deleteLogEntry(doc.id);
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(
                                            value: 'edit',
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.edit,
                                                  color: Colors.orange,
                                                ),
                                                SizedBox(width: 8),
                                                Text('Edit'),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.delete,
                                                  color: Colors.red,
                                                ),
                                                SizedBox(width: 8),
                                                Text('Delete'),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Chips/Badges Section
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    // Difficulty Chip
                                    _buildChip(
                                      icon: Icons.trending_up,
                                      label: difficulty,
                                      backgroundColor: difficultyColor
                                          .withOpacity(0.15),
                                      textColor: difficultyColor,
                                    ),
                                    // Run Date Chip
                                    _buildChip(
                                      icon: Icons.calendar_today,
                                      label:
                                          data['runDate'] ??
                                          data['date'] ??
                                          'Unknown',
                                      backgroundColor: Colors.blue.withOpacity(
                                        0.1,
                                      ),
                                      textColor: Colors.blue[700]!,
                                    ),
                                    // Flow Chip
                                    if (data['discharge'] != null)
                                      _buildChip(
                                        icon: Icons.water_drop,
                                        label:
                                            '${(data['discharge'] as num).toStringAsFixed(1)} m³/s',
                                        backgroundColor: Colors.cyan
                                            .withOpacity(0.1),
                                        textColor: Colors.cyan[700]!,
                                      ),
                                  ],
                                ),

                                // Visual Separator
                                if (data['notes']?.toString().isNotEmpty ==
                                    true) ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    height: 1,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.grey.withOpacity(0.0),
                                          Colors.grey.withOpacity(0.3),
                                          Colors.grey.withOpacity(0.0),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Notes Section
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.notes,
                                        size: 18,
                                        color: Colors.grey[600],
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          data['notes'],
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: Colors.grey[800],
                                                height: 1.4,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],

                                const SizedBox(height: 16),

                                // Footer Metadata
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.person_outline,
                                        size: 16,
                                        color: Colors.grey[600],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        data['userName'] ?? 'Unknown Kayaker',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[700],
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
                                            ? _formatTimestamp(
                                                timestamp.toDate(),
                                              )
                                            : 'Just now',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const LogbookEntryScreen()),
          );
          // Refresh is automatic due to StreamBuilder
          if (result == true && mounted) {
            // Entry was added successfully
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Log Descent'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
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

  Widget _buildChip({
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _getRatingEmoji(double rating) {
    if (rating == 1.0) return '😢';
    if (rating == 2.0) return '😐';
    if (rating == 3.0) return '😊';
    return '😐'; // Default
  }
}
