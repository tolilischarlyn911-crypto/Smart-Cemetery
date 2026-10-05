import 'dart:typed_data';

import 'package:capstone_project/data/cemetery_store.dart';
import 'package:capstone_project/models/cemetery_models.dart';
import 'package:capstone_project/services/photo_service.dart';
import 'package:capstone_project/services/profile_photo_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('preview photo persists with a maintenance request', () async {
    SharedPreferences.setMockInitialValues({});
    final store = CemeteryStore.instance;
    await store.initialize();
    final photo = XFile.fromData(
      Uint8List.fromList([1, 2, 3]),
      name: 'sample.jpg',
      mimeType: 'image/jpeg',
    );
    final source = await PhotoService.save(
      photo,
      path: 'maintenance/preview-visitor/request-1',
    );
    expect(source, startsWith('data:image/jpeg;base64,'));
    expect(PhotoService.provider(source), isNotNull);

    await store.addRequest(
      MaintenanceRequest(
        id: 'request-1',
        graveId: 'pedro-dela-cruz',
        issue: 'Damaged Tombstone',
        description: 'Broken left side',
        requestedBy: 'preview-visitor',
        createdAt: DateTime(2026, 10, 4),
        photoUrl: source,
      ),
    );
    await store.initialize();
    expect(store.requests.single.photoUrl, source);
  });

  test(
    'large PNG tomb photo is compressed before preview persistence',
    () async {
      SharedPreferences.setMockInitialValues({});
      final source = await PhotoService.save(
        XFile('assets/images/grave_sample.png'),
        path: 'maintenance/preview-visitor/large-photo',
      );
      expect(source, startsWith('data:image/jpeg;base64,'));
      expect(source.length, lessThan(700000));
      expect(PhotoService.provider(source), isNotNull);
    },
  );

  test('preview profile photo survives reload', () async {
    SharedPreferences.setMockInitialValues({});
    await ProfilePhotoService.save(
      'preview-visitor',
      XFile('assets/images/grave_sample.png'),
    );
    final saved = ProfilePhotoService.source.value;
    expect(saved, startsWith('data:image/jpeg;base64,'));
    await ProfilePhotoService.load('preview-visitor');
    expect(ProfilePhotoService.source.value, saved);
  });
}
