import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:brownclaw/models/gauge_station.dart';

void main() {
  group('GaugeStation Model Tests', () {
    test('should create GaugeStation with required fields', () {
      final station = GaugeStation(
        stationId: '08MF005',
        name: 'Kicking Horse River at Golden',
        latitude: 51.2963,
        longitude: -116.9633,
        isActive: true,
        parameters: ['discharge', 'water_level'],
      );

      expect(station.stationId, '08MF005');
      expect(station.name, 'Kicking Horse River at Golden');
      expect(station.latitude, 51.2963);
      expect(station.longitude, -116.9633);
      expect(station.isActive, true);
      expect(station.parameters, ['discharge', 'water_level']);
      expect(station.riverRunId, null);
      expect(station.associatedRiverRunIds, null);
    });

    test('should create GaugeStation with all fields', () {
      final now = DateTime.now();
      final station = GaugeStation(
        stationId: '08MF005',
        name: 'Kicking Horse River at Golden',
        riverRunId: 'legacy-run-id',
        associatedRiverRunIds: ['run-1', 'run-2', 'run-3'],
        latitude: 51.2963,
        longitude: -116.9633,
        agency: 'Environment Canada',
        region: 'British Columbia',
        country: 'Canada',
        isActive: true,
        parameters: ['discharge', 'water_level', 'temperature'],
        dataUrl: 'https://wateroffice.ec.gc.ca/...',
        createdAt: now,
        updatedAt: now,
        currentDischarge: 75.5,
        currentWaterLevel: 2.3,
        currentTemperature: 8.5,
        lastDataUpdate: now,
        dataStatus: 'live',
      );

      expect(station.riverRunId, 'legacy-run-id');
      expect(station.associatedRiverRunIds, ['run-1', 'run-2', 'run-3']);
      expect(station.agency, 'Environment Canada');
      expect(station.region, 'British Columbia');
      expect(station.country, 'Canada');
      expect(station.dataUrl, 'https://wateroffice.ec.gc.ca/...');
      expect(station.createdAt, now);
      expect(station.updatedAt, now);
      expect(station.currentDischarge, 75.5);
      expect(station.currentWaterLevel, 2.3);
      expect(station.currentTemperature, 8.5);
      expect(station.lastDataUpdate, now);
      expect(station.dataStatus, 'live');
    });

    test('should create GaugeStation from Map', () {
      final map = {
        'stationId': '08NA011',
        'name': 'Spillimacheen River near Spillimacheen',
        'latitude': 50.9856,
        'longitude': -116.5969,
        'agency': 'Environment Canada',
        'region': 'British Columbia',
        'isActive': true,
        'parameters': ['discharge'],
      };

      final station = GaugeStation.fromMap(map);

      expect(station.stationId, '08NA011');
      expect(station.name, 'Spillimacheen River near Spillimacheen');
      expect(station.latitude, 50.9856);
      expect(station.longitude, -116.5969);
      expect(station.agency, 'Environment Canada');
      expect(station.region, 'British Columbia');
      expect(station.isActive, true);
      expect(station.parameters, ['discharge']);
    });

    test('should handle default values for missing fields in fromMap', () {
      final map = <String, dynamic>{'stationId': 'TEST-001'};

      final station = GaugeStation.fromMap(map);

      expect(station.stationId, 'TEST-001');
      expect(station.name, 'Unknown Station');
      expect(station.latitude, 0.0);
      expect(station.longitude, 0.0);
      expect(station.isActive, true);
      expect(station.parameters, []);
    });

    test('should handle numeric conversions in fromMap', () {
      final map = {
        'stationId': 'TEST-001',
        'name': 'Test Station',
        'latitude': '51.5', // string
        'longitude': -116, // int
        'isActive': true,
        'parameters': [],
        'currentDischarge': 50, // int
        'currentWaterLevel': '2.5', // string
        'currentTemperature': 10.5, // double
      };

      final station = GaugeStation.fromMap(map);

      expect(station.latitude, 51.5);
      expect(station.longitude, -116.0);
      expect(station.currentDischarge, 50.0);
      expect(station.currentWaterLevel, 2.5);
      expect(station.currentTemperature, 10.5);
    });

    test('should handle invalid numeric strings gracefully', () {
      final map = {
        'stationId': 'TEST-001',
        'name': 'Test Station',
        'latitude': 'not-a-number',
        'longitude': 'invalid',
        'isActive': true,
        'parameters': [],
      };

      final station = GaugeStation.fromMap(map);

      // _safeToDouble returns null for invalid strings, but fromMap uses 0.0 as default
      expect(station.latitude, 0.0);
      expect(station.longitude, 0.0);
    });

    test('should convert GaugeStation to Map with required fields', () {
      final station = GaugeStation(
        stationId: '08MF005',
        name: 'Test Station',
        latitude: 51.0,
        longitude: -116.0,
        isActive: true,
        parameters: ['discharge'],
      );

      final map = station.toMap();

      expect(map['stationId'], '08MF005');
      expect(map['name'], 'Test Station');
      expect(map['latitude'], 51.0);
      expect(map['longitude'], -116.0);
      expect(map['isActive'], true);
      expect(map['parameters'], ['discharge']);
      expect(map.containsKey('riverRunId'), false);
      expect(map.containsKey('description'), false);
    });

    test('should convert GaugeStation to Map with all fields', () {
      final now = DateTime.now();
      final station = GaugeStation(
        stationId: '08MF005',
        name: 'Test Station',
        riverRunId: 'run-id',
        associatedRiverRunIds: ['run-1', 'run-2'],
        latitude: 51.0,
        longitude: -116.0,
        agency: 'Environment Canada',
        region: 'BC',
        country: 'Canada',
        isActive: true,
        parameters: ['discharge', 'water_level'],
        dataUrl: 'https://example.com',
        createdAt: now,
        updatedAt: now,
        currentDischarge: 100.0,
        currentWaterLevel: 3.0,
        currentTemperature: 12.0,
        lastDataUpdate: now,
        dataStatus: 'live',
      );

      final map = station.toMap();

      expect(map['riverRunId'], 'run-id');
      expect(map['associatedRiverRunIds'], ['run-1', 'run-2']);
      expect(map['agency'], 'Environment Canada');
      expect(map['region'], 'BC');
      expect(map['country'], 'Canada');
      expect(map['dataUrl'], 'https://example.com');
      expect(map['createdAt'], isA<Timestamp>());
      expect(map['updatedAt'], isA<Timestamp>());
      expect(map['currentDischarge'], 100.0);
      expect(map['currentWaterLevel'], 3.0);
      expect(map['currentTemperature'], 12.0);
      expect(map['lastDataUpdate'], isA<Timestamp>());
      expect(map['dataStatus'], 'live');
    });

    test('should not include empty associatedRiverRunIds in toMap', () {
      final station = GaugeStation(
        stationId: '08MF005',
        name: 'Test Station',
        associatedRiverRunIds: [],
        latitude: 51.0,
        longitude: -116.0,
        isActive: true,
        parameters: ['discharge'],
      );

      final map = station.toMap();

      expect(map.containsKey('associatedRiverRunIds'), false);
    });

    test('should correctly identify if station has live data', () {
      final now = DateTime.now();
      final recentUpdate = now.subtract(const Duration(hours: 2));
      final oldUpdate = now.subtract(const Duration(hours: 30));

      final liveStation = GaugeStation(
        stationId: '08MF005',
        name: 'Live Station',
        latitude: 51.0,
        longitude: -116.0,
        isActive: true,
        parameters: ['discharge'],
        dataStatus: 'live',
        lastDataUpdate: recentUpdate,
      );

      final staleStation = GaugeStation(
        stationId: '08MF006',
        name: 'Stale Station',
        latitude: 51.0,
        longitude: -116.0,
        isActive: true,
        parameters: ['discharge'],
        dataStatus: 'live',
        lastDataUpdate: oldUpdate,
      );

      final noDataStation = GaugeStation(
        stationId: '08MF007',
        name: 'No Data Station',
        latitude: 51.0,
        longitude: -116.0,
        isActive: true,
        parameters: ['discharge'],
        dataStatus: 'unavailable',
      );

      expect(liveStation.hasLiveData, true);
      expect(staleStation.hasLiveData, false);
      expect(noDataStation.hasLiveData, false);
    });

    test('should correctly identify measured parameters', () {
      final station = GaugeStation(
        stationId: '08MF005',
        name: 'Multi-Parameter Station',
        latitude: 51.0,
        longitude: -116.0,
        isActive: true,
        parameters: ['discharge', 'water_level', 'temperature'],
      );

      expect(station.measuresDischarge, true);
      expect(station.measuresWaterLevel, true);
      expect(station.measuresTemperature, true);
    });

    test('should correctly identify missing parameters', () {
      final station = GaugeStation(
        stationId: '08MF005',
        name: 'Discharge Only Station',
        latitude: 51.0,
        longitude: -116.0,
        isActive: true,
        parameters: ['discharge'],
      );

      expect(station.measuresDischarge, true);
      expect(station.measuresWaterLevel, false);
      expect(station.measuresTemperature, false);
    });

    test('should return correct display name', () {
      final station = GaugeStation(
        stationId: '08MF005',
        name: 'Kicking Horse River at Golden',
        latitude: 51.0,
        longitude: -116.0,
        isActive: true,
        parameters: ['discharge'],
      );

      expect(station.displayName, 'Kicking Horse River at Golden (08MF005)');
    });

    test('should create copy with modified values', () {
      final original = GaugeStation(
        stationId: '08MF005',
        name: 'Original Station',
        latitude: 51.0,
        longitude: -116.0,
        isActive: true,
        parameters: ['discharge'],
      );

      final copy = original.copyWith(
        name: 'Modified Station',
        currentDischarge: 50.0,
        dataStatus: 'live',
      );

      expect(copy.stationId, original.stationId);
      expect(copy.name, 'Modified Station');
      expect(copy.latitude, original.latitude);
      expect(copy.currentDischarge, 50.0);
      expect(copy.dataStatus, 'live');
    });

    test('should implement equality based on stationId', () {
      final station1 = GaugeStation(
        stationId: 'same-id',
        name: 'Station 1',
        latitude: 51.0,
        longitude: -116.0,
        isActive: true,
        parameters: ['discharge'],
      );

      final station2 = GaugeStation(
        stationId: 'same-id',
        name: 'Different Name',
        latitude: 52.0,
        longitude: -117.0,
        isActive: false,
        parameters: ['water_level'],
      );

      final station3 = GaugeStation(
        stationId: 'different-id',
        name: 'Station 1',
        latitude: 51.0,
        longitude: -116.0,
        isActive: true,
        parameters: ['discharge'],
      );

      expect(station1 == station2, true);
      expect(station1 == station3, false);
      expect(station1.hashCode, station2.hashCode);
    });

    test('should handle Timestamp conversion in fromMap', () {
      final timestamp = Timestamp.now();
      final map = {
        'stationId': 'TEST-001',
        'name': 'Test Station',
        'latitude': 51.0,
        'longitude': -116.0,
        'isActive': true,
        'parameters': ['discharge'],
        'createdAt': timestamp,
        'updatedAt': timestamp,
        'lastDataUpdate': timestamp,
      };

      final station = GaugeStation.fromMap(map);

      expect(station.createdAt, isA<DateTime>());
      expect(station.updatedAt, isA<DateTime>());
      expect(station.lastDataUpdate, isA<DateTime>());
    });
  });
}
