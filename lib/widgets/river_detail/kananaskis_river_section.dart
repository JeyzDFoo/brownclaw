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
    return TransAltaFlowWidget(threshold: flowThreshold);
  }
}
