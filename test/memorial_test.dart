import 'package:capstone_project/data/cemetery_store.dart';
import 'package:capstone_project/models/cemetery_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('grave QR code identifies the same memorial', () {
    const grave = Grave(
      id: 'pedro-dela-cruz',
      name: 'Pedro Dela Cruz',
      block: '12',
      lot: '45',
      number: '3',
      mapRow: 2,
      mapColumn: 3,
    );
    expect(Grave.idFromQr(grave.qrValue), grave.id);
    expect(Grave.idFromQr('smart-cemetery:grave:'), isNull);
    expect(Grave.idFromQr('https://example.com'), isNull);
  });

  test('memorial gallery photos persist in preview records', () async {
    SharedPreferences.setMockInitialValues({});
    final store = CemeteryStore.instance;
    await store.initialize();
    await store.saveGrave(
      const Grave(
        id: 'gallery-memorial',
        name: 'Gallery Memorial',
        block: '2',
        lot: '4',
        number: '1',
        mapRow: 0,
        mapColumn: 0,
        portraitPhotoUrl: 'https://example.com/portrait.jpg',
        tombPhotoUrl: 'https://example.com/tomb.jpg',
        photos: ['https://example.com/family-photo.jpg'],
      ),
    );
    await store.initialize();
    expect(store.graveById('gallery-memorial')?.photos, [
      'https://example.com/family-photo.jpg',
    ]);
    expect(
      store.graveById('gallery-memorial')?.portraitPhotoUrl,
      'https://example.com/portrait.jpg',
    );
    expect(
      store.graveById('gallery-memorial')?.tombPhotoUrl,
      'https://example.com/tomb.jpg',
    );
    expect(
      store
          .graveById('gallery-memorial')
          ?.copyWithLocation(14.63, 120.98)
          .portraitPhotoUrl,
      'https://example.com/portrait.jpg',
    );
  });
}
