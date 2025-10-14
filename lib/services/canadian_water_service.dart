import 'package:flutter/foundation.dart';
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
    'Elbow River': {
      'stationId': '05BJ004', // Elbow River at Calgary
      'section': 'Urban Canyon',
      'location': 'Alberta',
      'difficulty': 'Class II',
      'minRunnable': 8.0,
      'maxSafe': 40.0,
    },
    'Petawawa River': {
      'stationId': '02KB001', // Petawawa River near Petawawa
      'section': 'Five Mile Rapids',
      'location': 'Ontario',
      'difficulty': 'Class III-IV',
      'minRunnable': 30.0,
      'maxSafe': 120.0,
    },
    'Gatineau River': {
      'stationId': '02KD007', // Gatineau River near Ottawa
      'section': 'Paugan Falls',
      'location': 'Quebec',
      'difficulty': 'Class III',
      'minRunnable': 20.0,
      'maxSafe': 80.0,
    },
    'Rouge River': {
      'stationId': '02KB008', // Rouge River at Calumet
      'section': 'Seven Sisters',
      'location': 'Quebec',
      'difficulty': 'Class IV-V',
      'minRunnable': 15.0,
      'maxSafe': 60.0,
    },
    'Yukon River': {
      'stationId': '09AB004', // Yukon River at Whitehorse
      'section': 'Whitehorse Rapids',
      'location': 'Yukon',
      'difficulty': 'Class II-III',
      'minRunnable': 150.0,
      'maxSafe': 800.0,
    },
  };

  // Get all available rivers for search
  static List<Map<String, dynamic>> getAllRivers() {
    return canadianRivers.entries.map((entry) {
      final riverData = Map<String, dynamic>.from(entry.value);
      riverData['name'] = entry.key;
      return riverData;
    }).toList();
  }

  // Search rivers by name, section, or location
  static List<Map<String, dynamic>> searchRivers(String query) {
    if (query.isEmpty) return getAllRivers();

    final lowercaseQuery = query.toLowerCase();
    return getAllRivers().where((river) {
      final name = (river['name'] as String).toLowerCase();
      final section = (river['section'] as String).toLowerCase();
      final location = (river['location'] as String).toLowerCase();

      return name.contains(lowercaseQuery) ||
          section.contains(lowercaseQuery) ||
          location.contains(lowercaseQuery);
    }).toList();
  }

  static Future<List<Map<String, dynamic>>> fetchRiverLevels() async {
    // Check if running on web platform - CORS restrictions prevent direct API access
    if (kIsWeb) {
      print('🌐 Running on web - using mock data due to CORS restrictions');
      return _getWebMockData();
    }

    List<Map<String, dynamic>> riverData = [];
    List<String> failedStations = [];

    for (String riverName in canadianRivers.keys) {
      try {
        final riverInfo = canadianRivers[riverName]!;
        final stationId = riverInfo['stationId'];

        // Add any problematic stations here if needed
        // Currently all stations should work

        // Fetch data for this station with timeout
        final url =
            '$baseUrl?stations[]=$stationId&parameters[]=47'; // Parameter 47 is discharge
        print('🌊 Fetching data for $riverName from: $url');

        final response = await http
            .get(Uri.parse(url))
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                throw Exception('Request timeout for station $stationId');
              },
            );

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
              'province': riverInfo['location'],
              'flowRate': currentFlow,
              'lastUpdate': 'Just now',
            });
            print('✅ Successfully loaded data for $riverName');
          } else {
            print('⚠️ No flow data available for $riverName');
            failedStations.add(riverName);
          }
        } else {
          print(
            '❌ Failed to fetch data for $riverName: HTTP ${response.statusCode}',
          );
          failedStations.add(riverName);
        }
      } catch (e) {
        print('❌ Error fetching data for $riverName: $e');
        failedStations.add(riverName);
      }
    }

    // Add mock data for failed stations so they still appear in the list
    for (String failedRiver in failedStations) {
      final riverInfo = canadianRivers[failedRiver]!;
      final mockFlow = (riverInfo['minRunnable'] + riverInfo['maxSafe']) / 2;
      final status = _determineStatus(
        mockFlow,
        riverInfo['minRunnable'],
        riverInfo['maxSafe'],
      );

      riverData.add({
        'name': failedRiver,
        'section': riverInfo['section'],
        'location': riverInfo['location'],
        'currentLevel': '${mockFlow.toStringAsFixed(1)} m³/s',
        'currentFlowValue': mockFlow,
        'status': status['label'],
        'statusColor': Colors.grey,
        'difficulty': riverInfo['difficulty'],
        'lastUpdated': 'Data unavailable',
        'trend': 'stable',
        'minRunnable': '${riverInfo['minRunnable']} m³/s',
        'maxSafe': '${riverInfo['maxSafe']} m³/s',
        'stationId': riverInfo['stationId'],
        'province': riverInfo['location'],
        'flowRate': mockFlow,
        'lastUpdate': 'Data unavailable',
      });
    }

    // If no data at all, return full mock data as fallback
    if (riverData.isEmpty) {
      print('⚠️ No river data available, using mock data');
      return _getMockData();
    }

    print(
      '📊 Loaded ${riverData.length} rivers (${riverData.length - failedStations.length} real, ${failedStations.length} mock)',
    );
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

  // Comprehensive mock data for web platform (due to CORS restrictions)
  static List<Map<String, dynamic>> _getWebMockData() {
    final now = DateTime.now();
    final timeString =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return [
      {
        'name': 'Ottawa River',
        'section': 'Champlain Bridge',
        'location': 'Ontario/Quebec',
        'currentLevel': '125.5 m³/s',
        'currentFlowValue': 125.5,
        'status': 'normal',
        'statusColor': Colors.green,
        'difficulty': 'Class I-II',
        'lastUpdated': 'Demo Data',
        'trend': 'stable',
        'minRunnable': '50.0 m³/s',
        'maxSafe': '300.0 m³/s',
        'stationId': '02KF005',
        'province': 'Ontario/Quebec',
        'flowRate': 125.5,
        'lastUpdate': 'Demo Data - $timeString',
      },
      {
        'name': 'Madawaska River',
        'section': 'Lower Madawaska',
        'location': 'Ontario',
        'currentLevel': '45.2 m³/s',
        'currentFlowValue': 45.2,
        'status': 'normal',
        'statusColor': Colors.green,
        'difficulty': 'Class II-III',
        'lastUpdated': 'Demo Data',
        'trend': 'rising',
        'minRunnable': '15.0 m³/s',
        'maxSafe': '80.0 m³/s',
        'stationId': '02KA006',
        'province': 'Ontario',
        'flowRate': 45.2,
        'lastUpdate': 'Demo Data - $timeString',
      },
      {
        'name': 'French River',
        'section': 'Big Pine Rapids',
        'location': 'Ontario',
        'currentLevel': '65.8 m³/s',
        'currentFlowValue': 65.8,
        'status': 'normal',
        'statusColor': Colors.green,
        'difficulty': 'Class II-IV',
        'lastUpdated': 'Demo Data',
        'trend': 'stable',
        'minRunnable': '20.0 m³/s',
        'maxSafe': '100.0 m³/s',
        'stationId': '02ED003',
        'province': 'Ontario',
        'flowRate': 65.8,
        'lastUpdate': 'Demo Data - $timeString',
      },
      {
        'name': 'Bow River',
        'section': 'Harvey Passage',
        'location': 'Alberta',
        'currentLevel': '85.3 m³/s',
        'currentFlowValue': 85.3,
        'status': 'normal',
        'statusColor': Colors.green,
        'difficulty': 'Class II-III',
        'lastUpdated': 'Demo Data',
        'trend': 'stable',
        'minRunnable': '30.0 m³/s',
        'maxSafe': '150.0 m³/s',
        'stationId': '05BH004',
        'province': 'Alberta',
        'flowRate': 85.3,
        'lastUpdate': 'Demo Data - $timeString',
      },
      {
        'name': 'Kicking Horse River',
        'section': 'Lower Canyon',
        'location': 'British Columbia',
        'currentLevel': '72.1 m³/s',
        'currentFlowValue': 72.1,
        'status': 'normal',
        'statusColor': Colors.green,
        'difficulty': 'Class III-IV',
        'lastUpdated': 'Demo Data',
        'trend': 'falling',
        'minRunnable': '25.0 m³/s',
        'maxSafe': '120.0 m³/s',
        'stationId': '05AD007',
        'province': 'British Columbia',
        'flowRate': 72.1,
        'lastUpdate': 'Demo Data - $timeString',
      },
      {
        'name': 'Elbow River',
        'section': 'Urban Canyon',
        'location': 'Alberta',
        'currentLevel': '18.4 m³/s',
        'currentFlowValue': 18.4,
        'status': 'normal',
        'statusColor': Colors.green,
        'difficulty': 'Class II',
        'lastUpdated': 'Demo Data',
        'trend': 'stable',
        'minRunnable': '8.0 m³/s',
        'maxSafe': '40.0 m³/s',
        'stationId': '05BJ004',
        'province': 'Alberta',
        'flowRate': 18.4,
        'lastUpdate': 'Demo Data - $timeString',
      },
      {
        'name': 'Petawawa River',
        'section': 'Five Mile Rapids',
        'location': 'Ontario',
        'currentLevel': '75.6 m³/s',
        'currentFlowValue': 75.6,
        'status': 'normal',
        'statusColor': Colors.green,
        'difficulty': 'Class III-IV',
        'lastUpdated': 'Demo Data',
        'trend': 'rising',
        'minRunnable': '30.0 m³/s',
        'maxSafe': '120.0 m³/s',
        'stationId': '02KB001',
        'province': 'Ontario',
        'flowRate': 75.6,
        'lastUpdate': 'Demo Data - $timeString',
      },
      {
        'name': 'Gatineau River',
        'section': 'Paugan Falls',
        'location': 'Quebec',
        'currentLevel': '42.3 m³/s',
        'currentFlowValue': 42.3,
        'status': 'normal',
        'statusColor': Colors.green,
        'difficulty': 'Class III',
        'lastUpdated': 'Demo Data',
        'trend': 'stable',
        'minRunnable': '20.0 m³/s',
        'maxSafe': '80.0 m³/s',
        'stationId': '02KD007',
        'province': 'Quebec',
        'flowRate': 42.3,
        'lastUpdate': 'Demo Data - $timeString',
      },
      {
        'name': 'Rouge River',
        'section': 'Seven Sisters',
        'location': 'Quebec',
        'currentLevel': '38.7 m³/s',
        'currentFlowValue': 38.7,
        'status': 'normal',
        'statusColor': Colors.green,
        'difficulty': 'Class IV-V',
        'lastUpdated': 'Demo Data',
        'trend': 'falling',
        'minRunnable': '15.0 m³/s',
        'maxSafe': '60.0 m³/s',
        'stationId': '02KB008',
        'province': 'Quebec',
        'flowRate': 38.7,
        'lastUpdate': 'Demo Data - $timeString',
      },
      {
        'name': 'Yukon River',
        'section': 'Whitehorse Rapids',
        'location': 'Yukon',
        'currentLevel': '425.8 m³/s',
        'currentFlowValue': 425.8,
        'status': 'normal',
        'statusColor': Colors.green,
        'difficulty': 'Class II-III',
        'lastUpdated': 'Demo Data',
        'trend': 'stable',
        'minRunnable': '150.0 m³/s',
        'maxSafe': '800.0 m³/s',
        'stationId': '09AB004',
        'province': 'Yukon',
        'flowRate': 425.8,
        'lastUpdate': 'Demo Data - $timeString',
      },
    ];
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
        'province': 'Ontario/Quebec',
        'flowRate': 125.5,
        'lastUpdate': 'Mock Data',
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
        'province': 'Ontario',
        'flowRate': 45.2,
        'lastUpdate': 'Mock Data',
      },
      {
        'name': 'Bow River',
        'section': 'Harvey Passage',
        'location': 'Alberta',
        'currentLevel': '85.3 m³/s',
        'currentFlowValue': 85.3,
        'status': 'Good',
        'statusColor': Colors.green,
        'difficulty': 'Class II-III',
        'lastUpdated': 'Mock Data',
        'trend': 'stable',
        'minRunnable': '30.0 m³/s',
        'maxSafe': '150.0 m³/s',
        'stationId': '05BH004',
        'province': 'Alberta',
        'flowRate': 85.3,
        'lastUpdate': 'Mock Data',
      },
    ];
  }
}
