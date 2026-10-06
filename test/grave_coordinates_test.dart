import 'package:capstone_project/data/cemetery_store.dart';
import 'package:capstone_project/models/cemetery_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('grave map locations require a valid coordinate pair', () async {
    SharedPreferences.setMockInitialValues({});
    final store = CemeteryStore.instance;
    await store.initialize();

    Future<void> rejects(double? latitude, double? longitude) async {
      await expectLater(
        store.saveGrave(
          Grave(
            id: 'bad-location',
            name: 'Test',
            block: '1',
            lot: '1',
            number: '1',
            mapRow: 0,
            mapColumn: 0,
            latitude: latitude,
            longitude: longitude,
          ),
        ),
        throwsArgumentError,
      );
    }

    await rejects(14.63, null);
    await rejects(91, 120.98);
    await rejects(double.nan, 120.98);
    expect(store.graveById('bad-location'), isNull);

    await store.saveGrave(
      const Grave(
        id: 'valid-location',
        name: 'Test',
        block: '1',
        lot: '1',
        number: '1',
        mapRow: 0,
        mapColumn: 0,
        latitude: 14.63,
        longitude: 120.98,
      ),
    );
    expect(store.graveById('valid-location')?.hasValidCoordinates, isTrue);
  });

  test('cemetery center persists and rejects incomplete coordinates', () async {
    SharedPreferences.setMockInitialValues({});
    final store = CemeteryStore.instance;
    await store.initialize();
    expect(store.mapCenter?.latitude, 14.6327);

    await store.saveSettings({
      'mapCenterLatitude': 14.6,
      'mapCenterLongitude': 120.9,
    });
    await store.initialize();
    expect(store.mapCenter?.latitude, 14.6);
    expect(store.mapCenter?.longitude, 120.9);

    await store.saveSettings({'mapCenterLongitude': null});
    expect(store.mapCenter, isNull);
    await store.saveSettings({
      'mapCenterLatitude': 95,
      'mapCenterLongitude': 120.9,
    });
    expect(store.mapCenter, isNull);
  });

  test('an unpinned preview grave stays unpinned after reload', () async {
    SharedPreferences.setMockInitialValues({});
    final store = CemeteryStore.instance;
    await store.initialize();
    await store.saveGrave(
      const Grave(
        id: 'unpinned',
        name: 'Unpinned grave',
        block: '2',
        lot: '3',
        number: '1',
        mapRow: 0,
        mapColumn: 0,
      ),
    );

    await store.initialize();
    expect(store.graveById('unpinned')?.hasValidCoordinates, isFalse);
  });
}
