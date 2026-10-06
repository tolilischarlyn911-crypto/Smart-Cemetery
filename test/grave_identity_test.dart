import 'package:capstone_project/data/cemetery_store.dart';
import 'package:capstone_project/models/cemetery_models.dart';
import 'package:capstone_project/screens/admin/admin_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('grave save rejects another record at the same plot identity', () async {
    SharedPreferences.setMockInitialValues({});
    final store = CemeteryStore.instance;
    await store.initialize();
    final originalCount = store.graves.length;
    final pedro = store.graveById('pedro-dela-cruz')!;

    await expectLater(
      store.saveGrave(
        const Grave(
          id: 'duplicate-plot',
          name: 'Duplicate',
          block: ' 12 ',
          lot: '1',
          number: '1',
          mapRow: 5,
          mapColumn: 0,
        ),
      ),
      throwsStateError,
    );
    await expectLater(
      store.saveGrave(
        Grave.fromJson({
          ...pedro.toJson(),
          'block': '12',
          'lot': '1',
          'number': '1',
        }),
      ),
      throwsStateError,
    );
    await store.saveGrave(pedro);
    expect(store.graves.length, originalCount);
    expect(store.graveById('duplicate-plot'), isNull);
  });

  testWidgets('grave editor identifies a duplicate before saving', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = CemeteryStore.instance;
    await store.initialize();
    final originalCount = store.graves.length;
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
    await tester.tap(find.text('Add plot'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Block'), '12');
    await tester.enterText(find.widgetWithText(TextFormField, 'Lot'), '1');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Grave number'),
      '1',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'A record already exists for this block, lot, and grave number.',
      ),
      findsOneWidget,
    );
    expect(store.graves.length, originalCount);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });
}
