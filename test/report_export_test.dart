import 'package:capstone_project/data/cemetery_store.dart';
import 'package:capstone_project/models/cemetery_models.dart';
import 'package:capstone_project/services/report_export.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'burial export includes occupied records and excludes open plots',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = CemeteryStore.instance;
      await store.initialize();
      final csv = buildReportCsv(OperationsReport.burials, store);
      expect(csv, contains('Pedro Dela Cruz'));
      expect(csv, isNot(contains('plot-0-0')));
      expect(csv.trim().split('\r\n'), hasLength(2));
    },
  );

  test('payment export escapes quoted text and spreadsheet formulas', () async {
    SharedPreferences.setMockInitialValues({});
    final store = CemeteryStore.instance;
    await store.initialize();
    await store.savePayment(
      PaymentRecord(
        id: 'csv-payment',
        payer: '=1+1,"quoted"',
        graveId: 'pedro-dela-cruz',
        type: 'Annual Fee',
        amount: 123.45,
        date: DateTime(2026, 10, 4),
      ),
    );

    final csv = buildReportCsv(OperationsReport.payments, store);
    expect(csv, contains("'=1+1"));
    expect(csv, contains('""quoted""'));
    expect(csv, contains('"123.45"'));
  });
}
