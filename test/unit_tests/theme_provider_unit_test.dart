import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brownclaw/providers/theme_provider.dart';

void main() {
  group('ThemeProvider Unit Tests', () {
    late ThemeProvider themeProvider;

    setUp(() {
      themeProvider = ThemeProvider();
    });

    test('should initialize with system theme mode', () {
      expect(themeProvider.themeMode, ThemeMode.system);
      expect(themeProvider.isDarkMode, false);
    });

    test('should set theme mode to dark', () {
      themeProvider.setThemeMode(ThemeMode.dark);

      expect(themeProvider.themeMode, ThemeMode.dark);
      expect(themeProvider.isDarkMode, true);
    });

    test('should toggle from light to dark', () {
      themeProvider.setThemeMode(ThemeMode.light);
      themeProvider.toggleTheme();

      expect(themeProvider.themeMode, ThemeMode.dark);
      expect(themeProvider.isDarkMode, true);
    });

    test('should toggle from dark to light', () {
      themeProvider.setThemeMode(ThemeMode.dark);
      themeProvider.toggleTheme();

      expect(themeProvider.themeMode, ThemeMode.light);
      expect(themeProvider.isDarkMode, false);
    });

    test('should provide correct light theme data', () {
      final lightTheme = themeProvider.lightTheme;
      expect(lightTheme.brightness, Brightness.light);
      expect(lightTheme.useMaterial3, true);
    });

    test('should provide correct dark theme data', () {
      final darkTheme = themeProvider.darkTheme;
      expect(darkTheme.brightness, Brightness.dark);
      expect(darkTheme.useMaterial3, true);
    });
  });
}
