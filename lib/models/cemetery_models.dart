import 'plot_identity.dart';

class Grave {
  final String id;
  final String name;
  final String block;
  final String lot;
  final String number;
  final DateTime? born;
  final DateTime? died;
  final DateTime? buriedAt;
  final String birthplace;
  final String deathplace;
  final String message;
  final List<String> photos;
  final String? portraitPhotoUrl;
  final String? tombPhotoUrl;
  final String status;
  final int mapRow;
  final int mapColumn;
  final double? latitude;
  final double? longitude;

  const Grave({
    required this.id,
    required this.name,
    required this.block,
    required this.lot,
    required this.number,
    this.born,
    this.died,
    this.buriedAt,
    this.birthplace = '',
    this.deathplace = '',
    this.message = '',
    this.photos = const [],
    this.portraitPhotoUrl,
    this.tombPhotoUrl,
    this.status = 'occupied',
    required this.mapRow,
    required this.mapColumn,
    this.latitude,
    this.longitude,
  });

  String get location => 'Block $block · Lot $lot · Grave $number';
  String get qrValue => 'smart-cemetery:grave:$id';
  bool get hasValidCoordinates =>
      latitude != null &&
      longitude != null &&
      latitude!.isFinite &&
      longitude!.isFinite &&
      latitude! >= -90 &&
      latitude! <= 90 &&
      longitude! >= -180 &&
      longitude! <= 180;

  static String? idFromQr(String value) {
    const prefix = 'smart-cemetery:grave:';
    if (!value.startsWith(prefix)) return null;
    final id = value.substring(prefix.length);
    return id.isEmpty ? null : id;
  }

  factory Grave.fromJson(Map<String, dynamic> json) => Grave(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    block: json['block'] as String? ?? '',
    lot: json['lot'] as String? ?? '',
    number: json['number'] as String? ?? '',
    born: DateTime.tryParse(json['born'] as String? ?? ''),
    died: DateTime.tryParse(json['died'] as String? ?? ''),
    buriedAt: DateTime.tryParse(json['buriedAt'] as String? ?? ''),
    birthplace: json['birthplace'] as String? ?? '',
    deathplace: json['deathplace'] as String? ?? '',
    message: json['message'] as String? ?? '',
    photos: List<String>.from(json['photos'] as List? ?? const []),
    portraitPhotoUrl: json['portraitPhotoUrl'] as String?,
    tombPhotoUrl: json['tombPhotoUrl'] as String?,
    status: json['status'] as String? ?? 'available',
    mapRow: (json['mapRow'] as num?)?.toInt() ?? 0,
    mapColumn: (json['mapColumn'] as num?)?.toInt() ?? 0,
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
  );

  Grave copyWithLocation(double latitude, double longitude) => Grave(
    id: id,
    name: name,
    block: block,
    lot: lot,
    number: number,
    born: born,
    died: died,
    buriedAt: buriedAt,
    birthplace: birthplace,
    deathplace: deathplace,
    message: message,
    photos: photos,
    portraitPhotoUrl: portraitPhotoUrl,
    tombPhotoUrl: tombPhotoUrl,
    status: status,
    mapRow: mapRow,
    mapColumn: mapColumn,
    latitude: latitude,
    longitude: longitude,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'locationKey': plotIdentityKey(block, lot, number),
    'name': name,
    'block': block,
    'lot': lot,
    'number': number,
    'born': born?.toIso8601String(),
    'died': died?.toIso8601String(),
    'buriedAt': buriedAt?.toIso8601String(),
    'birthplace': birthplace,
    'deathplace': deathplace,
    'message': message,
    'photos': photos,
    'portraitPhotoUrl': portraitPhotoUrl,
    'tombPhotoUrl': tombPhotoUrl,
    'status': status,
    'mapRow': mapRow,
    'mapColumn': mapColumn,
    'latitude': latitude,
    'longitude': longitude,
  };
}

class MaintenanceRequest {
  final String id;
  final String graveId;
  final String issue;
  final String description;
  final String requestedBy;
  final DateTime createdAt;
  final String status;
  final String priority;
  final String? photoUrl;
  final String? assignedTo;
  final String? assigneeName;

  const MaintenanceRequest({
    required this.id,
    required this.graveId,
    required this.issue,
    required this.description,
    required this.requestedBy,
    required this.createdAt,
    this.status = 'Pending',
    this.priority = 'Medium',
    this.photoUrl,
    this.assignedTo,
    this.assigneeName,
  });

  MaintenanceRequest copyWith({String? status, String? priority}) =>
      MaintenanceRequest(
        id: id,
        graveId: graveId,
        issue: issue,
        description: description,
        requestedBy: requestedBy,
        createdAt: createdAt,
        status: status ?? this.status,
        priority: priority ?? this.priority,
        photoUrl: photoUrl,
        assignedTo: assignedTo,
        assigneeName: assigneeName,
      );

