import 'dart:convert';

import 'package:capstone_project/data/cemetery_store.dart';
import 'package:capstone_project/models/cemetery_models.dart';
import 'package:capstone_project/services/backup_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'encrypted backup restores preview records and rejects a wrong passphrase',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = CemeteryStore.instance;
      await store.initialize();
      await store.saveGrave(
        const Grave(
          id: 'backed-up-grave',
          name: 'Backup Test Memorial',
          block: '8',
          lot: '12',
          number: '2',
          mapRow: 0,
          mapColumn: 0,
          photos: ['https://example.com/memorial.jpg'],
        ),
      );
      final original = store.exportPreviewSnapshot();
      final file = await BackupService.encrypt(
        original,
        'A long backup phrase 2026',
      );
      expect(utf8.decode(file), isNot(contains('Backup Test Memorial')));

      await expectLater(
        BackupService.decrypt(file, 'incorrect passphrase'),
        throwsStateError,
      );
      final restored = await BackupService.decrypt(
        file,
        'A long backup phrase 2026',
      );
      expect(
        store.previewSnapshotCounts(restored)['graves'],
        store.graves.length,
      );

      await store.saveGrave(
        const Grave(
          id: 'newer-record',
          name: 'Not in backup',
          block: '9',
          lot: '1',
          number: '1',
          mapRow: 0,
          mapColumn: 1,
        ),
      );
      await store.restorePreviewSnapshot(restored);
      expect(store.graveById('backed-up-grave')?.photos, [
        'https://example.com/memorial.jpg',
      ]);
      expect(store.graveById('newer-record'), isNull);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test('invalid backup data cannot replace preview records', () async {
    SharedPreferences.setMockInitialValues({});
    final store = CemeteryStore.instance;
    await store.initialize();
    final count = store.graves.length;
    await expectLater(
      store.restorePreviewSnapshot({'format': 'wrong', 'version': 1}),
      throwsFormatException,
    );
    expect(store.graves.length, count);
  });

  test(
    'restoring an empty payment and lease list stays empty on reload',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = CemeteryStore.instance;
      await store.initialize();
      final snapshot = store.exportPreviewSnapshot();
      final data = Map<String, dynamic>.from(snapshot['data'] as Map);
      data['payments'] = <Map<String, dynamic>>[];
      data['leases'] = <Map<String, dynamic>>[];

      await store.restorePreviewSnapshot({...snapshot, 'data': data});
      expect(store.payments, isEmpty);
      expect(store.leases, isEmpty);

      await store.initialize();
      expect(store.payments, isEmpty);
      expect(store.leases, isEmpty);
    },
  );
}
