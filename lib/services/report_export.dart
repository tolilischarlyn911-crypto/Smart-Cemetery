import '../data/cemetery_store.dart';

enum OperationsReport { burials, maintenance, payments }

String reportLabel(OperationsReport report) => switch (report) {
  OperationsReport.burials => 'burial records',
  OperationsReport.maintenance => 'maintenance requests',
  OperationsReport.payments => 'payments',
};

String reportFileName(OperationsReport report) => switch (report) {
  OperationsReport.burials => 'burial-records',
  OperationsReport.maintenance => 'maintenance-requests',
  OperationsReport.payments => 'payment-records',
};

String buildReportCsv(OperationsReport report, CemeteryStore store) {
  final rows = switch (report) {
    OperationsReport.burials => <List<String>>[
      [
        'Record ID',
        'Name',
        'Block',
        'Lot',
        'Grave',
        'Birth date',
        'Death date',
        'Burial date',
        'Latitude',
        'Longitude',
      ],
      for (final grave in store.graves.where(
        (item) => item.status == 'occupied',
      ))
        [
          grave.id,
          grave.name,
          grave.block,
          grave.lot,
          grave.number,
          _date(grave.born),
          _date(grave.died),
          _date(grave.buriedAt),
          grave.latitude?.toString() ?? '',
          grave.longitude?.toString() ?? '',
        ],
    ],
    OperationsReport.maintenance => <List<String>>[
      [
        'Request ID',
        'Created at',
        'Grave location',
        'Issue',
        'Description',
        'Priority',
        'Status',
        'Requested by ID',
      ],
      for (final request in store.requests)
        [
          request.id,
          request.createdAt.toIso8601String(),
          store.graveById(request.graveId)?.location ?? request.graveId,
          request.issue,
          request.description,
          request.priority,
          request.status,
          request.requestedBy,
        ],
    ],
    OperationsReport.payments => <List<String>>[
      [
        'Payment ID',
        'Recorded at',
        'Payer',
        'Grave location',
        'Type',
        'Amount PHP',
        'Due date',
        'Status',
        'Linked account ID',
      ],
      for (final payment in store.payments)
        [
          payment.id,
          payment.date.toIso8601String(),
          payment.payer,
          store.graveById(payment.graveId)?.location ?? payment.graveId,
          payment.type,
          payment.amount.toStringAsFixed(2),
          _date(payment.dueDate),
          payment.status,
          payment.ownerId ?? '',
        ],
    ],
  };
  return '${rows.map((row) => row.map(_csvCell).join(',')).join('\r\n')}\r\n';
}

String _date(DateTime? value) => value == null
    ? ''
    : '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

String _csvCell(String value) {
  // Spreadsheet programs can interpret cells beginning with these characters
  // as formulas. Keep user-entered names and descriptions as plain text.
  final unsafe = RegExp(r'^[\s]*[=+\-@]');
  final text = unsafe.hasMatch(value) ? "'$value" : value;
  return '"${text.replaceAll('"', '""')}"';
}
