import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/favorites_provider.dart';
import '../providers/river_run_provider.dart';

/// Debug screen to diagnose favorites loading issues
class FavoritesDebugScreen extends StatefulWidget {
  const FavoritesDebugScreen({super.key});

  @override
  State<FavoritesDebugScreen> createState() => _FavoritesDebugScreenState();
}

class _FavoritesDebugScreenState extends State<FavoritesDebugScreen> {
  String _log = '';

  @override
  void initState() {
    super.initState();
    _runDiagnostics();
  }

  void _addLog(String message) {
    setState(() {
      _log +=
          '${DateTime.now().toIso8601String().split('T')[1].substring(0, 12)} $message\n';
    });
    print('🔧 DEBUG: $message');
  }

  Future<void> _runDiagnostics() async {
    _addLog('=== STARTING DIAGNOSTICS ===');

    // Check 1: Firebase Auth
    _addLog('');
    _addLog('1️⃣ Checking Firebase Auth...');
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      _addLog('✅ User is logged in: ${currentUser.uid}');
      _addLog('   Email: ${currentUser.email ?? "N/A"}');
    } else {
      _addLog('❌ No user logged in!');
      _addLog('   This is the problem - user must be authenticated');
      return;
    }

    await Future.delayed(Duration(milliseconds: 500));

    // Check 2: FavoritesProvider
    _addLog('');
    _addLog('2️⃣ Checking FavoritesProvider...');
    final favoritesProvider = context.read<FavoritesProvider>();
    _addLog(
      '   favoriteRunIds count: ${favoritesProvider.favoriteRunIds.length}',
    );
    _addLog('   isLoading: ${favoritesProvider.isLoading}');
    _addLog('   error: ${favoritesProvider.error ?? "none"}');

    if (favoritesProvider.favoriteRunIds.isEmpty) {
      _addLog('⚠️  No favorites loaded yet!');
      _addLog('   Waiting 2 seconds for favorites to load...');

      await Future.delayed(Duration(seconds: 2));

      _addLog('   After 2 seconds:');
      _addLog(
        '   favoriteRunIds count: ${favoritesProvider.favoriteRunIds.length}',
      );

      if (favoritesProvider.favoriteRunIds.isEmpty) {
        _addLog('❌ Still no favorites!');
        _addLog(
          '   DIAGNOSIS: FavoritesProvider._loadFavorites() not being called',
        );
        _addLog('   OR: User has no favorites in Firestore');
      } else {
        _addLog('✅ Favorites loaded!');
      }
    } else {
      _addLog(
        '✅ Favorites present: ${favoritesProvider.favoriteRunIds.join(", ")}',
      );
    }

    await Future.delayed(Duration(milliseconds: 500));

    // Check 3: RiverRunProvider
    _addLog('');
    _addLog('3️⃣ Checking RiverRunProvider...');
    final riverRunProvider = context.read<RiverRunProvider>();
    _addLog('   isInitialized: ${riverRunProvider.isInitialized}');
    _addLog('   all runs count: ${riverRunProvider.riverRuns.length}');
    _addLog('   favorite runs count: ${riverRunProvider.favoriteRuns.length}');
    _addLog('   isLoading: ${riverRunProvider.isLoading}');
    _addLog('   error: ${riverRunProvider.error ?? "none"}');

    if (riverRunProvider.riverRuns.isEmpty) {
      _addLog('⚠️  No runs loaded yet!');
    } else {
      _addLog('✅ Runs loaded successfully');
    }

    if (favoritesProvider.favoriteRunIds.isNotEmpty &&
        riverRunProvider.favoriteRuns.isEmpty) {
      _addLog('❌ MISMATCH: Favorite IDs exist but favorite runs not loaded!');
      _addLog('   DIAGNOSIS: loadFavoriteRuns() not being called by screen');
    }

    await Future.delayed(Duration(milliseconds: 500));

    // Check 4: Recommendations
    _addLog('');
    _addLog('4️⃣ Recommendations...');

    if (currentUser == null) {
      _addLog('🔧 ACTION: User must sign in first');
    } else if (favoritesProvider.favoriteRunIds.isEmpty) {
      _addLog('🔧 ACTION: Add some favorites from Find Runs screen');
      _addLog(
        '   OR check that FavoritesProvider constructor is calling _loadFavorites()',
      );
    } else if (riverRunProvider.favoriteRuns.isEmpty) {
      _addLog('🔧 ACTION: Check FavouritesScreen._checkAndReloadFavorites()');
      _addLog('   Make sure it\'s being called when favorites change');
    } else {
      _addLog('✅ Everything looks good!');
    }

    _addLog('');
    _addLog('=== DIAGNOSTICS COMPLETE ===');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorites Debug'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _log = '';
              });
              _runDiagnostics();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Diagnostic Log:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                _log.isEmpty ? 'Running diagnostics...' : _log,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  color: Colors.greenAccent,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
