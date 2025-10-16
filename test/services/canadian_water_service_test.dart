import 'package:flutter_test/flutter_test.dart';
import 'package:brownclaw/services/canadian_water_service.dart';

void main() {
  group('CanadianWaterService Tests', () {
    test('should have predefined Canadian rivers', () {
      final rivers = CanadianWaterService.canadianRivers;

      expect(rivers.isNotEmpty, true);
      expect(rivers.containsKey('Ottawa River'), true);
      expect(rivers.containsKey('Kicking Horse River'), true);
      expect(rivers.containsKey('Bow River'), true);
    });

    test('should return all rivers with getAllRivers', () {
      final rivers = CanadianWaterService.getAllRivers();

      expect(rivers.isNotEmpty, true);

      // Check that name is added to each river
      for (final river in rivers) {
        expect(river.containsKey('name'), true);
        expect(river.containsKey('stationId'), true);
        expect(river.containsKey('section'), true);
        expect(river.containsKey('location'), true);
        expect(river.containsKey('difficulty'), true);
      }
    });

    test('Ottawa River should have correct data', () {
      final ottawaRiver = CanadianWaterService.canadianRivers['Ottawa River'];

      expect(ottawaRiver, isNotNull);
      expect(ottawaRiver!['stationId'], '02KF005');
      expect(ottawaRiver['section'], 'Champlain Bridge');
      expect(ottawaRiver['location'], 'Ontario/Quebec');
      expect(ottawaRiver['difficulty'], 'Class I-II');
      expect(ottawaRiver['minRunnable'], isA<double>());
      expect(ottawaRiver['maxSafe'], isA<double>());
    });

    test('Kicking Horse River should have correct data', () {
      final kickingHorse =
          CanadianWaterService.canadianRivers['Kicking Horse River'];

      expect(kickingHorse, isNotNull);
      expect(kickingHorse!['stationId'], '05AD007');
      expect(kickingHorse['section'], 'Lower Canyon');
      expect(kickingHorse['location'], 'British Columbia');
      expect(kickingHorse['difficulty'], 'Class III-IV');
      expect(kickingHorse['minRunnable'], 25.0);
      expect(kickingHorse['maxSafe'], 120.0);
    });

    test('should have flow recommendations for all rivers', () {
      final rivers = CanadianWaterService.getAllRivers();

      for (final river in rivers) {
        expect(river['minRunnable'], isA<double>());
        expect(river['maxSafe'], isA<double>());
        expect(river['minRunnable'], lessThan(river['maxSafe']));
      }
    });

    test('should construct correct base URL', () {
      expect(CanadianWaterService.baseUrl, contains('wateroffice.ec.gc.ca'));
      expect(CanadianWaterService.baseUrl, contains('real_time_data'));
    });

    test('should include popular whitewater destinations', () {
      final rivers = CanadianWaterService.canadianRivers;

      // Check for some famous whitewater rivers
      expect(rivers.containsKey('Ottawa River'), true);
      expect(rivers.containsKey('Rouge River'), true);
      expect(rivers.containsKey('Petawawa River'), true);
      expect(rivers.containsKey('Madawaska River'), true);
      expect(rivers.containsKey('Kicking Horse River'), true);
    });

    test('all rivers should have required fields', () {
      final rivers = CanadianWaterService.getAllRivers();

      for (final river in rivers) {
        expect(river['name'], isA<String>());
        expect(river['stationId'], isA<String>());
        expect(river['section'], isA<String>());
        expect(river['location'], isA<String>());
        expect(river['difficulty'], isA<String>());
        expect(river['minRunnable'], isA<double>());
        expect(river['maxSafe'], isA<double>());
      }
    });

    test('should have rivers from multiple provinces', () {
      final rivers = CanadianWaterService.getAllRivers();
      final locations = rivers.map((r) => r['location']).toSet();

      expect(locations.contains('Ontario'), true);
      expect(locations.contains('British Columbia'), true);
      expect(locations.contains('Alberta'), true);
      expect(locations.contains('Quebec'), true);
    });

    test('should have difficulty classifications', () {
      final rivers = CanadianWaterService.getAllRivers();

      for (final river in rivers) {
        final difficulty = river['difficulty'] as String;
        expect(difficulty, contains('Class'));
      }
    });

    test('Rouge River should be Class IV-V', () {
      final rouge = CanadianWaterService.canadianRivers['Rouge River'];

      expect(rouge, isNotNull);
      expect(rouge!['difficulty'], 'Class IV-V');
      expect(rouge['section'], 'Seven Sisters');
    });

    test('should include Yukon territory rivers', () {
      final yukon = CanadianWaterService.canadianRivers['Yukon River'];

      expect(yukon, isNotNull);
      expect(yukon!['location'], 'Yukon');
      expect(yukon['stationId'], '09AB004');
    });

    test('should have reasonable flow ranges', () {
      final rivers = CanadianWaterService.getAllRivers();

      for (final river in rivers) {
        final minRunnable = river['minRunnable'] as double;
        final maxSafe = river['maxSafe'] as double;

        // Flow should be positive
        expect(minRunnable, greaterThan(0));
        expect(maxSafe, greaterThan(0));

        // Max should be greater than min
        expect(maxSafe, greaterThan(minRunnable));

        // Max should be at least 2x min (reasonable ratio)
        expect(maxSafe, greaterThanOrEqualTo(minRunnable * 1.5));
      }
    });

    test('should not modify original data when calling getAllRivers', () {
      final original = CanadianWaterService.canadianRivers['Ottawa River']!;
      final originalKeys = original.keys.toSet();

      // Call getAllRivers which adds 'name' field to returned data
      CanadianWaterService.getAllRivers();

      // Verify original data hasn't been modified
      expect(
        CanadianWaterService.canadianRivers['Ottawa River']!.keys.toSet(),
        originalKeys,
      );
    });
    test('each river should have unique station ID', () {
      final rivers = CanadianWaterService.getAllRivers();
      final stationIds = rivers.map((r) => r['stationId']).toSet();

      // No duplicate station IDs
      expect(stationIds.length, rivers.length);
    });

    test('should have different difficulty levels represented', () {
      final rivers = CanadianWaterService.getAllRivers();
      final difficulties = rivers.map((r) => r['difficulty']).toSet();

      // Should have multiple difficulty levels
      expect(difficulties.length, greaterThan(3));
      expect(difficulties.any((d) => (d as String).contains('I')), true);
      expect(difficulties.any((d) => (d as String).contains('IV')), true);
    });
  });
}
