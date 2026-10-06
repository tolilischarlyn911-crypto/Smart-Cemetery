import 'package:capstone_project/data/cemetery_store.dart';
import 'package:capstone_project/models/user_model.dart';
import 'package:capstone_project/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('preview visitor sees a recorded visit in My Visits', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    SharedPreferences.setMockInitialValues({});
    final store = CemeteryStore.instance;
    await store.initialize();
    await store.addVisit('pedro-dela-cruz', 'preview-visitor');

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          user: UserModel(
            email: 'preview@example.com',
            name: 'Preview Visitor',
          ),
          onNavigateTab: (_) {},
          onLogout: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    final visitsButton = find.text('My Visits');
    await tester.ensureVisible(visitsButton);
    await tester.pumpAndSettle();
    await tester.tap(visitsButton);
    await tester.pumpAndSettle();

    expect(find.text('My Visits History'), findsOneWidget);
    expect(find.text('Pedro Dela Cruz'), findsOneWidget);
    expect(find.textContaining('Visited '), findsOneWidget);
  });

  test(
    'visit history keeps this visitor and shows newest visit first',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = CemeteryStore.instance;
      await store.initialize();
      store.visits
        ..clear()
        ..addAll([
          {
            'id': 'old',
            'visitorId': 'preview-visitor',
            'date': '2026-01-01T10:00:00',
          },
          {
            'id': 'other',
            'visitorId': 'other-visitor',
            'date': '2026-12-01T10:00:00',
          },
          {
            'id': 'new',
            'visitorId': 'preview-visitor',
            'date': '2026-09-01T10:00:00',
          },
        ]);

      expect(
        store.visitsForVisitor('preview-visitor').map((visit) => visit['id']),
        ['new', 'old'],
      );
    },
  );
}
