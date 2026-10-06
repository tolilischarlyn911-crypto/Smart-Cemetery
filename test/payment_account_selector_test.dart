import 'package:capstone_project/data/cemetery_store.dart';
import 'package:capstone_project/screens/admin/admin_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('payment selector distinguishes duplicate names', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = CemeteryStore.instance;
    await store.initialize();
    store.users.add({
      'id': 'another-visitor',
      'name': 'Visitor User',
      'email': 'another@example.com',
      'role': 'visitor',
    });
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(home: AdminShell()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Payments & Leases').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add payment'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No account linked'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('visitor@example.com · Visitor User'), findsOneWidget);
    expect(find.text('another@example.com · Visitor User'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('lease selector distinguishes duplicate names', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = CemeteryStore.instance;
    await store.initialize();
    store.users.add({
      'id': 'another-visitor',
      'name': 'Visitor User',
      'email': 'another@example.com',
      'role': 'visitor',
    });
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(home: AdminShell()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Payments & Leases').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add lease'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No linked account'));
    await tester.pumpAndSettle();
    expect(find.text('visitor@example.com · Visitor User'), findsOneWidget);
    expect(find.text('another@example.com · Visitor User'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });
}
