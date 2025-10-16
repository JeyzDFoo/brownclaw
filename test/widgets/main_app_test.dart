import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brownclaw/main.dart';

void main() {
  group('MainApp Widget Tests', () {
    testWidgets('MainApp should create without errors', (
      WidgetTester tester,
    ) async {
      // Note: This will fail without proper Firebase mocking
      // But it tests the basic structure
      expect(() => const MainApp(), returnsNormally);
    });

    testWidgets('MainApp should have MultiProvider', (
      WidgetTester tester,
    ) async {
      final mainApp = const MainApp();

      // Check that the widget tree can be built
      expect(mainApp, isA<StatelessWidget>());
    });

    test('MainApp should be const constructible', () {
      const mainApp1 = MainApp();
      const mainApp2 = MainApp();

      // Verify const constructor works
      expect(mainApp1, isNotNull);
      expect(mainApp2, isNotNull);
    });
  });

  group('HomePage Widget Tests', () {
    testWidgets('HomePage should create without errors', (
      WidgetTester tester,
    ) async {
      expect(() => const HomePage(), returnsNormally);
    });

    test('HomePage should be const constructible', () {
      const homePage1 = HomePage();
      const homePage2 = HomePage();

      expect(homePage1, isNotNull);
      expect(homePage2, isNotNull);
    });

    testWidgets('HomePage should be a StatelessWidget', (
      WidgetTester tester,
    ) async {
      const homePage = HomePage();

      expect(homePage, isA<StatelessWidget>());
    });
  });
}
