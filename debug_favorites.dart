import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'lib/firebase_options.dart';
import 'lib/services/favorite_rivers_service.dart';
import 'lib/services/water_station_service.dart';
import 'lib/services/live_water_data_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Debug favorite stations issue
  debugFavorites();
}

void debugFavorites() async {
  print('🔍 Debugging favorite stations...');

  // First, check if water stations DB needs seeding
  final needsSeeding = await WaterStationService.needsSeeding();
  print('📊 Water stations DB needs seeding: $needsSeeding');

  if (needsSeeding) {
    print('🌱 Seeding water stations database...');
    await WaterStationService.seedPopularStations();
    print('✅ Seeding complete');
  }

  // Test getting favorites
  print('🎯 Testing favorite stations retrieval...');
  FavoriteRiversService.getUserFavorites().listen((favorites) async {
    print('📋 User favorites: $favorites');

    if (favorites.isEmpty) {
      print('❌ No favorites found');
      return;
    }

    // Test each favorite station
    for (final stationId in favorites) {
      print('\n🏞️ Testing station: $stationId');

      // Check if station exists in database
      final stationInfo = await WaterStationService.getStationById(stationId);
      if (stationInfo == null) {
        print('❌ Station $stationId not found in database');
      } else {
        print(
          '✅ Station info found: ${stationInfo['riverName']} - ${stationInfo['stationName']}',
        );
      }

      // Test live data
      final liveData = await LiveWaterDataService.fetchStationData(stationId);
      if (liveData == null) {
        print('❌ No live data for station $stationId');
      } else {
        print('✅ Live data: ${liveData['flowRate']}m³/s');
      }

      // Test enriched data (what the app actually uses)
      final enrichedData = await LiveWaterDataService.getEnrichedStationData(
        stationId,
      );
      if (enrichedData == null) {
        print('❌ No enriched data for station $stationId');
      } else {
        print(
          '✅ Enriched data: ${enrichedData['riverName']} - ${enrichedData['status']}',
        );
      }
    }
  });
}
