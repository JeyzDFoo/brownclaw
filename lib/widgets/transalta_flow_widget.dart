import 'package:flutter/material.dart';
import '../models/transalta_flow_data.dart';
import '../services/transalta_service.dart';

/// Example widget showing TransAlta Barrier Dam flow information
///
/// This demonstrates how to use the TransAltaService in your app.
/// You can customize the UI to match your app's design.
class TransAltaFlowWidget extends StatefulWidget {
  final double threshold;

  const TransAltaFlowWidget({Key? key, this.threshold = 20.0})
    : super(key: key);

  @override
  State<TransAltaFlowWidget> createState() => _TransAltaFlowWidgetState();
}

class _TransAltaFlowWidgetState extends State<TransAltaFlowWidget> {
  bool _isLoading = true;
  TransAltaFlowData? _flowData;
  List<HighFlowPeriod>? _highFlowPeriods;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await transAltaService.fetchFlowData();

      if (data != null) {
        final periods = data.getHighFlowHours(threshold: widget.threshold);

        setState(() {
          _flowData = data;
          _highFlowPeriods = periods;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Unable to fetch flow data';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _isLoading ? null : () => _loadData(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Barrier Dam (≥${widget.threshold} m³/s)',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const Divider(height: 24),

            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              Center(
                child: Column(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 8),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadData,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            else
              _buildContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_flowData == null) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Current Flow
        _buildCurrentFlow(),

        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 16),

        // High Flow Schedule
        _buildHighFlowSchedule(),
      ],
    );
  }

  Widget _buildCurrentFlow() {
    final current = _flowData?.currentFlow;

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
          Text(
            'Water arrives downstream: ${current.getArrivalTimeString()}',
            style: const TextStyle(fontSize: 12),
          ),
          Text(
            'Period: ${current.hourEndingString}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildHighFlowSchedule() {
    if (_highFlowPeriods == null || _highFlowPeriods!.isEmpty) {
      return Column(
        children: [
          const Text(
            'High Flow Schedule',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'No high flow periods ≥${widget.threshold} m³/s in the forecast',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'High Flow Schedule (≥${widget.threshold} m³/s)',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          '+${TransAltaService.travelTimeMinutes}min travel time from dam',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 12),

        ..._highFlowPeriods!.map((period) => _buildDayCard(period)).toList(),
      ],
    );
  }

  Widget _buildDayCard(HighFlowPeriod period) {
    final isToday = period.dayNumber == 0;

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
                  period.dateString,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isToday)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Today',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  period.arrivalTimeRange,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${period.totalHours} hours of high flow',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
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
