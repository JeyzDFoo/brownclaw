import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/transalta_flow_data.dart';
import '../providers/transalta_provider.dart';

/// Widget showing TransAlta Barrier Dam flow information
///
/// Uses TransAltaProvider for centralized state management
class TransAltaFlowWidget extends StatelessWidget {
  final double threshold;

  const TransAltaFlowWidget({super.key, this.threshold = 20.0});

  @override
  Widget build(BuildContext context) {
    return Consumer<TransAltaProvider>(
      builder: (context, transAltaProvider, child) {
        // Fetch data if not already loaded
        if (!transAltaProvider.hasData &&
            !transAltaProvider.isLoading &&
            transAltaProvider.error == null) {
          Future.microtask(() => transAltaProvider.fetchFlowData());
        }

        return Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '🌊 Kananaskis River Flow',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: transAltaProvider.isLoading
                          ? null
                          : () => transAltaProvider.fetchFlowData(
                              forceRefresh: true,
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Barrier Dam (≥${threshold.toStringAsFixed(0)} m³/s)',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const Divider(height: 24),

                if (transAltaProvider.isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (transAltaProvider.error != null)
                  Center(
                    child: Column(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          transAltaProvider.error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => transAltaProvider.fetchFlowData(
                            forceRefresh: true,
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                else if (transAltaProvider.hasData)
                  _buildContent(transAltaProvider),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(TransAltaProvider provider) {
    final flowData = provider.flowData;
    if (flowData == null) return const SizedBox();

    final highFlowPeriods = provider.getAllFlowPeriods(threshold: threshold);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Current Flow
        _buildCurrentFlow(flowData.currentFlow),

        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 16),

        // High Flow Schedule
        _buildHighFlowSchedule(highFlowPeriods),
      ],
    );
  }

  Widget _buildCurrentFlow(HourlyFlowEntry? current) {
    if (current == null) {
      return const Text('No current flow data available');
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getFlowStatusColor(current.flowStatus).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _getFlowStatusColor(current.flowStatus).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                current.flowStatus.emoji,
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 8),
              const Text(
                'Current Flow',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${current.barrierFlow} m³/s',
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),
          Text(
            current.flowStatus.description,
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildHighFlowSchedule(List<HighFlowPeriod> highFlowPeriods) {
    if (highFlowPeriods.isEmpty) {
      return Column(
        children: [
          const Text(
            'Flow Schedule',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'No flow periods ≥${threshold.toStringAsFixed(0)} m³/s in the forecast',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      );
    }

    // Group periods by day
    final Map<int, List<HighFlowPeriod>> periodsByDay = {};
    for (final period in highFlowPeriods) {
      periodsByDay.putIfAbsent(period.dayNumber, () => []).add(period);
    }

    // Sort days
    final sortedDays = periodsByDay.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Flow Schedule (≥${threshold.toStringAsFixed(0)} m³/s)',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Includes 45min travel time from dam to window maker',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 12),

        ...sortedDays.map((day) => _buildDayCard(day, periodsByDay[day]!)),
      ],
    );
  }

  Widget _buildDayCard(int dayNumber, List<HighFlowPeriod> periods) {
    final firstPeriod = periods.first;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  firstPeriod.dayName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    firstPeriod.dateString,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Show each period
            ...periods.asMap().entries.map((entry) {
              final index = entry.key;
              final period = entry.value;

              return Padding(
                padding: EdgeInsets.only(
                  bottom: index < periods.length - 1 ? 8.0 : 0.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (periods.length > 1)
                      Text(
                        'Period ${index + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                    if (periods.length > 1) const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              size: 16,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              period.arrivalTimeRange,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const Icon(
                              Icons.water_drop,
                              size: 16,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              period.flowRangeString,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '(${period.totalHours}h)',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Color _getFlowStatusColor(FlowStatus status) {
    switch (status) {
      case FlowStatus.offline:
        return Colors.grey;
      case FlowStatus.tooLow:
        return Colors.orange;
      case FlowStatus.low:
        return Colors.amber;
      case FlowStatus.moderate:
        return Colors.green;
      case FlowStatus.high:
        return Colors.blue;
    }
  }
}
