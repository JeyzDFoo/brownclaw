import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Fast batch fetcher for Firestore - handles 10-item whereIn limit
/// 
/// Solves the N+1 query problem by batching document fetches.
/// Example: Instead of 10 individual queries, makes 1 batch query.
class BatchFirestoreService {
  static final _firestore = FirebaseFirestore.instance;
  
  /// Batch fetch documents by IDs (handles 10-item whereIn limit)
  /// 
  /// Firestore has a limit of 10 items per whereIn query.
  /// This method automatically splits larger lists into multiple batches.
  /// 
  /// Example:
  /// ```dart
  /// final docs = await BatchFirestoreService.batchGetDocs(
  ///   'river_runs',
  ///   ['id1', 'id2', 'id3', ..., 'id15'],
  /// );
  /// // Makes 2 queries instead of 15!
  /// ```
  static Future<Map<String, DocumentSnapshot>> batchGetDocs(
    String collection,
    List<String> ids,
  ) async {
    if (ids.isEmpty) return {};
    
    final results = <String, DocumentSnapshot>{};
    
    if (kDebugMode) {
      print('📦 Batch fetching ${ids.length} docs from $collection');
    }
    
    // Split into batches of 10 (Firestore whereIn limit)
    for (int i = 0; i < ids.length; i += 10) {
      final batch = ids.skip(i).take(10).toList();
      
      if (kDebugMode) {
        print('   Fetching batch ${(i ~/ 10) + 1}: ${batch.length} items');
      }
      
      final snapshot = await _firestore
          .collection(collection)
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      
      for (final doc in snapshot.docs) {
        results[doc.id] = doc;
      }
    }
    
    if (kDebugMode) {
      print('✅ Fetched ${results.length} docs from $collection');
    }
    
    return results;
  }
  
  /// Batch fetch documents by a field value
  /// 
  /// Similar to batchGetDocs but filters by a specific field.
  /// Useful for fetching related documents (e.g., all stations for a run).
  /// 
  /// Example:
  /// ```dart
  /// final stations = await BatchFirestoreService.batchGetByField(
  ///   'gauge_stations',
  ///   'riverRunId',
  ///   ['run1', 'run2', 'run3'],
  /// );
  /// ```
  static Future<List<DocumentSnapshot>> batchGetByField(
    String collection,
    String field,
    List<String> values,
  ) async {
    if (values.isEmpty) return [];
    
    final results = <DocumentSnapshot>[];
    
    if (kDebugMode) {
      print('📦 Batch fetching from $collection where $field in ${values.length} values');
    }
    
    // Split into batches of 10
    for (int i = 0; i < values.length; i += 10) {
      final batch = values.skip(i).take(10).toList();
      
      final snapshot = await _firestore
          .collection(collection)
          .where(field, whereIn: batch)
          .get();
      
      results.addAll(snapshot.docs);
    }
    
    if (kDebugMode) {
      print('✅ Fetched ${results.length} docs from $collection');
    }
    
    return results;
  }
}
