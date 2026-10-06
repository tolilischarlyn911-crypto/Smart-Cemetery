import 'package:capstone_project/data/cemetery_store.dart';
import 'package:capstone_project/screens/admin/admin_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('grave editor separates plot, burial, photos and map fields', (
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

    await tester.pumpWidget(const MaterialApp(home: AdminShell()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grave Management').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pedro Dela Cruz').first);
    await tester.pumpAndSettle();

    expect(find.text('Plot identity and availability'), findsOneWidget);
    expect(find.text('Deceased and memorial details'), findsNothing);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Deceased and memorial details'), findsOneWidget);
    expect(find.text('Birth date (YYYY-MM-DD)'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Portrait, tomb, and gallery'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Place the grave pin on the map'), findsOneWidget);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Portrait, tomb, and gallery'), findsOneWidget);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Family message'),
      'Remembered with love.',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
      CemeteryStore.instance.graves
          .firstWhere((grave) => grave.name == 'Pedro Dela Cruz')
          .message,
      'Remembered with love.',
    );
  });

  testWidgets('grave editor steps fit a narrow admin viewport', (tester) async {
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
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grave Management').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pedro Dela Cruz').first);
    await tester.pumpAndSettle();
    expect(find.text('Plot identity and availability'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Deceased and memorial details'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Portrait, tomb, and gallery'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(tester.getBottomRight(find.text('Save')).dx, lessThan(390));
    expect(tester.getBottomRight(find.text('Save')).dy, lessThan(844));
    expect(
      (tester.getTopLeft(find.text('Save')).dy -
              tester.getTopLeft(find.text('Next')).dy)
          .abs(),
      lessThan(10),
    );
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Place the grave pin on the map'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
