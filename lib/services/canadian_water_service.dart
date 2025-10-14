import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class CanadianWaterService {
  static const String baseUrl =
      'https://wateroffice.ec.gc.ca/services/real_time_data/csv/inline';

  // Popular Canadian whitewater rivers with their station IDs
  static const Map<String, Map<String, dynamic>> canadianRivers = {
    'Ottawa River': {
      'stationId': '02KF005', // Ottawa River near Ottawa
      'section': 'Champlain Bridge',
      'location': 'Ontario/Quebec',
      'difficulty': 'Class I-II',
      'minRunnable': 50.0, // cubic meters per second
      'maxSafe': 300.0,
    },
    'Madawaska River': {
      'stationId': '02KA006', // Madawaska River at Arnprior
      'section': 'Lower Madawaska',
      'location': 'Ontario',
      'difficulty': 'Class II-III',
      'minRunnable': 15.0,
      'maxSafe': 80.0,
    },
    'French River': {
      'stationId': '02ED003', // French River near Monetville
      'section': 'Big Pine Rapids',
      'location': 'Ontario',
      'difficulty': 'Class II-IV',
      'minRunnable': 20.0,
      'maxSafe': 100.0,
    },
    'Bow River': {
      'stationId': '05BH004', // Bow River at Calgary
      'section': 'Harvey Passage',
      'location': 'Alberta',
      'difficulty': 'Class II-III',
      'minRunnable': 30.0,
      'maxSafe': 150.0,
    },
    'Kicking Horse River': {
      'stationId': '05AD007', // Kicking Horse River at Golden
      'section': 'Lower Canyon',
      'location': 'British Columbia',
      'difficulty': 'Class III-IV',
      'minRunnable': 25.0,
      'maxSafe': 120.0,
    },
  };

  static Future<List<Map<String, dynamic>>> fetchRiverLevels() async {
    List<Map<String, dynamic>> riverData = [];

    for (String riverName in canadianRivers.keys) {
      try {
        final riverInfo = canadianRivers[riverName]!;
        final stationId = riverInfo['stationId'];

        // Fetch data for this station
        final url =
            '$baseUrl?stations[]=$stationId&parameters[]=47'; // Parameter 47 is discharge
        print('🌊 Fetching data for $riverName from: $url');

        final response = await http.get(Uri.parse(url));

        if (response.statusCode == 200) {
          final csvData = response.body;
          final currentFlow = _parseLatestFlow(csvData);

          if (currentFlow != null) {
            final status = _determineStatus(
              currentFlow,
              riverInfo['minRunnable'],
              riverInfo['maxSafe'],
            );
            final trend = _determineTrend(); // Simplified for now

            riverData.add({
              'name': riverName,
              'section': riverInfo['section'],
              'location': riverInfo['location'],
              'currentLevel': '${currentFlow.toStringAsFixed(1)} m³/s',
              'currentFlowValue': currentFlow,
              'status': status['label'],
              'statusColor': status['color'],
              'difficulty': riverInfo['difficulty'],
              'lastUpdated': 'Just now',
              'trend': trend,
              'minRunnable': '${riverInfo['minRunnable']} m³/s',
              'maxSafe': '${riverInfo['maxSafe']} m³/s',
              'stationId': stationId,
            });
          }
        } else {
          print(
            '❌ Failed to fetch data for $riverName: ${response.statusCode}',
          );
        }
      } catch (e) {
        print('❌ Error fetching data for $riverName: $e');
      }
    }

    // If no real data, return mock data as fallback
    if (riverData.isEmpty) {
      return _getMockData();
    }

    return riverData;
  }

  static double? _parseLatestFlow(String csvData) {
    try {
      final lines = csvData.split('\n');

      // Skip header and find the most recent data point
      for (int i = lines.length - 1; i >= 1; i--) {
        final line = lines[i].trim();
        if (line.isNotEmpty) {
          final parts = line.split(',');
          if (parts.length >= 3) {
            final flowStr = parts[2].trim();
            if (flowStr.isNotEmpty && flowStr != 'No Data') {
              return double.tryParse(flowStr);
            }
          }
        }
      }
    } catch (e) {
      print('❌ Error parsing CSV data: $e');
    }
    return null;
  }

  static Map<String, dynamic> _determineStatus(
    double flow,
    double minRunnable,
    double maxSafe,
  ) {
    if (flow < minRunnable * 0.8) {
      return {'label': 'Too Low', 'color': Colors.red};
    } else if (flow < minRunnable) {
      return {'label': 'Low', 'color': Colors.orange};
    } else if (flow <= minRunnable * 2) {
      return {'label': 'Good', 'color': Colors.green};
    } else if (flow <= maxSafe) {
      return {'label': 'High', 'color': Colors.blue};
    } else {
      return {'label': 'Too High', 'color': Colors.red};
    }
  }

  static String _determineTrend() {
    // Simplified - in a real app, you'd compare with previous readings
    final random = DateTime.now().millisecond % 3;
    switch (random) {
      case 0:
        return 'rising';
      case 1:
        return 'falling';
      default:
        return 'stable';
    }
  }

  static List<Map<String, dynamic>> _getMockData() {
    return [
      {
        'name': 'Ottawa River',
        'section': 'Champlain Bridge',
        'location': 'Ontario/Quebec',
        'currentLevel': '125.5 m³/s',
        'currentFlowValue': 125.5,
        'status': 'Good',
        'statusColor': Colors.green,
        'difficulty': 'Class I-II',
        'lastUpdated': 'Mock Data',
        'trend': 'stable',
        'minRunnable': '50.0 m³/s',
        'maxSafe': '300.0 m³/s',
        'stationId': '02KF005',
      },
      {
        'name': 'Madawaska River',
        'section': 'Lower Madawaska',
        'location': 'Ontario',
        'currentLevel': '45.2 m³/s',
        'currentFlowValue': 45.2,
        'status': 'Good',
        'statusColor': Colors.green,
        'difficulty': 'Class II-III',
        'lastUpdated': 'Mock Data',
        'trend': 'rising',
        'minRunnable': '15.0 m³/s',
        'maxSafe': '80.0 m³/s',
        'stationId': '02KA006',
      },
    ];
  }
}
