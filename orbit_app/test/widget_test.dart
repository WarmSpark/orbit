// Smoke test for the Orbit app.
//
// Pumps the splash screen (no plugins/network required) and verifies the
// brand renders. Fuller flows are covered by manual/integration testing since
// they depend on Google Sign-In, geolocation and the backend.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:orbit_app/screens/splash_screen.dart';
import 'package:orbit_app/theme.dart';

void main() {
  testWidgets('Splash shows the Orbit brand', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildOrbitTheme(Brightness.light), home: const SplashScreen()),
    );

    expect(find.text('Orbit'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
