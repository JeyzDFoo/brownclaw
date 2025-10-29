import 'package:flutter/material.dart';

/// Header card for run detail screen
///
/// Displays:
/// - River section name and difficulty class
/// - Status indicator (runnable, too low, too high, etc.)
/// - Location
/// - Difficulty rating
/// - Recommended flow range
/// - Logbook statistics (last run date, total runs)
class RunHeaderCard extends StatelessWidget {
  final String section;
  final String sectionClass;
  final String status;
  final String location;
  final String difficulty;
  final double? minRunnable;
  final double? maxSafe;
  final int totalRuns;
  final DateTime? lastRanDate;

  const RunHeaderCard({
    super.key,
    required this.section,
    required this.sectionClass,
    required this.status,
    required this.location,
    required this.difficulty,
    this.minRunnable,
    this.maxSafe,
    this.totalRuns = 0,
    this.lastRanDate,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _getStatusIcon(status),
                  color: _getStatusColor(status),
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (section.isNotEmpty)
                        Text(
                          '$section ($sectionClass)',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      if (section.isEmpty && sectionClass != 'Unknown')
                        Text(
                          sectionClass,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                ),
                // Logbook stats - top right
                if (totalRuns > 0) _buildLogbookStats(context),
              ],
            ),
            const SizedBox(height: 16),

            // Location
            Row(
              children: [
                Icon(Icons.location_on, color: Colors.grey[600], size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    location,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              ],
            ),

            // Difficulty
            if (difficulty != 'Unknown') ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.trending_up, color: Colors.grey[600], size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Difficulty: $difficulty',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ],

            // Recommended flow range
            if (minRunnable != null && maxSafe != null && minRunnable! > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.water_drop, color: Colors.blue[600], size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Recommended flow: $minRunnable-$maxSafe m³/s',
                      style: TextStyle(
                        color: Colors.blue[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLogbookStats(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event, size: 14, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              lastRanDate != null ? _formatDate(lastRanDate!) : 'Never',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.format_list_numbered, size: 14, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              '$totalRuns ${totalRuns == 1 ? 'run' : 'runs'}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return months == 1 ? '1 month ago' : '$months months ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return years == 1 ? '1 year ago' : '$years years ago';
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'runnable':
      case 'good':
        return Icons.check_circle;
      case 'too low':
      case 'low':
        return Icons.arrow_downward;
      case 'too high':
      case 'high':
      case 'dangerous':
        return Icons.warning;
      case 'unknown':
      default:
        return Icons.help_outline;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'runnable':
      case 'good':
        return Colors.green;
      case 'too low':
      case 'low':
        return Colors.orange;
      case 'too high':
      case 'high':
      case 'dangerous':
        return Colors.red;
      case 'unknown':
      default:
        return Colors.grey;
    }
  }
}
