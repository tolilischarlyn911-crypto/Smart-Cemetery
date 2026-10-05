import 'dart:convert';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/cemetery_models.dart';
import '../models/plot_identity.dart';

/// One source of data for both layouts. Without Firebase configuration this is
/// an explicitly labelled, persistent local preview. A configured app uses
/// Firestore listeners so changes appear on other devices immediately.
class CemeteryStore extends ChangeNotifier {
  CemeteryStore._();

  static final CemeteryStore instance = CemeteryStore._();

  final List<Grave> graves = [];
  final List<MaintenanceRequest> requests = [];
  final List<PaymentRecord> payments = [];
  final List<LeaseRecord> leases = [];
  final List<Map<String, dynamic>> announcements = [];
  final List<Map<String, dynamic>> visits = [];
  final List<Map<String, dynamic>> staff = [];
  final List<Map<String, dynamic>> users = [];
  final List<Map<String, dynamic>> feedback = [];
  final Map<String, dynamic> settings = {};
  final List<StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
  _subscriptions = [];
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _settingsSubscription;
  FirebaseFirestore? _db;
  int _listenerGeneration = 0;
  bool get isDemo => _db == null;

  Future<void> initialize({
    FirebaseFirestore? firestore,
    bool admin = false,
    bool staffAccess = false,
    String? visitorId,
  }) async {
    _listenerGeneration++;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    await _settingsSubscription?.cancel();
    _settingsSubscription = null;
    graves.clear();
    requests.clear();
    payments.clear();
    leases.clear();
    announcements.clear();
    visits.clear();
    staff.clear();
    users.clear();
    feedback.clear();
    settings.clear();
    _db = firestore;
    if (_db != null) {
      _watchCollection('graves', (docs) {
        graves
          ..clear()
          ..addAll(docs.map(Grave.fromJson));
      });
      _watchCollection('announcements', (docs) {
        announcements
          ..clear()
          ..addAll(docs);
      });
      if (admin) {
        _watchCollection('maintenance', (docs) {
          requests
            ..clear()
            ..addAll(docs.map(MaintenanceRequest.fromJson));
        });
        _watchCollection('payments', (docs) {
          payments
            ..clear()
            ..addAll(docs.map(PaymentRecord.fromJson));
        });
        _watchCollection('leases', (docs) {
          leases
            ..clear()
            ..addAll(docs.map(LeaseRecord.fromJson));
        });
        _watchCollection('visits', (docs) {
          visits
            ..clear()
            ..addAll(docs);
        });
        _watchCollection('staff', (docs) {
          staff
            ..clear()
            ..addAll(docs);
        });
        _watchCollection('users', (docs) {
          users
            ..clear()
            ..addAll(docs);
        });
        _watchCollection('feedback', (docs) {
          feedback
            ..clear()
            ..addAll(docs);
        });
      } else if (staffAccess) {
        _watchCollection('maintenance', (docs) {
          requests
            ..clear()
            ..addAll(docs.map(MaintenanceRequest.fromJson));
        });
      } else if (visitorId != null) {
        _watchQuery(
          _db!
              .collection('maintenance')
              .where('requestedBy', isEqualTo: visitorId),
          (docs) => requests
            ..clear()
            ..addAll(docs.map(MaintenanceRequest.fromJson)),
        );
        _watchQuery(
          _db!.collection('visits').where('visitorId', isEqualTo: visitorId),
          (docs) => visits
            ..clear()
            ..addAll(docs),
        );
        _watchQuery(
          _db!.collection('payments').where('ownerId', isEqualTo: visitorId),
          (docs) => payments
            ..clear()
            ..addAll(docs.map(PaymentRecord.fromJson)),
        );
      }
      final generation = _listenerGeneration;
      _settingsSubscription = _db!
          .collection('settings')
          .doc('general')
          .snapshots()
          .listen(
            (snapshot) {
              if (generation != _listenerGeneration) return;
              settings
                ..clear()
                ..addAll(snapshot.data() ?? {});
              notifyListeners();
            },
            onError: (Object error) =>
                debugPrint('Could not load settings: $error'),
          );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('smart_cemetery_preview_v1');
    var seededPreview = false;
    if (saved != null) {
      try {
        final data = jsonDecode(saved) as Map<String, dynamic>;
        graves.addAll(
          (data['graves'] as List).map((item) {
            final record = Map<String, dynamic>.from(item as Map);
            if (record['id'] == 'pedro-dela-cruz' &&
                record['name'] == 'Pedro Dela Cruz' &&
                record['tombPhotoUrl'] == 'assets/images/grave_sample.png' &&
                !record.containsKey('portraitPhotoUrl')) {
              record['portraitPhotoUrl'] = 'assets/images/portrait_sample.png';
            }
            return Grave.fromJson(record);
          }),
        );
        requests.addAll(
          (data['requests'] as List).map(
            (item) => MaintenanceRequest.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          ),
        );
        payments.addAll(
          (data['payments'] as List).map(
            (item) =>
                PaymentRecord.fromJson(Map<String, dynamic>.from(item as Map)),
          ),
        );
        leases.addAll(
          (data['leases'] as List? ?? const []).map(
            (item) =>
                LeaseRecord.fromJson(Map<String, dynamic>.from(item as Map)),
          ),
        );
        announcements.addAll(
          (data['announcements'] as List).map(
            (item) => Map<String, dynamic>.from(item as Map),
          ),
        );
        visits.addAll(
          (data['visits'] as List).map(
            (item) => Map<String, dynamic>.from(item as Map),
          ),
        );
        staff.addAll(
          (data['staff'] as List? ?? const []).map(
            (item) => Map<String, dynamic>.from(item as Map),
          ),
        );
        users.addAll(
          (data['users'] as List? ?? const []).map(
            (item) => Map<String, dynamic>.from(item as Map),
          ),
        );
        feedback.addAll(
          (data['feedback'] as List? ?? const []).map(
            (item) => Map<String, dynamic>.from(item as Map),
          ),
        );
        settings.addAll(
          Map<String, dynamic>.from(data['settings'] as Map? ?? const {}),
        );
      } catch (_) {
        _seedPreview();
        seededPreview = true;
        await _persist();
      }
    } else {
      _seedPreview();
      seededPreview = true;
      await _persist();
    }
    if (users.isEmpty) {
      users.addAll([
        {
          'id': 'preview-admin',
          'name': 'Admin User',
          'email': 'admin@example.com',
          'role': 'admin',
        },
        {
          'id': 'preview-visitor',
          'name': 'Visitor User',
          'email': 'visitor@example.com',
          'role': 'visitor',
        },
      ]);
    }
    if (seededPreview && payments.isEmpty) {
      payments.add(
        PaymentRecord(
          id: 'preview-annual-fee',
          payer: 'Preview Visitor',
          graveId: 'pedro-dela-cruz',
          type: 'Annual Fee',
          amount: 1500,
          date: DateTime.now(),
          dueDate: DateTime.now().add(const Duration(days: 14)),
          ownerId: 'preview-visitor',
        ),
      );
    }
    if (seededPreview && leases.isEmpty && isDemo) {
      leases.add(
        LeaseRecord(
          id: 'preview-lease',
          graveId: 'pedro-dela-cruz',
          lessee: 'Preview Visitor',
          ownerId: 'preview-visitor',
          startsAt: DateTime.now().subtract(const Duration(days: 30)),
          endsAt: DateTime.now().add(const Duration(days: 335)),
        ),
      );
    }
    await _persist();
    notifyListeners();
  }

  /// Stops account-scoped listeners and removes their records from memory.
  Future<void> disconnect() async {
    _listenerGeneration++;
    final subscriptions = [..._subscriptions];
    _subscriptions.clear();
    final settingsSubscription = _settingsSubscription;
    _settingsSubscription = null;
    _db = null;
    graves.clear();
    requests.clear();
    payments.clear();
    leases.clear();
    announcements.clear();
    visits.clear();
    staff.clear();
    users.clear();
    feedback.clear();
    settings.clear();
    notifyListeners();
    await Future.wait(
      subscriptions.map((subscription) => subscription.cancel()),
    );
    await settingsSubscription?.cancel();
  }

  void _watchCollection(
    String name,
    void Function(List<Map<String, dynamic>>) assign,
  ) {
    _watchQuery(_db!.collection(name), assign);
  }

  void _watchQuery(
    Query<Map<String, dynamic>> query,
    void Function(List<Map<String, dynamic>>) assign,
  ) {
    final generation = _listenerGeneration;
    _subscriptions.add(
      query.snapshots().listen(
        (snapshot) {
          if (generation != _listenerGeneration) return;
          assign(
            snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList(),
          );
          notifyListeners();
        },
        onError: (Object error) {
          debugPrint('Could not load collection: $error');
        },
      ),
    );
  }

  Grave? graveById(String id) {
    for (final grave in graves) {
      if (grave.id == id) return grave;
    }
    return null;
  }

  List<Grave> search(String query) {
    final term = query.trim().toLowerCase();
    return graves.where((grave) {
      return grave.status == 'occupied' &&
          (term.isEmpty ||
              grave.name.toLowerCase().contains(term) ||
              grave.location.toLowerCase().contains(term));
    }).toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  int get occupiedCount => graves.where((g) => g.status == 'occupied').length;
  int get availableCount => graves.where((g) => g.status == 'available').length;
  int get reservedCount => graves.where((g) => g.status == 'reserved').length;
  int get pendingCount => requests.where((r) => r.status == 'Pending').length;

  ({double latitude, double longitude})? get mapCenter {
    final latitude = double.tryParse('${settings['mapCenterLatitude'] ?? ''}');
    final longitude = double.tryParse(
      '${settings['mapCenterLongitude'] ?? ''}',
    );
    if (latitude == null ||
        longitude == null ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }
    return (latitude: latitude, longitude: longitude);
  }

  List<MaintenanceRequest> get recentRequests =>
      [...requests]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<PaymentRecord> get recentPayments =>
      [...payments]..sort((a, b) => b.date.compareTo(a.date));

  List<Map<String, dynamic>> get recentAnnouncements =>
      [...announcements]..sort((a, b) => _compareDateDesc(a, b, 'date'));

  List<Map<String, dynamic>> visitsForVisitor(String visitorId) {
    final result = visits
        .where((visit) => visit['visitorId'] == visitorId)
        .toList();
    result.sort((a, b) => _compareDateDesc(a, b, 'date'));
    return result;
  }

  static int _compareDateDesc(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
    String field,
  ) {
    final first = DateTime.tryParse('${a[field] ?? ''}');
    final second = DateTime.tryParse('${b[field] ?? ''}');
    if (first == null) return second == null ? 0 : 1;
    if (second == null) return -1;
    return second.compareTo(first);
  }

  Set<String> expiredLeaseGraveIdsAt(DateTime asOf) {
    final latest = <String, LeaseRecord>{};
    for (final lease in leases) {
      if (lease.startsAt.isAfter(asOf)) continue;
      final previous = latest[lease.graveId];
      if (previous == null ||
          lease.startsAt.isAfter(previous.startsAt) ||
          (lease.startsAt.isAtSameMomentAs(previous.startsAt) &&
              lease.endsAt.isAfter(previous.endsAt))) {
        latest[lease.graveId] = lease;
      }
    }
    return {
      for (final entry in latest.entries)
        if (entry.value.effectiveStatus(asOf) == 'Expired') entry.key,
    };
  }

  int expiredOccupiedCountAt(DateTime asOf) {
    final expiredIds = expiredLeaseGraveIdsAt(asOf);
    return graves
        .where(
          (grave) =>
              grave.status == 'occupied' && expiredIds.contains(grave.id),
        )
        .length;
  }

  Map<String, dynamic> exportPreviewSnapshot() {
    if (!isDemo) throw StateError('Use a server-side backup for cloud data.');
    return {
      'format': 'smart-cemetery-preview-data',
      'version': 1,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'data': _previewData(),
    };
  }

  Map<String, int> previewSnapshotCounts(Map<String, dynamic> snapshot) {
    final data = _validatePreviewSnapshot(snapshot);
    return {
      'graves': (data['graves'] as List).length,
      'requests': (data['requests'] as List).length,
      'payments': (data['payments'] as List).length,
      'leases': (data['leases'] as List? ?? const []).length,
      'announcements': (data['announcements'] as List).length,
      'visits': (data['visits'] as List).length,
      'staff': (data['staff'] as List).length,
      'users': (data['users'] as List).length,
      'feedback': (data['feedback'] as List).length,
    };
  }

  Future<void> restorePreviewSnapshot(Map<String, dynamic> snapshot) async {
    if (!isDemo) throw StateError('Cloud data cannot be restored here.');
    final data = _validatePreviewSnapshot(snapshot);
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString('smart_cemetery_preview_v1', jsonEncode(data))) {
      throw StateError('Could not save the restored preview data.');
    }
    await initialize();
  }

  Map<String, dynamic> _validatePreviewSnapshot(Map<String, dynamic> snapshot) {
    if (snapshot['format'] != 'smart-cemetery-preview-data' ||
        snapshot['version'] != 1 ||
        snapshot['data'] is! Map) {
      throw const FormatException('Unsupported Smart Cemetery backup data.');
    }
    try {
      final data = Map<String, dynamic>.from(snapshot['data'] as Map);
      List<Map<String, dynamic>> records(String key) =>
          (data[key] as List).map((item) {
            final record = Map<String, dynamic>.from(item as Map);
            if (record['id'] is! String || (record['id'] as String).isEmpty) {
              throw FormatException('Invalid $key record.');
            }
            return record;
          }).toList();
      final graveRecords = records('graves');
      final requestRecords = records('requests');
      final paymentRecords = records('payments');
      final leaseRecords = (data['leases'] as List? ?? const []).map((item) {
        final record = Map<String, dynamic>.from(item as Map);
        if (record['id'] is! String || (record['id'] as String).isEmpty) {
          throw const FormatException('Invalid lease record.');
        }
        return record;
      }).toList();
      graveRecords.map(Grave.fromJson).toList();
      requestRecords.map(MaintenanceRequest.fromJson).toList();
      paymentRecords.map(PaymentRecord.fromJson).toList();
      leaseRecords.map(LeaseRecord.fromJson).toList();
      for (final key in [
        'announcements',
        'visits',
        'staff',
        'users',
        'feedback',
      ]) {
        records(key);
      }
      Map<String, dynamic>.from(data['settings'] as Map);
      return data;
    } catch (_) {
      throw const FormatException('Backup data is incomplete or invalid.');
    }
  }

  Future<void> saveGrave(Grave grave) async {
    final duplicate = graveAtLocation(
      block: grave.block,
      lot: grave.lot,
      number: grave.number,
      exceptId: grave.id,
    );
    if (duplicate != null) {
      throw StateError(
        'Block ${grave.block.trim()}, Lot ${grave.lot.trim()}, Grave ${grave.number.trim()} already has a record.',
      );
    }
    if ((grave.latitude != null || grave.longitude != null) &&
        !grave.hasValidCoordinates) {
      throw ArgumentError(
        'Enter a valid latitude and longitude together for this grave.',
      );
    }
    if (_db != null) {
      final db = _db!;
      final locationKey = plotIdentityKey(grave.block, grave.lot, grave.number);
      // Check records imported before the location index was introduced.
      final records = await db.collection('graves').get();
      for (final record in records.docs) {
        if (record.id == grave.id) continue;
        final data = record.data();
        final block = data['block'];
        final lot = data['lot'];
        final number = data['number'];
        if (block is String &&
            lot is String &&
            number is String &&
            normalizedPlotPart(block) == normalizedPlotPart(grave.block) &&
            normalizedPlotPart(lot) == normalizedPlotPart(grave.lot) &&
            normalizedPlotPart(number) == normalizedPlotPart(grave.number)) {
          throw StateError(
            'Block ${grave.block.trim()}, Lot ${grave.lot.trim()}, Grave ${grave.number.trim()} already has a record.',
          );
        }
      }
      final graveRef = db.collection('graves').doc(grave.id);
      final claimRef = db.collection('graveLocations').doc(locationKey);
      await db.runTransaction((transaction) async {
        final previous = await transaction.get(graveRef);
        final claim = await transaction.get(claimRef);
        final previousData = previous.data();
        String? previousKey;
        if (previousData != null &&
            previousData['block'] is String &&
            previousData['lot'] is String &&
            previousData['number'] is String) {
          previousKey = plotIdentityKey(
            previousData['block'] as String,
            previousData['lot'] as String,
            previousData['number'] as String,
          );
        }
        final previousClaimRef =
            previousKey != null && previousKey != locationKey
            ? db.collection('graveLocations').doc(previousKey)
            : null;
        final previousClaim = previousClaimRef == null
            ? null
            : await transaction.get(previousClaimRef);
        if (claim.exists && claim.data()?['graveId'] != grave.id) {
          throw StateError('This plot was claimed by another grave record.');
        }
        transaction.set(claimRef, {'graveId': grave.id});
        transaction.set(graveRef, grave.toJson());
        if (previousClaimRef != null &&
            previousClaim?.data()?['graveId'] == grave.id) {
          transaction.delete(previousClaimRef);
        }
      });
      return;
    }
    final index = graves.indexWhere((g) => g.id == grave.id);
    if (index < 0) {
      graves.add(grave);
    } else {
      graves[index] = grave;
    }
    notifyListeners();
    await _save('graves', grave.id, grave.toJson());
  }

  Grave? graveAtLocation({
    required String block,
    required String lot,
    required String number,
    String? exceptId,
  }) {
    final normalizedBlock = normalizedPlotPart(block);
    final normalizedLot = normalizedPlotPart(lot);
    final normalizedNumber = normalizedPlotPart(number);
    if (normalizedBlock.isEmpty ||
        normalizedLot.isEmpty ||
        normalizedNumber.isEmpty) {
      return null;
    }
    for (final existing in graves) {
      if (existing.id == exceptId) continue;
      if (normalizedPlotPart(existing.block) == normalizedBlock &&
          normalizedPlotPart(existing.lot) == normalizedLot &&
          normalizedPlotPart(existing.number) == normalizedNumber) {
        return existing;
      }
    }
    return null;
  }

  Future<void> addRequest(MaintenanceRequest request) async {
    if (_db != null) {
      await _save('maintenance', request.id, request.toJson());
      return;
    }
    requests.insert(0, request);
    notifyListeners();
    await _save('maintenance', request.id, request.toJson());
  }

  Future<void> updateRequest(String id, String status, String priority) async {
    final index = requests.indexWhere((r) => r.id == id);
    if (index < 0) return;
    final updated = requests[index].copyWith(
      status: status,
      priority: priority,
    );
    if (_db != null) {
      await _save('maintenance', id, updated.toJson());
      return;
    }
    requests[index] = updated;
    notifyListeners();
    await _save('maintenance', id, requests[index].toJson());
  }

  Future<void> savePayment(PaymentRecord payment) async {
    if (!graves.any((grave) => grave.id == payment.graveId)) {
      throw ArgumentError('Choose an existing grave or plot.');
    }
    if (!payment.amount.isFinite || payment.amount <= 0) {
      throw ArgumentError('Enter a positive payment amount.');
    }
    if (_db != null) {
      await _save('payments', payment.id, payment.toJson());
      return;
    }
    final index = payments.indexWhere((p) => p.id == payment.id);
    if (index < 0) {
      payments.insert(0, payment);
    } else {
      payments[index] = payment;
    }
    notifyListeners();
    await _save('payments', payment.id, payment.toJson());
  }

  Future<void> saveLease(LeaseRecord lease) async {
    if (!graves.any((grave) => grave.id == lease.graveId)) {
      throw ArgumentError('Choose an existing grave or plot.');
    }
    if (lease.endsAt.isBefore(lease.startsAt)) {
      throw ArgumentError('The lease end date must follow its start date.');
    }
    if (_db != null) {
      await _save('leases', lease.id, lease.toJson());
      return;
    }
    final index = leases.indexWhere((item) => item.id == lease.id);
    if (index < 0) {
      leases.insert(0, lease);
    } else {
      leases[index] = lease;
    }
    notifyListeners();
    await _save('leases', lease.id, lease.toJson());
  }

  Future<void> saveAnnouncement(Map<String, dynamic> announcement) async {
    if (_db != null) {
      await _save('announcements', announcement['id'] as String, announcement);
      return;
    }
    final index = announcements.indexWhere(
      (a) => a['id'] == announcement['id'],
    );
    if (index < 0) {
      announcements.insert(0, announcement);
    } else {
      announcements[index] = announcement;
    }
    notifyListeners();
    await _save('announcements', announcement['id'] as String, announcement);
  }

  Future<void> deleteAnnouncement(String id) async {
    if (_db != null) {
      await _db!.collection('announcements').doc(id).delete();
      return;
    }
    announcements.removeWhere((item) => item['id'] == id);
    notifyListeners();
    await _persist();
  }

  Future<void> addVisit(String graveId, String visitorId) async {
    final visit = {
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'graveId': graveId,
      'visitorId': visitorId,
      'date': DateTime.now().toIso8601String(),
    };
    if (_db != null) {
      await _save('visits', visit['id']!, visit);
      return;
    }
    visits.insert(0, visit);
    notifyListeners();
    await _save('visits', visit['id']!, visit);
  }

  Future<void> saveStaff(Map<String, dynamic> member) async {
    if (_db != null) {
      await _save('staff', member['id'] as String, member);
      return;
    }
    final index = staff.indexWhere((person) => person['id'] == member['id']);
    if (index < 0) {
      staff.add(member);
    } else {
      staff[index] = member;
    }
    notifyListeners();
    await _save('staff', member['id'] as String, member);
  }

  Future<void> deleteStaff(String id) async {
    if (_db != null) {
      await _db!.collection('staff').doc(id).delete();
      return;
    }
    staff.removeWhere((person) => person['id'] == id);
    notifyListeners();
    await _persist();
  }

  Future<void> updateUserRole(String userId, String role) async {
    if (role != 'visitor' && role != 'staff' && role != 'admin') {
      throw ArgumentError.value(role, 'role', 'Unsupported access role');
    }
    final index = users.indexWhere((user) => user['id'] == userId);
    if (index < 0) throw StateError('Account not found.');
    if (_db != null) {
      await _db!.collection('users').doc(userId).update({'role': role});
    } else {
      users[index] = {...users[index], 'role': role};
      notifyListeners();
      await _persist();
    }
  }

  Future<void> addFeedback({
    required String userId,
    required int rating,
    required String message,
  }) async {
    if (rating < 1 || rating > 5) throw ArgumentError.value(rating, 'rating');
    final item = <String, dynamic>{
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'userId': userId,
      'rating': rating,
      'message': message.trim(),
      'createdAt': DateTime.now().toIso8601String(),
    };
    if (_db == null) {
      feedback.insert(0, item);
      notifyListeners();
      await _persist();
    } else {
      await _save('feedback', item['id'] as String, item);
    }
  }

  Future<void> saveSettings(Map<String, dynamic> values) async {
    if (_db != null) {
      await _db!
          .collection('settings')
          .doc('general')
          .set(values, SetOptions(merge: true));
      return;
    }
    settings.addAll(values);
    notifyListeners();
    await _persist();
  }

  Future<void> _save(
    String collection,
    String id,
    Map<String, dynamic> data,
  ) async {
    if (_db != null) {
      await _db!.collection(collection).doc(id).set(data);
    } else {
      await _persist();
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'smart_cemetery_preview_v1',
      jsonEncode(_previewData()),
    );
  }

  Map<String, dynamic> _previewData() => {
    'graves': graves.map((g) => g.toJson()).toList(),
    'requests': requests.map((r) => r.toJson()).toList(),
    'payments': payments.map((p) => p.toJson()).toList(),
    'leases': leases.map((lease) => lease.toJson()).toList(),
    'announcements': announcements,
    'visits': visits,
    'staff': staff,
    'users': users,
    'feedback': feedback,
    'settings': settings,
  };

  void _seedPreview() {
    graves
      ..clear()
      ..addAll([
        Grave(
          id: 'pedro-dela-cruz',
          name: 'Pedro Dela Cruz',
          block: '12',
          lot: '45',
          number: '3',
          born: DateTime(1940, 5, 12),
          died: DateTime(2020, 3, 3),
          buriedAt: DateTime(2020, 3, 5),
          birthplace: 'Manila, Philippines',
          deathplace: 'Quezon City, Philippines',
          message: 'Always in our hearts.',
          portraitPhotoUrl: 'assets/images/portrait_sample.png',
          tombPhotoUrl: 'assets/images/grave_sample.png',
          mapRow: 2,
          mapColumn: 3,
          latitude: 14.6327,
          longitude: 120.9897,
        ),
        for (var row = 0; row < 4; row++)
          for (var col = 0; col < 5; col++)
            if (row != 2 || col != 3)
              Grave(
                id: 'plot-$row-$col',
                name: '',
                block: '12',
                lot: '${row * 5 + col + 1}',
                number: '1',
                status: (row + col) % 6 == 0 ? 'reserved' : 'available',
                mapRow: row,
                mapColumn: col,
                latitude: 14.6330 - row * 0.00015,
                longitude: 120.9893 + col * 0.00015,
              ),
      ]);
    settings.addAll({
      'mapCenterLatitude': 14.6327,
      'mapCenterLongitude': 120.9897,
      'visitingHours': 'Contact the cemetery office for visiting hours.',
      'guidelines':
          'Please keep the grounds clean and be respectful of other visitors.',
      'emergencyContact': 'Contact local emergency services.',
    });
    announcements
      ..clear()
      ..add({
        'id': 'welcome',
        'title': 'Welcome to Smart Cemetery',
        'body': 'Visit the office for current visiting hours and assistance.',
        'date': DateTime.now().toIso8601String(),
      });
  }
}
