import 'package:capstone_project/data/cemetery_store.dart';
import 'package:capstone_project/models/cemetery_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'dashboard activity uses record dates even when writes arrive out of order',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = CemeteryStore.instance;
      await store.initialize();
      store.payments.clear();
      final graveId = store.graves.first.id;

      for (final day in [5, 1, 4, 2, 3]) {
        await store.addRequest(
          MaintenanceRequest(
            id: 'request-$day',
            graveId: graveId,
            issue: 'Issue $day',
            description: '',
            requestedBy: 'preview-visitor',
            createdAt: DateTime(2026, 9, day),
          ),
        );
        await store.savePayment(
          PaymentRecord(
            id: 'payment-$day',
            payer: 'Visitor $day',
            graveId: graveId,
            type: 'Annual Fee',
            amount: 100,
            date: DateTime(2026, 9, day),
          ),
        );
      }

      expect(store.requests.first.id, 'request-3');
      expect(store.payments.first.id, 'payment-3');
      expect(store.recentRequests.take(4).map((item) => item.id), [
        'request-5',
        'request-4',
        'request-3',
        'request-2',
      ]);
      expect(store.recentPayments.take(4).map((item) => item.id), [
        'payment-5',
        'payment-4',
        'payment-3',
        'payment-2',
      ]);
    },
  );
}
