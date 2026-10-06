import 'package:capstone_project/data/cemetery_store.dart';
import 'package:capstone_project/models/cemetery_models.dart';
import 'package:capstone_project/screens/request_maintenance_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('visitor sees an updated maintenance request status', (
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
    await store.addRequest(
      MaintenanceRequest(
        id: 'request-history-test',
        graveId: 'pedro-dela-cruz',
        issue: 'Overgrown Grass',
        description: 'Grass needs trimming.',
        requestedBy: 'preview-visitor',
        createdAt: DateTime(2026, 10, 4),
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(home: RequestMaintenanceScreen()),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('My Requests'));
    await tester.pumpAndSettle();
    expect(find.text('Overgrown Grass'), findsOneWidget);
    expect(find.textContaining('Pending · Medium priority'), findsOneWidget);

    await store.updateRequest('request-history-test', 'In Progress', 'High');
    await tester.pumpAndSettle();
    expect(find.textContaining('In Progress · High priority'), findsOneWidget);

    store.graves.clear();
    store.notifyListeners();
    await tester.pumpAndSettle();
    expect(
      find.text('No occupied graves are available for requests.'),
      findsOneWidget,
    );
    expect(find.textContaining('In Progress · High priority'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });
}
