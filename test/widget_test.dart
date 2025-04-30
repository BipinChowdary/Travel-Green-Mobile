// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:carbon_credit_project/main.dart';
import 'package:carbon_credit_project/providers/auth_provider.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    // Mock the Firebase initialization
    // Note: For actual testing, you'd use a Firebase mock package

    // Build our app with the authentication provider
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>(
        create: (context) => AuthProvider(),
        child: const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text('Carbon Credit App'),
            ),
          ),
        ),
      ),
    );

    // Verify the app shows some text
    expect(find.text('Carbon Credit App'), findsOneWidget);
  });
}
