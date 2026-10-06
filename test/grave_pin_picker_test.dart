import 'package:capstone_project/screens/admin/grave_pin_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  testWidgets('admin can select a map point and use it as a grave pin', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    LatLng? chosen;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                chosen = await GravePinPicker.pick(
                  context,
                  title: 'Place grave pin',
                  center: const LatLng(14.6327, 120.9897),
                );
              },
              child: const Text('Choose pin'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Choose pin'));
    await tester.pump();
    expect(find.text('No pin selected'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.tapAt(tester.getCenter(find.byType(FlutterMap)));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('No pin selected'), findsNothing);
    await tester.tap(find.text('Use this pin'));
    await tester.pumpAndSettle();
    expect(chosen, isNotNull);
    expect(chosen!.latitude, closeTo(14.6327, 0.01));
    expect(chosen!.longitude, closeTo(120.9897, 0.01));
  });

  testWidgets('existing map pin can be dragged before saving', (tester) async {
    tester.view.physicalSize = const Size(1100, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    const start = LatLng(14.6327, 120.9897);
    LatLng? chosen;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                chosen = await GravePinPicker.pick(
                  context,
                  title: 'Move grave pin',
                  center: start,
                  initialPoint: start,
                );
              },
              child: const Text('Move pin'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Move pin'));
    await tester.pump();
    await tester.drag(find.byIcon(Icons.add_location), const Offset(70, 0));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Use this pin'));
    await tester.pumpAndSettle();
    expect(chosen, isNotNull);
    expect(chosen!.longitude, greaterThan(start.longitude));
  });
}
