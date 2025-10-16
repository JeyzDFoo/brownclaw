import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:brownclaw/models/river_run.dart';

void main() {
  group('RiverRun Model Tests', () {
    test('should create RiverRun with required fields', () {
      final riverRun = RiverRun(
        id: 'run-id',
        riverId: 'river-id',
        name: 'Lower Canyon',
        difficultyClass: 'Class III',
      );

      expect(riverRun.id, 'run-id');
      expect(riverRun.riverId, 'river-id');
      expect(riverRun.name, 'Lower Canyon');
      expect(riverRun.difficultyClass, 'Class III');
      expect(riverRun.description, null);
      expect(riverRun.length, null);
    });

    test('should create RiverRun with all fields', () {
      final now = DateTime.now();
      final riverRun = RiverRun(
        id: 'run-id',
        riverId: 'river-id',
        name: 'Lower Canyon',
        difficultyClass: 'Class III-IV',
        description: 'Technical rapids',
        length: 12.5,
        putIn: 'Highway Bridge',
        takeOut: 'River Park',
        gradient: 15.0,
        season: 'April-October',
        permits: 'None required',
        hazards: ['Undercut rocks', 'Log jams'],
        minRecommendedFlow: 20.0,
        maxRecommendedFlow: 150.0,
        optimalFlowMin: 40.0,
        optimalFlowMax: 100.0,
        flowUnit: 'cms',
        stationId: '08MF005',
        createdBy: 'user-123',
        createdAt: now,
        updatedAt: now,
      );

      expect(riverRun.description, 'Technical rapids');
      expect(riverRun.length, 12.5);
      expect(riverRun.putIn, 'Highway Bridge');
      expect(riverRun.takeOut, 'River Park');
      expect(riverRun.gradient, 15.0);
      expect(riverRun.season, 'April-October');
      expect(riverRun.permits, 'None required');
      expect(riverRun.hazards, ['Undercut rocks', 'Log jams']);
      expect(riverRun.minRecommendedFlow, 20.0);
      expect(riverRun.maxRecommendedFlow, 150.0);
      expect(riverRun.optimalFlowMin, 40.0);
      expect(riverRun.optimalFlowMax, 100.0);
      expect(riverRun.flowUnit, 'cms');
      expect(riverRun.stationId, '08MF005');
      expect(riverRun.createdBy, 'user-123');
      expect(riverRun.createdAt, now);
      expect(riverRun.updatedAt, now);
    });

    test('should create RiverRun from Map', () {
      final map = {
        'id': 'run-id',
        'riverId': 'river-id',
        'name': 'Upper Falls',
        'difficultyClass': 'Class V',
        'description': 'Expert only',
        'length': 5.0,
        'minRecommendedFlow': 30.0,
        'maxRecommendedFlow': 80.0,
      };

      final riverRun = RiverRun.fromMap(map);

      expect(riverRun.id, 'run-id');
      expect(riverRun.riverId, 'river-id');
      expect(riverRun.name, 'Upper Falls');
      expect(riverRun.difficultyClass, 'Class V');
      expect(riverRun.description, 'Expert only');
      expect(riverRun.length, 5.0);
      expect(riverRun.minRecommendedFlow, 30.0);
      expect(riverRun.maxRecommendedFlow, 80.0);
    });

    test('should handle default values for missing fields in fromMap', () {
      final map = <String, dynamic>{};

      final riverRun = RiverRun.fromMap(map, docId: 'doc-id');

      expect(riverRun.id, 'doc-id');
      expect(riverRun.riverId, '');
      expect(riverRun.name, 'Unknown Section');
      expect(riverRun.difficultyClass, 'Unknown');
    });

    test('should handle numeric conversions in fromMap', () {
      final map = {
        'riverId': 'river-id',
        'name': 'Test Run',
        'difficultyClass': 'Class II',
        'length': 10, // int instead of double
        'gradient': '15.5', // string instead of double
        'minRecommendedFlow': 25, // int
        'maxRecommendedFlow': '100', // string
      };

      final riverRun = RiverRun.fromMap(map, docId: 'run-id');

      expect(riverRun.length, 10.0);
      expect(riverRun.gradient, 15.5);
      expect(riverRun.minRecommendedFlow, 25.0);
      expect(riverRun.maxRecommendedFlow, 100.0);
    });

    test('should convert RiverRun to Map with required fields', () {
      final riverRun = RiverRun(
        id: 'run-id',
        riverId: 'river-id',
        name: 'Middle Section',
        difficultyClass: 'Class II',
      );

      final map = riverRun.toMap();

      expect(map['riverId'], 'river-id');
      expect(map['name'], 'Middle Section');
      expect(map['difficultyClass'], 'Class II');
      expect(map.containsKey('id'), false);
      expect(map.containsKey('description'), false);
    });

    test('should convert RiverRun to Map with all fields', () {
      final now = DateTime.now();
      final riverRun = RiverRun(
        id: 'run-id',
        riverId: 'river-id',
        name: 'Expert Canyon',
        difficultyClass: 'Class IV+',
        description: 'Very technical',
        length: 8.0,
        putIn: 'Dam',
        takeOut: 'Bridge',
        gradient: 20.0,
        season: 'Spring runoff',
        permits: 'Required',
        hazards: ['Waterfall', 'Sieve'],
        minRecommendedFlow: 50.0,
        maxRecommendedFlow: 200.0,
        optimalFlowMin: 80.0,
        optimalFlowMax: 150.0,
        flowUnit: 'cfs',
        stationId: 'USGS-12345',
        createdBy: 'user-456',
        createdAt: now,
        updatedAt: now,
      );

      final map = riverRun.toMap();

      expect(map['description'], 'Very technical');
      expect(map['length'], 8.0);
      expect(map['putIn'], 'Dam');
      expect(map['takeOut'], 'Bridge');
      expect(map['gradient'], 20.0);
      expect(map['season'], 'Spring runoff');
      expect(map['permits'], 'Required');
      expect(map['hazards'], ['Waterfall', 'Sieve']);
      expect(map['minRecommendedFlow'], 50.0);
      expect(map['maxRecommendedFlow'], 200.0);
      expect(map['optimalFlowMin'], 80.0);
      expect(map['optimalFlowMax'], 150.0);
      expect(map['flowUnit'], 'cfs');
      expect(map['stationId'], 'USGS-12345');
      expect(map['createdBy'], 'user-456');
      expect(map['createdAt'], isA<Timestamp>());
      expect(map['updatedAt'], isA<Timestamp>());
    });

    test('should handle hazards list in fromMap and toMap', () {
      final map = {
        'riverId': 'river-id',
        'name': 'Dangerous Run',
        'difficultyClass': 'Class V',
        'hazards': ['Rapids', 'Rocks', 'Logs'],
      };

      final riverRun = RiverRun.fromMap(map, docId: 'run-id');
      expect(riverRun.hazards, ['Rapids', 'Rocks', 'Logs']);

      final convertedMap = riverRun.toMap();
      expect(convertedMap['hazards'], ['Rapids', 'Rocks', 'Logs']);
    });

    test('should create copy with modified values', () {
      final original = RiverRun(
        id: 'run-id',
        riverId: 'river-id',
        name: 'Original Name',
        difficultyClass: 'Class III',
      );

      final copy = original.copyWith(
        name: 'Modified Name',
        difficultyClass: 'Class IV',
        description: 'Updated description',
      );

      expect(copy.id, original.id);
      expect(copy.riverId, original.riverId);
      expect(copy.name, 'Modified Name');
      expect(copy.difficultyClass, 'Class IV');
      expect(copy.description, 'Updated description');
    });

    test('should return string representation', () {
      final riverRun = RiverRun(
        id: 'run-id',
        riverId: 'river-id',
        name: 'Five Mile Rapids',
        difficultyClass: 'Class III-IV',
      );

      expect(riverRun.toString(), 'Five Mile Rapids (Class III-IV)');
    });

    test('should implement equality based on id', () {
      final run1 = RiverRun(
        id: 'same-id',
        riverId: 'river-1',
        name: 'Run 1',
        difficultyClass: 'Class II',
      );

      final run2 = RiverRun(
        id: 'same-id',
        riverId: 'river-2',
        name: 'Run 2',
        difficultyClass: 'Class III',
      );

      final run3 = RiverRun(
        id: 'different-id',
        riverId: 'river-1',
        name: 'Run 1',
        difficultyClass: 'Class II',
      );

      expect(run1 == run2, true);
      expect(run1 == run3, false);
      expect(run1.hashCode, run2.hashCode);
    });

    test('should handle flow recommendations correctly', () {
      final riverRun = RiverRun(
        id: 'run-id',
        riverId: 'river-id',
        name: 'Test Run',
        difficultyClass: 'Class III',
        minRecommendedFlow: 20.0,
        maxRecommendedFlow: 150.0,
        optimalFlowMin: 40.0,
        optimalFlowMax: 100.0,
        flowUnit: 'cms',
      );

      expect(riverRun.hasFlowRecommendations, true);
      expect(riverRun.minRecommendedFlow, 20.0);
      expect(riverRun.maxRecommendedFlow, 150.0);
      expect(riverRun.optimalFlowMin, 40.0);
      expect(riverRun.optimalFlowMax, 100.0);
    });

    test('should handle missing flow recommendations', () {
      final riverRun = RiverRun(
        id: 'run-id',
        riverId: 'river-id',
        name: 'Test Run',
        difficultyClass: 'Class III',
      );

      expect(riverRun.hasFlowRecommendations, false);
    });

    test('should handle empty hazards list', () {
      final map = {
        'riverId': 'river-id',
        'name': 'Safe Run',
        'difficultyClass': 'Class I',
        'hazards': <String>[],
      };

      final riverRun = RiverRun.fromMap(map, docId: 'run-id');
      expect(riverRun.hazards, []);
    });
  });
}
