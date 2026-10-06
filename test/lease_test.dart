import 'package:capstone_project/data/cemetery_store.dart';
import 'package:capstone_project/models/cemetery_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('lease dates, status, and backup round trip', () async {
    SharedPreferences.setMockInitialValues({});
    final store = CemeteryStore.instance;
    await store.initialize();
    final lease = LeaseRecord(
      id: 'lease-test',
      graveId: 'pedro-dela-cruz',
      lessee: 'Lease Visitor',
      startsAt: DateTime(2026, 1, 1),
      endsAt: DateTime(2026, 9, 30),
    );
    await store.saveLease(lease);
    expect(lease.effectiveStatus(DateTime(2026, 10, 4)), 'Expired');
    final snapshot = store.exportPreviewSnapshot();
    expect(
      store.previewSnapshotCounts(snapshot)['leases'],
      store.leases.length,
    );

    await store.initialize();
    expect(store.leases.any((item) => item.id == 'lease-test'), isTrue);
    await store.restorePreviewSnapshot(snapshot);
    expect(
      store.leases.firstWhere((item) => item.id == 'lease-test').lessee,
      'Lease Visitor',
    );
  });

  test('rejects a lease with an invalid date range', () async {
    SharedPreferences.setMockInitialValues({});
    final store = CemeteryStore.instance;
    await store.initialize();
    await expectLater(
      store.saveLease(
        LeaseRecord(
          id: 'invalid',
          graveId: 'pedro-dela-cruz',
          lessee: 'Visitor',
          startsAt: DateTime(2026, 11, 1),
          endsAt: DateTime(2026, 10, 1),
        ),
      ),
      throwsArgumentError,
    );
  });

  test('dashboard counts expired occupied plots until renewed', () async {
    SharedPreferences.setMockInitialValues({});
    final store = CemeteryStore.instance;
    await store.initialize();
    await store.saveLease(
      LeaseRecord(
        id: 'preview-lease',
        graveId: 'pedro-dela-cruz',
        lessee: 'Preview Visitor',
        startsAt: DateTime(2026, 1, 1),
        endsAt: DateTime(2026, 9, 30),
      ),
    );
    final asOf = DateTime(2026, 10, 4);
    expect(store.expiredOccupiedCountAt(asOf), 1);
    expect(store.occupiedCount, 1);

    await store.saveLease(
      LeaseRecord(
        id: 'renewal',
        graveId: 'pedro-dela-cruz',
        lessee: 'Preview Visitor',
        startsAt: DateTime(2026, 11, 1),
        endsAt: DateTime(2027, 10, 31),
      ),
    );
    expect(
      store.leases
          .firstWhere((item) => item.id == 'renewal')
          .effectiveStatus(asOf),
      'Upcoming',
    );
    expect(store.expiredOccupiedCountAt(asOf), 1);
    expect(store.expiredOccupiedCountAt(DateTime(2026, 11, 2)), 0);
  });
}
