import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LogbookProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Current entry being edited (if any)
  String? _editingEntryId;
  Map<String, dynamic>? _editingEntryData;

  String? get editingEntryId => _editingEntryId;
  Map<String, dynamic>? get editingEntryData => _editingEntryData;
  bool get isEditMode => _editingEntryId != null;

  // Set the entry to edit
  void setEditingEntry(String entryId, Map<String, dynamic> entryData) {
    _editingEntryId = entryId;
    _editingEntryData = entryData;
    notifyListeners();
  }

  // Clear editing state
  void clearEditingEntry() {
    _editingEntryId = null;
    _editingEntryData = null;
    notifyListeners();
  }

  // Update an existing entry
  Future<void> updateEntry(String entryId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('river_descents').doc(entryId).update(data);
      clearEditingEntry();
    } catch (e) {
      debugPrint('Error updating entry: $e');
      rethrow;
    }
  }

  // Add a new entry
  Future<void> addEntry(Map<String, dynamic> data) async {
    try {
      await _firestore.collection('river_descents').add(data);
    } catch (e) {
      debugPrint('Error adding entry: $e');
      rethrow;
    }
  }

  // Delete an entry
  Future<void> deleteEntry(String entryId) async {
    try {
      await _firestore.collection('river_descents').doc(entryId).delete();
    } catch (e) {
      debugPrint('Error deleting entry: $e');
      rethrow;
    }
  }
}
