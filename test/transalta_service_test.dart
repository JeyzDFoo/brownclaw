import 'package:flutter_test/flutter_test.dart';
import 'package:brownclaw/services/transalta_service.dart';
import 'package:brownclaw/models/transalta_flow_data.dart';

void main() {
  group('TransAltaService', () {
    late TransAltaService service;

    setUp(() {
      service = TransAltaService();
      service.clearCache();
    });

    test('fetchFlowData returns data', () async {
      final data = await service.fetchFlowData();

      expect(data, isNotNull);
      expect(data!.forecasts, isNotEmpty);
      expect(
        data.forecasts.length,
        lessThanOrEqualTo(4),
      ); // Max 4 days forecast
    });

    test('getCurrentFlow returns current flow data', () async {
      final current = await service.getCurrentFlow();

      expect(current, isNotNull);
      expect(current!.barrierFlow, greaterThanOrEqualTo(0));
      expect(current.pocaterraFlow, greaterThanOrEqualTo(0));
    });

    test('getHighFlowSchedule filters correctly', () async {
      const threshold = 20.0;
      final schedule = await service.getHighFlowSchedule(threshold: threshold);

      // All entries should be above threshold
      for (final period in schedule) {
        for (final entry in period.entries) {
          expect(entry.barrierFlow, greaterThanOrEqualTo(threshold));
        }
      }
    });

    test('cache works correctly', () async {
      // First fetch
      final data1 = await service.fetchFlowData();
      expect(service.isCacheValid, true);
      expect(service.getCacheAgeMinutes(), equals(0));

      // Second fetch should use cache
      final data2 = await service.fetchFlowData();
      expect(data1, equals(data2));

      // Force refresh bypasses cache
      final data3 = await service.fetchFlowData(forceRefresh: true);
      expect(data3, isNotNull);
    });

    test('clearCache removes cached data', () async {
      await service.fetchFlowData();
      expect(service.isCacheValid, true);

      service.clearCache();
      expect(service.isCacheValid, false);
      expect(service.getCacheAgeMinutes(), isNull);
    });
  });

  group('HourlyFlowEntry', () {
    test('calculates water arrival time correctly', () {
      final entry = HourlyFlowEntry(
        period: '2025-10-17 17',
        barrierFlow: 26.0,
        pocaterraFlow: 23.0,
      );

      expect(entry.hourEnding, equals(17));
      expect(entry.hourEndingString, equals('HE17'));

      // HE17 means flow ends at 17:00, starts at 16:00
      // So arrival should be 16:00 + 45 min = 16:45
      final arrival = entry.getWaterArrivalTime(travelTimeMinutes: 45);
      expect(arrival.hour, equals(16));
      expect(arrival.minute, equals(45));
    });

    test('formats arrival time correctly', () {
      final entry = HourlyFlowEntry(
        period: '2025-10-17 17',
        barrierFlow: 26.0,
        pocaterraFlow: 23.0,
      );

      final timeString = entry.getArrivalTimeString(travelTimeMinutes: 45);
      expect(timeString, equals('4:45pm'));
    });

    test('flow status is correct', () {
      expect(
        HourlyFlowEntry(
          period: '2025-10-17 01',
          barrierFlow: 0,
          pocaterraFlow: 0,
        ).flowStatus,
        equals(FlowStatus.offline),
      );

      expect(
        HourlyFlowEntry(
          period: '2025-10-17 01',
          barrierFlow: 5,
          pocaterraFlow: 0,
        ).flowStatus,
        equals(FlowStatus.tooLow),
      );

      expect(
        HourlyFlowEntry(
          period: '2025-10-17 01',
          barrierFlow: 15,
          pocaterraFlow: 0,
        ).flowStatus,
        equals(FlowStatus.low),
      );

      expect(
        HourlyFlowEntry(
          period: '2025-10-17 01',
          barrierFlow: 25,
          pocaterraFlow: 0,
        ).flowStatus,
        equals(FlowStatus.moderate),
      );

      expect(
        HourlyFlowEntry(
          period: '2025-10-17 01',
          barrierFlow: 35,
          pocaterraFlow: 0,
        ).flowStatus,
        equals(FlowStatus.high),
      );
    });
  });

  group('TransAltaFlowData', () {
    test('getHighFlowHours filters correctly', () {
      final json = {
        'name': 'test',
        'elements': [
          {
            'day': 0,
            'entry': [
              {'period': '2025-10-17 01', 'barrier': 8, 'pocaterra': 3},
              {'period': '2025-10-17 17', 'barrier': 26, 'pocaterra': 23},
              {'period': '2025-10-17 18', 'barrier': 26, 'pocaterra': 23},
            ],
          },
        ],
      };

      final data = TransAltaFlowData.fromJson(json);
      final highFlows = data.getHighFlowHours(threshold: 20.0);

      expect(highFlows.length, equals(1)); // 1 day
      expect(highFlows[0].entries.length, equals(2)); // 2 high flow hours
    });

    test('currentFlow returns first entry of first day', () {
      final json = {
        'name': 'test',
        'elements': [
          {
            'day': 0,
            'entry': [
              {'period': '2025-10-17 01', 'barrier': 8, 'pocaterra': 3},
              {'period': '2025-10-17 02', 'barrier': 1, 'pocaterra': 1},
            ],
          },
        ],
      };

      final data = TransAltaFlowData.fromJson(json);
      final current = data.currentFlow;

      expect(current, isNotNull);
      expect(current!.barrierFlow, equals(8.0));
      expect(current.hourEnding, equals(1));
    });
  });

  group('HighFlowPeriod', () {
    test('calculates properties correctly', () {
      final entries = [
        HourlyFlowEntry(
          period: '2025-10-17 17',
          barrierFlow: 26,
          pocaterraFlow: 23,
        ),
        HourlyFlowEntry(
          period: '2025-10-17 18',
          barrierFlow: 26,
          pocaterraFlow: 23,
        ),
        HourlyFlowEntry(
          period: '2025-10-17 19',
          barrierFlow: 26,
          pocaterraFlow: 23,
        ),
      ];

      final period = HighFlowPeriod(
        date: DateTime(2025, 10, 17),
        dayNumber: 0,
        entries: entries,
        threshold: 20.0,
      );

      expect(period.totalHours, equals(3));
      expect(period.firstArrivalTime, equals('4:45pm'));
      expect(period.lastArrivalTime, equals('6:45pm'));
      expect(period.arrivalTimeRange, equals('4:45pm - 6:45pm'));
      expect(period.dateString, equals('2025-10-17'));
    });
  });
}
