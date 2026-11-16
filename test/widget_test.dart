import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:scrap_scan/main.dart';
import 'package:scrap_scan/core/constants/app_constants.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'v1_migrated_to_sqlite': true,
    });
  });

  testWidgets('ScrapScanApp loads Home screen with branding and tagline', (WidgetTester tester) async {
    await tester.pumpWidget(const ScrapScanApp());
    await tester.pumpAndSettle();

    // Verify title and identity preserved
    expect(find.text(AppConstants.appName), findsOneWidget);
    expect(find.text(AppConstants.tagline), findsOneWidget);
    expect(find.text('Ready to scan?'), findsOneWidget);
    expect(find.text('Start Scanning'), findsOneWidget);

    // Verify bottom navigation bar destinations
    expect(find.byIcon(Icons.home_rounded), findsOneWidget);
    expect(find.byIcon(Icons.history_outlined), findsOneWidget);
    expect(find.byIcon(Icons.analytics_outlined), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
  });
}
