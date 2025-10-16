import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brownclaw/providers/theme_provider.dart';

void main() {
  group('ThemeProvider Tests', () {
    late ThemeProvider themeProvider;

    setUp(() {
      themeProvider = ThemeProvider();
    });

    test('should initialize with system theme mode by default', () {
      expect(themeProvider.themeMode, ThemeMode.system);
      expect(
        themeProvider.isDarkMode,
        false,
      ); // Defaults to false for system mode
    });

    test('should set theme mode to dark', () {
      themeProvider.setThemeMode(ThemeMode.dark);

      expect(themeProvider.themeMode, ThemeMode.dark);
      expect(themeProvider.isDarkMode, true);
    });

    test('should set theme mode to light', () {
      themeProvider.setThemeMode(ThemeMode.light);

      expect(themeProvider.themeMode, ThemeMode.light);
      expect(themeProvider.isDarkMode, false);
    });

    test('should toggle from system to dark/light based on current state', () {
      // Initially system mode with isDarkMode false
      expect(themeProvider.themeMode, ThemeMode.system);
      expect(themeProvider.isDarkMode, false);

      // Toggle should switch to dark mode
      themeProvider.toggleTheme();
      expect(themeProvider.themeMode, ThemeMode.dark);
      expect(themeProvider.isDarkMode, true);
    });

    test('should toggle between light and dark modes', () {
      // Set to light mode first
      themeProvider.setThemeMode(ThemeMode.light);
      expect(themeProvider.isDarkMode, false);

      // Toggle to dark mode
      themeProvider.toggleTheme();
      expect(themeProvider.themeMode, ThemeMode.dark);
      expect(themeProvider.isDarkMode, true);

      // Toggle back to light mode
      themeProvider.toggleTheme();
      expect(themeProvider.themeMode, ThemeMode.light);
      expect(themeProvider.isDarkMode, false);
    });

    test('should notify listeners when theme changes', () {
      bool notified = false;
      themeProvider.addListener(() {
        notified = true;
      });

      themeProvider.setThemeMode(ThemeMode.dark);

      expect(notified, true);
    });

    test('should provide light theme data', () {
      final lightTheme = themeProvider.lightTheme;
      expect(lightTheme.brightness, Brightness.light);
      expect(lightTheme.useMaterial3, true);
    });

    test('should provide dark theme data', () {
      final darkTheme = themeProvider.darkTheme;
      expect(darkTheme.brightness, Brightness.dark);
      expect(darkTheme.useMaterial3, true);
    });

    test('should have brown color scheme for both themes', () {
      final lightTheme = themeProvider.lightTheme;
      final darkTheme = themeProvider.darkTheme;

      // Both themes should use brown-based color scheme
      expect(lightTheme.colorScheme.brightness, Brightness.light);
      expect(darkTheme.colorScheme.brightness, Brightness.dark);
    });
  });
}