  MaintenanceRequest withAssignee(String? userId, String? name) =>
      MaintenanceRequest(
        id: id,
        graveId: graveId,
        issue: issue,
        description: description,
        requestedBy: requestedBy,
        createdAt: createdAt,
        status: status,
        priority: priority,
        photoUrl: photoUrl,
        assignedTo: userId,
        assigneeName: name,
      );

  factory MaintenanceRequest.fromJson(Map<String, dynamic> json) =>
      MaintenanceRequest(
        id: json['id'] as String,
        graveId: json['graveId'] as String? ?? '',
        issue: json['issue'] as String? ?? '',
        description: json['description'] as String? ?? '',
        requestedBy: json['requestedBy'] as String? ?? '',
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        status: json['status'] as String? ?? 'Pending',
        priority: json['priority'] as String? ?? 'Medium',
        photoUrl: json['photoUrl'] as String?,
        assignedTo: json['assignedTo'] as String?,
        assigneeName: json['assigneeName'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'graveId': graveId,
    'issue': issue,
    'description': description,
    'requestedBy': requestedBy,
    'createdAt': createdAt.toIso8601String(),
    'status': status,
    'priority': priority,
    'photoUrl': photoUrl,
    'assignedTo': assignedTo,
    'assigneeName': assigneeName,
  };
}

class PaymentAttachment {
  final String name;
  final String mimeType;
  final String source;

  const PaymentAttachment({
    required this.name,
    required this.mimeType,
    required this.source,
  });

  factory PaymentAttachment.fromJson(Map<String, dynamic> json) =>
      PaymentAttachment(
        name: json['name'] as String? ?? 'Supporting file',
        mimeType: json['mimeType'] as String? ?? 'application/octet-stream',
        source: json['source'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
    'name': name,
    'mimeType': mimeType,
    'source': source,
  };
}

class PaymentRecord {
  final String id;
  final String payer;
  final String graveId;
  final String type;
  final double amount;
  final DateTime date;
  final String status;
  final String? ownerId;
  final DateTime? dueDate;
  final List<PaymentAttachment> attachments;

  const PaymentRecord({
    required this.id,
    required this.payer,
    required this.graveId,
    required this.type,
    required this.amount,
    required this.date,
    this.status = 'Pending',
    this.ownerId,
    this.dueDate,
    this.attachments = const [],
  });

  PaymentRecord copyWith({String? status}) => PaymentRecord(
    id: id,
    payer: payer,
    graveId: graveId,
    type: type,
    amount: amount,
    date: date,
    status: status ?? this.status,
    ownerId: ownerId,
    dueDate: dueDate,
    attachments: attachments,
  );

  factory PaymentRecord.fromJson(Map<String, dynamic> json) => PaymentRecord(
    id: json['id'] as String,
    payer: json['payer'] as String? ?? '',
    graveId: json['graveId'] as String? ?? '',
    type: json['type'] as String? ?? '',
    amount: (json['amount'] as num?)?.toDouble() ?? 0,
    date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
    status: json['status'] as String? ?? 'Pending',
    ownerId: json['ownerId'] as String?,
    dueDate: DateTime.tryParse(json['dueDate'] as String? ?? ''),
    attachments: (json['attachments'] as List? ?? const [])
        .map(
          (entry) => PaymentAttachment.fromJson(
            Map<String, dynamic>.from(entry as Map),
          ),
        )
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'payer': payer,
    'graveId': graveId,
    'type': type,
    'amount': amount,
    'date': date.toIso8601String(),
    'status': status,
    'ownerId': ownerId,
    'dueDate': dueDate?.toIso8601String(),
    'attachments': attachments
        .map((attachment) => attachment.toJson())
        .toList(),
  };
}

class LeaseRecord {
  final String id;
  final String graveId;
  final String lessee;
  final String? ownerId;
  final DateTime startsAt;
  final DateTime endsAt;
  final String status;

  const LeaseRecord({
    required this.id,
    required this.graveId,
    required this.lessee,
    this.ownerId,
    required this.startsAt,
    required this.endsAt,
    this.status = 'Active',
  });

  String effectiveStatus(DateTime today) {
    if (status != 'Active') return status;
    final day = DateTime(today.year, today.month, today.day);
    if (startsAt.isAfter(day)) return 'Upcoming';
    if (endsAt.isBefore(day)) return 'Expired';
    return 'Active';
  }

  factory LeaseRecord.fromJson(Map<String, dynamic> json) => LeaseRecord(
    id: json['id'] as String,
    graveId: json['graveId'] as String,
    lessee: json['lessee'] as String,
    ownerId: json['ownerId'] as String?,
    startsAt: DateTime.parse(json['startsAt'] as String),
    endsAt: DateTime.parse(json['endsAt'] as String),
    status: json['status'] as String? ?? 'Active',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'graveId': graveId,
    'lessee': lessee,
    'ownerId': ownerId,
    'startsAt': startsAt.toIso8601String(),
    'endsAt': endsAt.toIso8601String(),
    'status': status,
  };
}
