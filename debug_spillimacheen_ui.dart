import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'lib/firebase_options.dart';
import 'lib/services/live_water_data_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Skip Firebase for now to avoid config issues
  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spillimacheen Debug',
      home: SpillimacheenDebugScreen(),
    );
  }
}

class SpillimacheenDebugScreen extends StatefulWidget {
  @override
  _SpillimacheenDebugScreenState createState() =>
      _SpillimacheenDebugScreenState();
}

class _SpillimacheenDebugScreenState extends State<SpillimacheenDebugScreen> {
  String _result = 'Tap button to test';
  bool _isLoading = false;

  Future<void> _testSpillimacheenData() async {
    setState(() {
      _isLoading = true;
      _result = 'Loading...';
    });

    try {
      print('🧪 STARTING SPILLIMACHEEN TEST');

      final data = await LiveWaterDataService.fetchStationData('08NA011');

      if (data != null) {
        final flowRate = data['flowRate'];
        final timestamp = data['lastUpdate'];
        final stationName = data['stationName'];

        setState(() {
          _result =
              '''✅ SUCCESS!
Station: $stationName
Flow Rate: $flowRate m³/s
Timestamp: $timestamp

${flowRate == 34.8 ? '⚠️ STILL OLD DATA!' : '🎉 NEW DATA WORKING!'}''';
        });

        print('🎉 TEST COMPLETE - Flow Rate: $flowRate m³/s');
      } else {
        setState(() {
          _result = '❌ No data returned';
        });
        print('❌ TEST FAILED - No data returned');
      }
    } catch (e) {
      setState(() {
        _result = '💥 Error: $e';
      });
      print('💥 TEST ERROR: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Spillimacheen Debug'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Debug Spillimacheen Data Fetch',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text(
              'Expected: ~8.43 m³/s (current data)\nPrevious wrong: 34.8 m³/s (old data)',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _testSpillimacheenData,
              child: _isLoading
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text('Test Spillimacheen Data'),
            ),
            SizedBox(height: 20),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _result,
                style: TextStyle(fontSize: 14, fontFamily: 'monospace'),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Check the console/debug output for detailed logs!',
              style: TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ],
        ),
      ),
    );
  }
}
