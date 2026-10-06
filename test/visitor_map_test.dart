import 'package:capstone_project/data/cemetery_store.dart';
import 'package:capstone_project/screens/map_navigation_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Map tab opens with an occupied grave ready for directions', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await CemeteryStore.instance.initialize();

    await tester.pumpWidget(const MaterialApp(home: MapNavigationScreen()));
    await tester.pump();

    expect(find.text('Pedro Dela Cruz'), findsOneWidget);
    expect(find.text('Block 12 · Lot 45 · Grave 3'), findsOneWidget);
    expect(find.text('START NAVIGATION'), findsOneWidget);
    expect(find.byTooltip('Share grave location'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.ancestor(
              of: find.text('START NAVIGATION'),
              matching: find.byType(FilledButton),
            ),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('grave photo and navigation action fit a short phone screen', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await CemeteryStore.instance.initialize();
    await tester.binding.setSurfaceSize(const Size(320, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: MapNavigationScreen()));
    await tester.pump();

    expect(find.text('Pedro Dela Cruz'), findsOneWidget);
    expect(find.text('START NAVIGATION'), findsOneWidget);
    expect(
      tester.getBottomRight(find.text('START NAVIGATION')).dy,
      lessThan(480),
    );
    expect(tester.takeException(), isNull);
  });
}
