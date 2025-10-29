import 'package:flutter/material.dart';
import '../../widgets/transalta_flow_widget.dart';

/// River detail section specifically for Kananaskis rivers
///
/// Kananaskis rivers use TransAlta Barrier Dam data instead of
/// Government of Canada hydrometric data. This widget displays:
/// - TransAlta flow forecast and dam release schedule
/// - Premium paywall for extended forecasts
///
/// Does NOT display:
/// - Standard current conditions card
/// - Weather forecast widget (included in TransAlta widget)
/// - Historical discharge charts (TransAlta provides forecast instead)
class KananaskisRiverSection extends StatelessWidget {
  /// Threshold for runnable flow (in cubic meters per second)
  final double flowThreshold;

  const KananaskisRiverSection({super.key, this.flowThreshold = 20.0});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // TransAlta Flow Widget - Shows dam release schedule and forecast
        TransAltaFlowWidget(threshold: flowThreshold),
        const SizedBox(height: 16),

        // Information card about TransAlta data
        Card(
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TransAlta Data',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Flow data for Kananaskis rivers comes directly from TransAlta\'s Barrier Dam release schedule. '
                        'This provides more accurate predictions for dam-controlled flows than standard gauge data.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
