import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:brownclaw/screens/favourites_screen.dart';
import 'package:brownclaw/providers/providers.dart';
import 'package:brownclaw/models/models.dart';

// Mock providers for testing
class MockFavoritesProvider extends ChangeNotifier
    implements FavoritesProvider {
  Set<String> _mockFavoriteIds = {};
  bool _isLoading = false;
  String? _error;

  @override
  Set<String> get favoriteRunIds => _mockFavoriteIds;

  @override
  bool get isLoading => _isLoading;

  @override
  String? get error => _error;

  void setMockFavorites(Set<String> ids) {
    _mockFavoriteIds = ids;
    notifyListeners();
  }

  @override
  bool isFavorite(String runId) => _mockFavoriteIds.contains(runId);

  @override
  Future<void> toggleFavorite(String runId) async {
    if (_mockFavoriteIds.contains(runId)) {
      _mockFavoriteIds.remove(runId);
    } else {
      _mockFavoriteIds.add(runId);
    }
    notifyListeners();
  }

  @override
  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  @override
  void setError(String? error) {
    _error = error;
    notifyListeners();
  }

  @override
  void clearError() {
    _error = null;
    notifyListeners();
  }
}

class MockRiverRunProvider extends RiverRunProvider {
  List<RiverRunWithStations> _mockFavoriteRuns = [];
  bool _mockIsLoading = false;
  String? _mockError;
  int loadCallCount = 0; // Track number of loadFavoriteRuns calls

  @override
  List<RiverRunWithStations> get favoriteRuns => _mockFavoriteRuns;

  @override
  bool get isLoading => _mockIsLoading;

  @override
  String? get error => _mockError;

  void setMockFavoriteRuns(List<RiverRunWithStations> runs) {
    _mockFavoriteRuns = runs;
    notifyListeners();
  }

  @override
  Future<void> loadFavoriteRuns(Set<String> favoriteRunIds) async {
    loadCallCount++; // Increment counter

    _mockIsLoading = true;
    notifyListeners();

    // Simulate loading delay
    await Future.delayed(const Duration(milliseconds: 100));

    // Filter mock runs based on favorite IDs
    _mockFavoriteRuns = _allMockRuns
        .where((run) => favoriteRunIds.contains(run.run.id))
        .toList();

    _mockIsLoading = false;
    notifyListeners();
  } // Static mock data

  static final List<RiverRunWithStations> _allMockRuns = [
    RiverRunWithStations(
      run: RiverRun(
        id: 'run1',
        riverId: 'river1',
        name: 'Upper Section',
        difficultyClass: 'Class III',
        description: 'Fun rapids',
        minRecommendedFlow: 10.0,
        maxRecommendedFlow: 50.0,
      ),
      river: River(
        id: 'river1',
        name: 'Kicking Horse River',
        region: 'British Columbia',
        country: 'Canada',
      ),
      stations: [],
    ),
    RiverRunWithStations(
      run: RiverRun(
        id: 'run2',
        riverId: 'river2',
        name: 'Lower Canyon',
        difficultyClass: 'Class IV',
        description: 'Challenging run',
        minRecommendedFlow: 15.0,
        maxRecommendedFlow: 60.0,
      ),
      river: River(
        id: 'river2',
        name: 'Elbow River',
        region: 'Alberta',
        country: 'Canada',
      ),
      stations: [],
    ),
  ];
}

class MockLiveWaterDataProvider extends LiveWaterDataProvider {
  @override
  LiveWaterData? getLiveData(String stationId) => null;

  @override
  Future<LiveWaterData?> fetchStationData(String stationId) async => null;

  @override
  Future<void> fetchMultipleStations(List<String> stationIds) async {}
}

void main() {
  group('FavouritesScreen Favorites Tests', () {
    late MockFavoritesProvider mockFavoritesProvider;
    late MockRiverRunProvider mockRiverRunProvider;
    late MockLiveWaterDataProvider mockLiveWaterDataProvider;

    setUp(() {
      mockFavoritesProvider = MockFavoritesProvider();
      mockRiverRunProvider = MockRiverRunProvider();
      mockLiveWaterDataProvider = MockLiveWaterDataProvider();
    });

    Widget createTestWidget() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<FavoritesProvider>.value(
            value: mockFavoritesProvider,
          ),
          ChangeNotifierProvider<RiverRunProvider>.value(
            value: mockRiverRunProvider,
          ),
          ChangeNotifierProvider<LiveWaterDataProvider>.value(
            value: mockLiveWaterDataProvider,
          ),
        ],
        child: const MaterialApp(home: FavouritesScreen()),
      );
    }

    testWidgets('should show empty state when no favorites', (
      WidgetTester tester,
    ) async {
      // Arrange: No favorites
      mockFavoritesProvider.setMockFavorites({});

      // Act
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      // Assert
      expect(find.text('No Favorite River Runs Yet'), findsOneWidget);
      expect(find.text('Add River Runs'), findsOneWidget);
    });

    testWidgets('should load and display favorites on initial render', (
      WidgetTester tester,
    ) async {
      // Skip: This test requires Firebase to be initialized for StreamBuilder
      // TODO: Mock RiverRunService.watchRunById() to avoid Firebase dependency
    }, skip: true);

    testWidgets('should update list when favorite is added', (
      WidgetTester tester,
    ) async {
      // Skip: This test requires Firebase to be initialized for StreamBuilder
      // TODO: Mock RiverRunService.watchRunById() to avoid Firebase dependency
    }, skip: true);

    testWidgets('should update list when favorite is removed', (
      WidgetTester tester,
    ) async {
      // Skip: This test requires Firebase to be initialized for StreamBuilder
      // TODO: Mock RiverRunService.watchRunById() to avoid Firebase dependency
    }, skip: true);

    testWidgets('should show empty state when all favorites are removed', (
      WidgetTester tester,
    ) async {
      // Skip: This test requires Firebase to be initialized for StreamBuilder
      // TODO: Mock RiverRunService.watchRunById() to avoid Firebase dependency
    }, skip: true);

    testWidgets('should not create infinite loop when favorites change', (
      WidgetTester tester,
    ) async {
      // Skip: This test requires Firebase to be initialized for StreamBuilder
      // TODO: Mock RiverRunService.watchRunById() to avoid Firebase dependency
    }, skip: true);

    testWidgets('should show refresh button', (WidgetTester tester) async {
      // Arrange
      mockFavoritesProvider.setMockFavorites({});

      // Act
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      // Assert
      expect(find.text('Refresh'), findsOneWidget);
    });

    testWidgets('should display river difficulty correctly', (
      WidgetTester tester,
    ) async {
      // Skip: This test requires Firebase to be initialized for StreamBuilder
      // TODO: Mock RiverRunService.watchRunById() to avoid Firebase dependency
    }, skip: true);
  });
}
