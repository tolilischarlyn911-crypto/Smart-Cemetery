import 'package:capstone_project/data/cemetery_store.dart';
import 'package:capstone_project/screens/admin/admin_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('staff navigation exposes operational sections only', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await CemeteryStore.instance.initialize();
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(home: AdminShell(role: 'staff')));
    await tester.pumpAndSettle();
    for (final title in [
      'Burial Records',
      'Grave Management',
      'Map Management',
      'Maintenance',
    ]) {
      expect(find.text(title), findsWidgets);
    }
    for (final title in [
      'Dashboard',
      'Payments & Leases',
      'Reports & Analytics',
      'ML Predictions',
      'User Management',
      'System Settings',
    ]) {
      expect(find.text(title), findsNothing);
    }
    await tester.tap(find.text('Maintenance').first);
    await tester.pumpAndSettle();
    expect(find.text('Review and update reported issues'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
