import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../models/river_descent.dart';
import '../utils/debug_logger.dart';

/// Widget to display the user's historical runs on a specific river
class UserRunsHistoryWidget extends StatelessWidget {
  final String riverRunId;
  final String riverName;

  const UserRunsHistoryWidget({
    super.key,
    required this.riverRunId,
    required this.riverName,
  });

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;

    if (user == null) {
      DebugLogger.warning('UserRunsHistoryWidget: No user authenticated');
      return const SizedBox.shrink();
    }

    DebugLogger.log(
      'UserRunsHistoryWidget: Fetching runs for riverRunId: $riverRunId, userId: ${user.uid}',
    );

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('river_descents')
          .where('userId', isEqualTo: user.uid)
          .where('riverRunId', isEqualTo: riverRunId)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          DebugLogger.error(
            'UserRunsHistoryWidget: Error fetching runs\n'
            '   Error type: ${snapshot.error.runtimeType}\n'
            '   Error message: ${snapshot.error}\n'
            '   RiverRunId: $riverRunId\n'
            '   UserId: ${user.uid}',
          );
          return _buildErrorCard(context, snapshot.error.toString());
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          if (kDebugMode) {
            print('⏳ UserRunsHistoryWidget: Loading runs...');
          }
          return _buildLoadingCard(context);
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          if (kDebugMode) {
            print(
              '📭 UserRunsHistoryWidget: No runs found for riverRunId: $riverRunId',
            );
          }
          return _buildNoRunsCard(context);
        }

        try {
          final runDocs = snapshot.data!.docs;
          final runs = runDocs.map((doc) {
            return RiverDescent.fromMap(
              doc.data() as Map<String, dynamic>,
              docId: doc.id,
            );
          }).toList();

          if (kDebugMode) {
            print(
              '✅ UserRunsHistoryWidget: Successfully loaded ${runs.length} runs',
            );
            print(
              '   Run dates: ${runs.map((r) => r.formattedDate).join(', ')}',
            );
          }

          return _buildRunsCard(context, runs, runDocs);
        } catch (e, stackTrace) {
          if (kDebugMode) {
            print('❌ UserRunsHistoryWidget: Error parsing run data');
            print('   Error: $e');
            print('   Stack trace: $stackTrace');
          }
          return _buildErrorCard(context, 'Error parsing run data: $e');
        }
      },
    );
  }

  Widget _buildLoadingCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.history,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Your Runs on This River',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const SizedBox(
              height: 80, // Minimum height to prevent layout shift
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context, String error) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red[400]),
                const SizedBox(width: 8),
                Text(
                  'Your Runs on This River',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.red[400],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Error Loading Runs',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(error, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 8),
                  Text(
                    'RiverRunId: $riverRunId',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: Theme.of(
                        context,
                      ).textTheme.bodySmall?.color?.withOpacity(0.6),
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

  Widget _buildNoRunsCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.history,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Your Runs on This River',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.kayaking,
                    size: 48,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.3),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No runs logged yet',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Add your first run in the Logbook tab!',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.5),
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

  Widget _buildRunsCard(
    BuildContext context,
    List<RiverDescent> runs,
    List<QueryDocumentSnapshot> runDocs,
  ) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.history,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your Runs on This River',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${runs.length} ${runs.length == 1 ? 'run' : 'runs'}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Show summary stats
            _buildSummaryStats(context, runs),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            // List of runs
            ...List.generate(
              runs.take(5).length,
              (index) => _buildRunItem(
                context,
                runs[index],
                runDocs[index].data() as Map<String, dynamic>,
              ),
            ),
            if (runs.length > 5) ...[
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Showing 5 of ${runs.length} runs',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryStats(BuildContext context, List<RiverDescent> runs) {
    // Calculate stats
    final runsWithRating = runs.where((r) => r.rating != null).toList();
    final avgRating = runsWithRating.isEmpty
        ? null
        : runsWithRating.map((r) => r.rating!).reduce((a, b) => a + b) /
              runsWithRating.length;

    // Get most recent and oldest run dates
    final dates = runs
        .where((r) => r.timestamp != null)
        .map((r) => r.timestamp!)
        .toList();
    dates.sort();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            context,
            Icons.calendar_today,
            'First Run',
            dates.isNotEmpty ? _formatDate(dates.first) : 'N/A',
          ),
          Container(
            width: 1,
            height: 40,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
          ),
          _buildStatItem(
            context,
            Icons.event,
            'Latest Run',
            dates.isNotEmpty ? _formatDate(dates.last) : 'N/A',
          ),
          if (avgRating != null) ...[
            Container(
              width: 1,
              height: 40,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
            ),
            _buildStatItemWithEmoji(
              context,
              'Avg Rating',
              '${avgRating.toStringAsFixed(1)}/3',
              _getRatingEmoji(avgRating),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildStatItemWithEmoji(
    BuildContext context,
    String label,
    String value,
    String emoji,
  ) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildRunItem(
    BuildContext context,
    RiverDescent run,
    Map<String, dynamic> data,
  ) {
    final date = run.timestamp ?? DateTime.now();
    final hasNotes = run.notes.isNotEmpty;
    final rating = run.rating;
    final discharge = data['discharge'] as num?;
    final difficulty = data['difficulty'] as String?;
    final tags = run.tags;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date circle
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _getMonthAbbr(date.month),
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  date.day.toString(),
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Run details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _formatDate(date),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (rating != null) _buildRatingStars(context, rating),
                  ],
                ),
                const SizedBox(height: 6),
                // Info row with difficulty and discharge
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (difficulty != null)
                      _buildInfoChip(
                        context,
                        Icons.trending_up,
                        difficulty,
                        Colors.teal,
                      ),
                    if (discharge != null)
                      _buildInfoChip(
                        context,
                        Icons.water_drop,
                        '${discharge.toStringAsFixed(1)} m³/s',
                        Colors.blue,
                      ),
                  ],
                ),
                // Tags
                if (tags != null && tags.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: tags
                        .take(3)
                        .map((tag) => _buildTag(context, tag))
                        .toList(),
                  ),
                ],
                // Notes
                if (hasNotes) ...[
                  const SizedBox(height: 6),
                  Text(
                    run.notes,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(BuildContext context, String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.secondaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        tag,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSecondaryContainer,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildRatingStars(BuildContext context, double rating) {
    return Text(_getRatingEmoji(rating), style: const TextStyle(fontSize: 20));
  }

  String _getRatingEmoji(double rating) {
    // Rating system matches logbook entry: 1.0 = 😢, 2.0 = 😐, 3.0 = 😊
    if (rating == 1.0) {
      return '😢'; // Poor run
    } else if (rating == 2.0) {
      return '😐'; // Okay run
    } else if (rating == 3.0) {
      return '😊'; // Great run
    } else {
      // For averages that fall between values, use closest emoji
      if (rating < 1.5) {
        return '😢';
      } else if (rating < 2.25) {
        return '😐';
      } else {
        return '😊';
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${_getMonthAbbr(date.month)} ${date.day}, ${date.year}';
  }

  String _getMonthAbbr(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }
}
