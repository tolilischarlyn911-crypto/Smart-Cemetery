import 'package:capstone_project/data/cemetery_store.dart';
import 'package:capstone_project/models/cemetery_models.dart';
import 'package:capstone_project/screens/admin/admin_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('dashboard details open the matching filtered records', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = CemeteryStore.instance;
    await store.initialize();
    store.requests.addAll([
      MaintenanceRequest(
        id: 'pending-dashboard-test',
        graveId: 'pedro-dela-cruz',
        issue: 'Pending dashboard issue',
        description: '',
        requestedBy: 'preview-visitor',
        status: 'Pending',
        createdAt: DateTime(2026, 1, 2),
      ),
      MaintenanceRequest(
        id: 'completed-dashboard-test',
        graveId: 'pedro-dela-cruz',
        issue: 'Completed dashboard issue',
        description: '',
        requestedBy: 'preview-visitor',
        status: 'Completed',
        createdAt: DateTime(2026, 1, 1),
      ),
    ]);
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(home: AdminShell()));
    await tester.pumpAndSettle();
    final availableCard = find.ancestor(
      of: find.text('Available Spaces'),
      matching: find.byType(InkWell),
    );
    await tester.tap(availableCard.first);
    await tester.pumpAndSettle();
    expect(find.text('Grave Management', skipOffstage: false), findsWidgets);
    expect(find.text('Available'), findsOneWidget);
    expect(find.text('Pedro Dela Cruz'), findsNothing);

    await tester.tap(find.text('Dashboard').first);
    await tester.pumpAndSettle();
    final pendingCard = find.ancestor(
      of: find.text('Pending Requests'),
      matching: find.byType(InkWell),
    );
    await tester.tap(pendingCard.first);
    await tester.pumpAndSettle();
    expect(find.text('Pending dashboard issue'), findsOneWidget);
    expect(find.text('Completed dashboard issue'), findsNothing);
  });

  testWidgets('dashboard cards fill a narrow admin viewport', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await CemeteryStore.instance.initialize();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(home: AdminShell()));
    await tester.pumpAndSettle();
    final summaryCard = find.ancestor(
      of: find.text('Total Burials'),
      matching: find.byType(Card),
    );
    final overviewCard = find.ancestor(
      of: find.text('Cemetery Overview'),
      matching: find.byType(Card),
    );
    expect(tester.getSize(summaryCard.first).width, greaterThan(300));
    expect(tester.getSize(overviewCard.first).width, greaterThan(300));
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reports & Analytics').first);
    await tester.pumpAndSettle();
    final reportCard = find.ancestor(
      of: find.text('Burials').first,
      matching: find.byType(Card),
    );
    expect(tester.getSize(reportCard.first).width, greaterThan(300));
    expect(tester.takeException(), isNull);
  });
}
