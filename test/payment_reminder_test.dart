import 'package:capstone_project/models/cemetery_models.dart';
import 'package:capstone_project/services/payment_reminder_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  PaymentRecord payment({
    required String id,
    required String owner,
    required String status,
    required DateTime? due,
  }) => PaymentRecord(
    id: id,
    payer: 'Visitor',
    graveId: 'grave-1',
    type: 'Annual Fee',
    amount: 1500,
    date: DateTime(2026, 10, 1),
    ownerId: owner,
    status: status,
    dueDate: due,
  );

  test('plans only future alerts for this visitor and unpaid payments', () {
    final now = DateTime(2026, 10, 4, 8);
    final alerts = PaymentReminderService.planAlerts('visitor-1', [
      payment(
        id: 'next',
        owner: 'visitor-1',
        status: 'Pending',
        due: DateTime(2026, 10, 18),
      ),
      payment(
        id: 'soon',
        owner: 'visitor-1',
        status: 'Pending',
        due: DateTime(2026, 10, 7),
      ),
      payment(
        id: 'paid',
        owner: 'visitor-1',
        status: 'Paid',
        due: DateTime(2026, 10, 18),
      ),
      payment(
        id: 'other',
        owner: 'visitor-2',
        status: 'Pending',
        due: DateTime(2026, 10, 18),
      ),
      payment(id: 'no-date', owner: 'visitor-1', status: 'Pending', due: null),
    ], now);

    expect(alerts.length, 3);
    expect(alerts.map((a) => a.payment.id), ['soon', 'next', 'next']);
    expect(alerts.map((a) => a.at), [
      DateTime(2026, 10, 7, 9),
      DateTime(2026, 10, 11, 9),
      DateTime(2026, 10, 18, 9),
    ]);
    expect(alerts.map((a) => a.id).toSet().length, 3);
  });

  test('caps pending alerts at sixty nearest occurrences', () {
    final now = DateTime(2026, 10, 4);
    final payments = List.generate(
      40,
      (index) => payment(
        id: '$index',
        owner: 'visitor-1',
        status: 'Pending',
        due: now.add(Duration(days: index + 10)),
      ),
    );
    final alerts = PaymentReminderService.planAlerts(
      'visitor-1',
      payments,
      now,
    );
    expect(alerts.length, 60);
    expect(alerts.first.at, DateTime(2026, 10, 7, 9));
    expect(alerts.last.at.isBefore(DateTime(2026, 11, 13)), isTrue);
  });
}
