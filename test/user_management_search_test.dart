import 'package:capstone_project/data/cemetery_store.dart';
import 'package:capstone_project/screens/admin/admin_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('admin can filter account list by name or email', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await CemeteryStore.instance.initialize();
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
    expect(find.text('Admin User'), findsOneWidget);
    expect(find.text('Visitor User'), findsOneWidget);

    final search = find.widgetWithText(TextField, 'Search accounts');
    await tester.enterText(search, 'visitor@example.com');
    await tester.pumpAndSettle();
    expect(find.text('Visitor User'), findsOneWidget);
    expect(find.text('Admin User'), findsNothing);

    await tester.enterText(search, 'nothing matches');
    await tester.pumpAndSettle();
    expect(find.text('No accounts match this search.'), findsOneWidget);
  });
}
