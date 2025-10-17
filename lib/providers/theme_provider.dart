import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  bool _isDarkMode = false;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _isDarkMode;

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    _updateDarkMode();
    notifyListeners();
  }

  void toggleTheme() {
    if (_themeMode == ThemeMode.light) {
      setThemeMode(ThemeMode.dark);
    } else if (_themeMode == ThemeMode.dark) {
      setThemeMode(ThemeMode.light);
    } else {
      // If system, switch to opposite of current system setting
      setThemeMode(_isDarkMode ? ThemeMode.light : ThemeMode.dark);
    }
  }

  void _updateDarkMode() {
    if (_themeMode == ThemeMode.dark) {
      _isDarkMode = true;
    } else if (_themeMode == ThemeMode.light) {
      _isDarkMode = false;
    } else {
      // System mode - would need to check system brightness
      // For now, default to light
      _isDarkMode = false;
    }
  }

  // Theme data
  ThemeData get lightTheme => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.brown,
      secondary: const Color(0xFF009688), // Teal - our water/adventure color
    ),
    useMaterial3: true,
    appBarTheme: const AppBarTheme(elevation: 2, centerTitle: false),
  );

  ThemeData get darkTheme => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.brown,
      brightness: Brightness.dark,
      secondary: const Color(0xFF009688), // Teal - our water/adventure color
    ),
    useMaterial3: true,
    appBarTheme: const AppBarTheme(elevation: 2, centerTitle: false),
  );
}
