import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';

/// Service for managing river descents
class RiverDescentService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get enhanced river descent information including river and run details
  static Future<Map<String, dynamic>> getEnhancedDescentInfo(
    Map<String, dynamic> descentData,
  ) async {
    try {
      final riverRunId = descentData['riverRunId'] as String?;

      if (riverRunId == null || riverRunId.isEmpty) {
        // Return basic info for legacy entries
        return {
          'riverName': descentData['riverName'] ?? 'Unknown River',
          'runName': descentData['section'] ?? 'Unknown Section',
          'difficulty': descentData['difficulty'] ?? 'Unknown',
          'waterLevel': descentData['waterLevel'] ?? '',
          'notes': descentData['notes'] ?? '',
          'runDate': descentData['runDate'] ?? descentData['date'],
          'isLegacy': true,
        };
      }

      // Get the river run details
      final runDoc = await _firestore
          .collection('river_runs')
          .doc(riverRunId)
          .get();

      if (!runDoc.exists) {
        // Fallback to legacy data
        return {
          'riverName': descentData['riverName'] ?? 'Unknown River',
          'runName': descentData['section'] ?? 'Unknown Section',
          'difficulty': descentData['difficulty'] ?? 'Unknown',
          'waterLevel': descentData['waterLevel'] ?? '',
          'notes': descentData['notes'] ?? '',
          'runDate': descentData['runDate'] ?? descentData['date'],
          'isLegacy': true,
        };
      }

      final runData = runDoc.data() as Map<String, dynamic>;
      final run = RiverRun.fromMap(runData, docId: runDoc.id);

      // Get the river details
      final riverDoc = await _firestore
          .collection('rivers')
          .doc(run.riverId)
          .get();

      String riverName = 'Unknown River';
      String region = '';
      if (riverDoc.exists) {
        final riverData = riverDoc.data() as Map<String, dynamic>;
        final river = River.fromMap(riverData, docId: riverDoc.id);
        riverName = river.name;
        region = '${river.region}, ${river.country}';
      }

      return {
        'riverName': riverName,
        'runName': run.name,
        'difficulty': run.difficultyClass,
        'waterLevel': descentData['waterLevel'] ?? '',
        'notes': descentData['notes'] ?? '',
        'runDate': descentData['runDate'] ?? descentData['date'],
        'region': region,
        'length': run.length,
        'putIn': run.putIn,
        'takeOut': run.takeOut,
        'season': run.season,
        'description': run.description,
        'isLegacy': false,
      };
    } catch (e) {
      // Fallback to legacy data on any error
      return {
        'riverName': descentData['riverName'] ?? 'Unknown River',
        'runName': descentData['section'] ?? 'Unknown Section',
        'difficulty': descentData['difficulty'] ?? 'Unknown',
        'waterLevel': descentData['waterLevel'] ?? '',
        'notes': descentData['notes'] ?? '',
        'runDate': descentData['runDate'] ?? descentData['date'],
        'isLegacy': true,
        'error': e.toString(),
      };
    }
  }

  /// Get all descents for a user with enhanced information
  static Stream<List<Map<String, dynamic>>> getEnhancedDescentsForUser(
    String userId,
  ) {
    return _firestore
        .collection('river_descents')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          final results = <Map<String, dynamic>>[];

          for (final doc in snapshot.docs) {
            final descentData = doc.data();
            descentData['id'] = doc.id;

            final enhancedInfo = await getEnhancedDescentInfo(descentData);
            enhancedInfo.addAll(descentData); // Include original data

            results.add(enhancedInfo);
          }

          return results;
        });
  }
}
