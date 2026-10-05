import 'package:capstone_project/data/cemetery_store.dart';
import 'package:capstone_project/screens/admin/admin_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'preview account role changes persist across store initialization',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = CemeteryStore.instance;
      await store.initialize();
      expect(
        store.users.firstWhere(
          (user) => user['id'] == 'preview-visitor',
        )['role'],
        'visitor',
      );

      await store.updateUserRole('preview-visitor', 'admin');
      await store.initialize();
      expect(
        store.users.firstWhere(
          (user) => user['id'] == 'preview-visitor',
        )['role'],
        'admin',
      );
      await store.updateUserRole('preview-visitor', 'staff');
      await store.initialize();
      expect(
        store.users.firstWhere(
          (user) => user['id'] == 'preview-visitor',
        )['role'],
        'staff',
      );
    },
  );

  testWidgets('admin can assign staff access from user management', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = CemeteryStore.instance;
    await store.initialize();
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(home: AdminShell()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('User Management').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Change account role'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Staff').last);
    await tester.pumpAndSettle();
    expect(find.text('Grant staff access?'), findsOneWidget);
    await tester.tap(find.text('CONFIRM'));
    await tester.pumpAndSettle();
    expect(
      store.users.firstWhere((user) => user['id'] == 'preview-visitor')['role'],
      'staff',
    );
    expect(tester.takeException(), isNull);
  });

  test(
    'disconnect clears account data from memory but preserves preview records',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = CemeteryStore.instance;
      await store.initialize();
      final graveId = store.graves.first.id;
      expect(store.users, isNotEmpty);

      await store.disconnect();
      expect(store.graves, isEmpty);
      expect(store.users, isEmpty);
      expect(store.requests, isEmpty);

      await store.initialize();
      expect(store.graveById(graveId), isNotNull);
      expect(store.users, isNotEmpty);
    },
  );
}
