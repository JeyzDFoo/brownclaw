import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:brownclaw/services/persistent_cache_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // Clear any existing data before each test
    SharedPreferences.setMockInitialValues({});
  });

  group('PersistentCacheService', () {
    test('should save and load static cache', () async {
      // Arrange
      final testCache = {
        'key1': {'data': 'value1'},
        'key2': {'data': 'value2'},
      };
      final testTimestamps = {'key1': DateTime.now(), 'key2': DateTime.now()};

      // Act - Save
      await PersistentCacheService.saveStaticCache(testCache, testTimestamps);

      // Act - Load
      final loadedCache = await PersistentCacheService.loadStaticCache();
      final loadedTimestamps =
          await PersistentCacheService.loadStaticTimestamps();

      // Assert
      expect(loadedCache.length, 2);
      expect(loadedCache['key1']?['data'], 'value1');
      expect(loadedCache['key2']?['data'], 'value2');
      expect(loadedTimestamps.length, 2);
      expect(loadedTimestamps.containsKey('key1'), true);
      expect(loadedTimestamps.containsKey('key2'), true);
    });

    test('should save and load live data cache', () async {
      // Arrange
      final testCache = {
        'station1': {'flow': 100.5, 'level': 2.3},
        'station2': {'flow': 200.0, 'level': 3.1},
      };
      final testTimestamps = {
        'station1': DateTime.now(),
        'station2': DateTime.now(),
      };

      // Act - Save
      await PersistentCacheService.saveLiveDataCache(testCache, testTimestamps);

      // Act - Load
      final loadedCache = await PersistentCacheService.loadLiveDataCache();
      final loadedTimestamps =
          await PersistentCacheService.loadLiveTimestamps();

      // Assert
      expect(loadedCache.length, 2);
      expect(loadedCache['station1']?['flow'], 100.5);
      expect(loadedCache['station2']?['level'], 3.1);
      expect(loadedTimestamps.length, 2);
    });

    test('should clear all cache', () async {
      // Arrange
      final testCache = {
        'key1': {'data': 'value'},
      };
      final testTimestamps = {'key1': DateTime.now()};
      await PersistentCacheService.saveStaticCache(testCache, testTimestamps);
      await PersistentCacheService.saveLiveDataCache(testCache, testTimestamps);

      // Act
      await PersistentCacheService.clearAllCache();

      // Assert
      final staticCache = await PersistentCacheService.loadStaticCache();
      final liveCache = await PersistentCacheService.loadLiveDataCache();
      expect(staticCache.isEmpty, true);
      expect(liveCache.isEmpty, true);
    });

    test('should clear only static cache', () async {
      // Arrange
      final testCache = {
        'key1': {'data': 'value'},
      };
      final testTimestamps = {'key1': DateTime.now()};
      await PersistentCacheService.saveStaticCache(testCache, testTimestamps);
      await PersistentCacheService.saveLiveDataCache(testCache, testTimestamps);

      // Act
      await PersistentCacheService.clearStaticCache();

      // Assert
      final staticCache = await PersistentCacheService.loadStaticCache();
      final liveCache = await PersistentCacheService.loadLiveDataCache();
      expect(staticCache.isEmpty, true);
      expect(liveCache.isEmpty, false);
    });

    test('should clear only live data cache', () async {
      // Arrange
      final testCache = {
        'key1': {'data': 'value'},
      };
      final testTimestamps = {'key1': DateTime.now()};
      await PersistentCacheService.saveStaticCache(testCache, testTimestamps);
      await PersistentCacheService.saveLiveDataCache(testCache, testTimestamps);

      // Act
      await PersistentCacheService.clearLiveDataCache();

      // Assert
      final staticCache = await PersistentCacheService.loadStaticCache();
      final liveCache = await PersistentCacheService.loadLiveDataCache();
      expect(staticCache.isEmpty, false);
      expect(liveCache.isEmpty, true);
    });

    test('should remove specific cache entry', () async {
      // Arrange
      final testCache = {
        'key1': {'data': 'value1'},
        'key2': {'data': 'value2'},
      };
      final testTimestamps = {'key1': DateTime.now(), 'key2': DateTime.now()};
      await PersistentCacheService.saveStaticCache(testCache, testTimestamps);

      // Act
      await PersistentCacheService.removeEntry('key1', isLiveData: false);

      // Assert
      final loadedCache = await PersistentCacheService.loadStaticCache();
      expect(loadedCache.containsKey('key1'), false);
      expect(loadedCache.containsKey('key2'), true);
    });

    test('should handle empty cache gracefully', () async {
      // Act
      final staticCache = await PersistentCacheService.loadStaticCache();
      final liveCache = await PersistentCacheService.loadLiveDataCache();

      // Assert
      expect(staticCache.isEmpty, true);
      expect(liveCache.isEmpty, true);
    });

    test('should preserve data across multiple load/save cycles', () async {
      // Arrange
      final originalCache = {
        'key1': {
          'nested': {'data': 'value'},
        },
      };
      final originalTimestamps = {'key1': DateTime.now()};

      // Act - Save, load, save again, load again
      await PersistentCacheService.saveStaticCache(
        originalCache,
        originalTimestamps,
      );
      final firstLoad = await PersistentCacheService.loadStaticCache();
      await PersistentCacheService.saveStaticCache(
        firstLoad,
        originalTimestamps,
      );
      final secondLoad = await PersistentCacheService.loadStaticCache();

      // Assert
      expect(secondLoad['key1']?['nested']?['data'], 'value');
    });
  });
}
