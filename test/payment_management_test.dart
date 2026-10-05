import 'package:capstone_project/data/cemetery_store.dart';
import 'package:capstone_project/models/cemetery_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('payment corrections keep one record and survive reload', () async {
    SharedPreferences.setMockInitialValues({});
    final store = CemeteryStore.instance;
    await store.initialize();
    final original = store.payments.firstWhere(
      (payment) => payment.id == 'preview-annual-fee',
    );
    final corrected = PaymentRecord(
      id: original.id,
      payer: original.payer,
      graveId: original.graveId,
      type: original.type,
      amount: 1750,
      date: original.date,
      dueDate: DateTime(2026, 12, 15),
      ownerId: original.ownerId,
      status: 'Pending',
    );
    await store.savePayment(corrected);
    await store.initialize();

    final matches = store.payments.where(
      (payment) => payment.id == original.id,
    );
    expect(matches, hasLength(1));
    expect(matches.single.amount, 1750);
    expect(matches.single.dueDate, DateTime(2026, 12, 15));
    expect(matches.single.ownerId, 'preview-visitor');
  });

  test('invalid payment amounts are rejected', () async {
    SharedPreferences.setMockInitialValues({});
    final store = CemeteryStore.instance;
    await store.initialize();
    await expectLater(
      store.savePayment(
        PaymentRecord(
          id: 'invalid-payment',
          payer: 'Visitor',
          graveId: 'pedro-dela-cruz',
          type: 'Annual Fee',
          amount: double.nan,
          date: DateTime(2026, 10, 4),
        ),
      ),
      throwsArgumentError,
    );
  });
}
