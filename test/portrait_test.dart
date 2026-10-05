import 'dart:convert';

import 'package:capstone_project/data/cemetery_store.dart';
import 'package:capstone_project/models/cemetery_models.dart';
import 'package:capstone_project/screens/grave_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('grave header uses the portrait instead of a gallery photo', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = CemeteryStore.instance;
    await store.initialize();
    final grave = store.graveById('pedro-dela-cruz')!;
    await store.saveGrave(
      Grave.fromJson({
        ...grave.toJson(),
        'portraitPhotoUrl': 'assets/images/portrait_sample.png',
        'photos': ['assets/images/grave_sample.png'],
      }),
    );

    await tester.pumpWidget(
      const MaterialApp(home: GraveDetailsScreen(graveId: 'pedro-dela-cruz')),
    );
    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(
      (avatar.backgroundImage as AssetImage).assetName,
      'assets/images/portrait_sample.png',
    );
  });

  test('older preview gets the sample portrait once', () async {
    SharedPreferences.setMockInitialValues({});
    final store = CemeteryStore.instance;
    await store.initialize();
    final prefs = await SharedPreferences.getInstance();
    final data =
        jsonDecode(prefs.getString('smart_cemetery_preview_v1')!)
            as Map<String, dynamic>;
    final graves = data['graves'] as List;
    final sample = graves.cast<Map>().firstWhere(
      (item) => item['id'] == 'pedro-dela-cruz',
    );
    sample.remove('portraitPhotoUrl');
    await prefs.setString('smart_cemetery_preview_v1', jsonEncode(data));

    await store.initialize();
    expect(
      store.graveById('pedro-dela-cruz')?.portraitPhotoUrl,
      'assets/images/portrait_sample.png',
    );

    final grave = store.graveById('pedro-dela-cruz')!;
    await store.saveGrave(
      Grave.fromJson({...grave.toJson(), 'portraitPhotoUrl': null}),
    );
    await store.initialize();
    expect(store.graveById('pedro-dela-cruz')?.portraitPhotoUrl, isNull);
  });
}
