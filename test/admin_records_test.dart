import 'dart:typed_data';

import 'package:capstone_project/data/cemetery_store.dart';
import 'package:capstone_project/models/cemetery_models.dart';
import 'package:capstone_project/services/payment_document_service.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'maintenance assignment uses a registered account and persists',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = CemeteryStore.instance;
      await store.initialize();
      final request = MaintenanceRequest(
        id: 'assignment-test',
        graveId: store.graves.first.id,
        issue: 'Damaged tombstone',
        description: 'Needs repair',
        requestedBy: 'preview-visitor',
        createdAt: DateTime(2026, 10, 5),
      );
      await store.addRequest(request);
      await store.assignRequest(request.id, 'preview-visitor');
      expect(
        store.requests.firstWhere((item) => item.id == request.id).assignedTo,
        'preview-visitor',
      );
      await store.initialize();
      expect(
        store.requests.firstWhere((item) => item.id == request.id).assignedTo,
        'preview-visitor',
      );
      await store.assignRequest(request.id, null);
      expect(
        store.requests.firstWhere((item) => item.id == request.id).assignedTo,
        isNull,
      );
      await expectLater(
        store.assignRequest(request.id, 'missing-user'),
        throwsArgumentError,
      );
    },
  );

  test(
    'supporting payment file survives record serialization in preview',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = CemeteryStore.instance;
      await store.initialize();
      final bytes = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
      final attachment = await PaymentDocumentService.save(
        XFile.fromData(
          bytes,
          path: 'receipt.png',
          name: 'receipt.png',
          mimeType: 'image/png',
        ),
        paymentId: 'attachment-test',
      );
      expect(await PaymentDocumentService.read(attachment), bytes);
      final record = PaymentRecord(
        id: 'attachment-test',
        payer: 'Test Visitor',
        graveId: store.graves.first.id,
        type: 'Annual Fee',
        amount: 100,
        date: DateTime(2026, 10, 5),
        attachments: [attachment],
      );
      await store.savePayment(record);
      await store.initialize();
      final saved = store.payments.firstWhere((item) => item.id == record.id);
      expect(saved.attachments.single.name, 'receipt.png');
      expect(
        await PaymentDocumentService.read(saved.attachments.single),
        bytes,
      );
    },
  );
}
