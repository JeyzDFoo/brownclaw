import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:brownclaw/models/river.dart';

void main() {
  group('River Model Tests', () {
    test('should create River with required fields', () {
      final river = River(
        id: 'test-id',
        name: 'Ottawa River',
        region: 'Ontario',
        country: 'Canada',
      );

      expect(river.id, 'test-id');
      expect(river.name, 'Ottawa River');
      expect(river.region, 'Ontario');
      expect(river.country, 'Canada');
      expect(river.description, null);
      expect(river.createdAt, null);
      expect(river.updatedAt, null);
    });

    test('should create River with all fields', () {
      final now = DateTime.now();
      final river = River(
        id: 'test-id',
        name: 'Ottawa River',
        region: 'Ontario',
        country: 'Canada',
        description: 'A great whitewater river',
        createdAt: now,
        updatedAt: now,
      );

      expect(river.description, 'A great whitewater river');
      expect(river.createdAt, now);
      expect(river.updatedAt, now);
    });

    test('should create River from Map', () {
      final map = {
        'id': 'test-id',
        'name': 'Kicking Horse River',
        'region': 'British Columbia',
        'country': 'Canada',
        'description': 'World-class whitewater',
      };

      final river = River.fromMap(map);

      expect(river.id, 'test-id');
      expect(river.name, 'Kicking Horse River');
      expect(river.region, 'British Columbia');
      expect(river.country, 'Canada');
      expect(river.description, 'World-class whitewater');
    });

    test('should create River from Map with docId', () {
      final map = {
        'name': 'Bow River',
        'region': 'Alberta',
        'country': 'Canada',
      };

      final river = River.fromMap(map, docId: 'firestore-doc-id');

      expect(river.id, 'firestore-doc-id');
      expect(river.name, 'Bow River');
    });

    test('should handle missing optional fields when creating from Map', () {
      final map = {
        'name': 'Rouge River',
        'region': 'Quebec',
        'country': 'Canada',
      };

      final river = River.fromMap(map, docId: 'test-id');

      expect(river.id, 'test-id');
      expect(river.description, null);
      expect(river.createdAt, null);
      expect(river.updatedAt, null);
    });

    test(
      'should use default values for missing required fields in fromMap',
      () {
        final map = <String, dynamic>{'id': 'test-id'};

        final river = River.fromMap(map);

        expect(river.name, 'Unknown River');
        expect(river.region, 'Unknown');
        expect(river.country, 'Unknown');
      },
    );

    test('should convert River to Map with only required fields', () {
      final river = River(
        id: 'test-id',
        name: 'Madawaska River',
        region: 'Ontario',
        country: 'Canada',
      );

      final map = river.toMap();

      expect(map['name'], 'Madawaska River');
      expect(map['region'], 'Ontario');
      expect(map['country'], 'Canada');
      expect(map.containsKey('description'), false);
      expect(map.containsKey('id'), false); // ID not included in toMap
    });

    test('should convert River to Map with all fields', () {
      final now = DateTime.now();
      final river = River(
        id: 'test-id',
        name: 'Petawawa River',
        region: 'Ontario',
        country: 'Canada',
        description: 'Challenging rapids',
        createdAt: now,
        updatedAt: now,
      );

      final map = river.toMap();

      expect(map['name'], 'Petawawa River');
      expect(map['description'], 'Challenging rapids');
      expect(map['createdAt'], isA<Timestamp>());
      expect(map['updatedAt'], isA<Timestamp>());
    });

    test('should convert Timestamp to DateTime in fromMap', () {
      final timestamp = Timestamp.now();
      final map = {
        'name': 'Test River',
        'region': 'Test Region',
        'country': 'Test Country',
        'createdAt': timestamp,
        'updatedAt': timestamp,
      };

      final river = River.fromMap(map, docId: 'test-id');

      expect(river.createdAt, isA<DateTime>());
      expect(river.updatedAt, isA<DateTime>());
    });

    test('should create copy with modified values', () {
      final original = River(
        id: 'test-id',
        name: 'Original River',
        region: 'Original Region',
        country: 'Canada',
      );

      final copy = original.copyWith(
        name: 'Modified River',
        description: 'New description',
      );

      expect(copy.id, original.id);
      expect(copy.name, 'Modified River');
      expect(copy.region, original.region);
      expect(copy.description, 'New description');
    });

    test('should return string representation', () {
      final river = River(
        id: 'test-id',
        name: 'Ottawa River',
        region: 'Ontario',
        country: 'Canada',
      );

      expect(river.toString(), 'Ottawa River (Ontario)');
    });

    test('should implement equality based on id', () {
      final river1 = River(
        id: 'same-id',
        name: 'River 1',
        region: 'Region 1',
        country: 'Country 1',
      );

      final river2 = River(
        id: 'same-id',
        name: 'Different Name',
        region: 'Different Region',
        country: 'Different Country',
      );

      final river3 = River(
        id: 'different-id',
        name: 'River 1',
        region: 'Region 1',
        country: 'Country 1',
      );

      expect(river1 == river2, true);
      expect(river1 == river3, false);
      expect(river1.hashCode, river2.hashCode);
      expect(river1.hashCode == river3.hashCode, false);
    });

    test('should handle null and empty values gracefully', () {
      final map = {'name': '', 'region': '', 'country': ''};

      final river = River.fromMap(map, docId: 'test-id');

      expect(river.name, '');
      expect(river.region, '');
      expect(river.country, '');
    });
  });
}
