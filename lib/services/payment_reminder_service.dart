import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/cemetery_models.dart';

class PaymentAlert {
  final int id;
  final DateTime at;
  final PaymentRecord payment;
  final bool advance;

  const PaymentAlert(this.id, this.at, this.payment, this.advance);
}

/// Schedules local alerts for payments already synced to this device.
/// A remote payment update is picked up when the app next receives store data.
class PaymentReminderService {
  PaymentReminderService._();

  static final instance = PaymentReminderService._();
  static const _ownerKey = 'smart_cemetery_reminder_owner';
  static const _idsKey = 'smart_cemetery_reminder_ids';
  static const _enabledPrefix = 'smart_cemetery_reminders_enabled_';
  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'payment_reminders',
      'Payment reminders',
      channelDescription: 'Upcoming cemetery payment due dates',
      importance: Importance.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  String? _lastSignature;
  Future<void> _serial = Future.value();

  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<bool> isEnabled(String userId) async {
    if (!supported) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_enabledPrefix$userId') ?? false;
  }

  Future<bool> enable(String userId, List<PaymentRecord> payments) async {
    if (!supported) return false;
    await _initialize();
    bool? granted;
    if (defaultTargetPlatform == TargetPlatform.android) {
      granted = await _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    } else {
      granted = await _notifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
    if (granted == false) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_enabledPrefix$userId', true);
    await sync(userId, payments);
    return true;
  }

  Future<void> disable(String userId) async {
    if (!supported) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_enabledPrefix$userId', false);
    await _enqueue(() => _clearScheduled(userId));
  }

  Future<void> clearForLogout(String userId) async {
    if (!supported) return;
    await _enqueue(() => _clearScheduled(userId));
  }

  Future<void> sync(String userId, List<PaymentRecord> payments) =>
      supported ? _enqueue(() => _sync(userId, payments)) : Future.value();

  Future<void> _enqueue(Future<void> Function() action) {
    final next = _serial.then((_) => action());
    _serial = next.catchError((Object _) {});
    return next;
  }

  Future<void> _initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    final info = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(info.identifier));
    await _notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _initialized = true;
  }

  Future<void> _sync(String userId, List<PaymentRecord> payments) async {
    final prefs = await SharedPreferences.getInstance();
    final previousOwner = prefs.getString(_ownerKey);
    if (previousOwner != null && previousOwner != userId) {
      await _cancelSaved(prefs);
      _lastSignature = null;
    }
    if (!(prefs.getBool('$_enabledPrefix$userId') ?? false)) return;
    await _initialize();
    final alerts = planAlerts(userId, payments, DateTime.now());
    final signature = jsonEncode(
      alerts
          .map(
            (alert) => [
              alert.id,
              alert.at.toIso8601String(),
              alert.payment.type,
              alert.payment.amount,
            ],
          )
          .toList(),
    );
    if (_lastSignature == signature && previousOwner == userId) return;
    await _cancelSaved(prefs);
    final scheduled = <int>[];
    try {
      for (final alert in alerts) {
        final at = tz.TZDateTime(
          tz.local,
          alert.at.year,
          alert.at.month,
          alert.at.day,
          alert.at.hour,
        );
        await _notifications.zonedSchedule(
          id: alert.id,
          title: alert.advance ? 'Payment due in 7 days' : 'Payment due today',
          body:
              '${alert.payment.type} · ₱${alert.payment.amount.toStringAsFixed(2)}',
          scheduledDate: at,
          notificationDetails: _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: alert.payment.id,
        );
        scheduled.add(alert.id);
      }
      await prefs.setString(_ownerKey, userId);
      await prefs.setStringList(_idsKey, scheduled.map((id) => '$id').toList());
      _lastSignature = signature;
    } catch (_) {
      for (final id in scheduled) {
        await _notifications.cancel(id: id);
      }
      rethrow;
    }
  }

  Future<void> _clearScheduled(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_ownerKey) != userId) return;
    await _initialize();
    await _cancelSaved(prefs);
    await prefs.remove(_ownerKey);
    _lastSignature = null;
  }

  Future<void> _cancelSaved(SharedPreferences prefs) async {
    await _initialize();
    for (final value in prefs.getStringList(_idsKey) ?? const <String>[]) {
      final id = int.tryParse(value);
      if (id != null) await _notifications.cancel(id: id);
    }
    await prefs.remove(_idsKey);
  }

  /// Keeps the nearest 60 alerts to respect iOS's 64 pending-alert limit.
  static List<PaymentAlert> planAlerts(
    String userId,
    List<PaymentRecord> payments,
    DateTime now,
  ) {
    final alerts = <PaymentAlert>[];
    for (final payment in payments) {
      final due = payment.dueDate;
      if (payment.ownerId != userId ||
          payment.status == 'Paid' ||
          due == null) {
        continue;
      }
      final dueMorning = DateTime(due.year, due.month, due.day, 9);
      final advance = DateTime(due.year, due.month, due.day - 7, 9);
      if (advance.isAfter(now)) {
        alerts.add(
          PaymentAlert(
            _id(userId, payment.id, 'advance'),
            advance,
            payment,
            true,
          ),
        );
      }
      if (dueMorning.isAfter(now)) {
        alerts.add(
          PaymentAlert(
            _id(userId, payment.id, 'due'),
            dueMorning,
            payment,
            false,
          ),
        );
      }
    }
    alerts.sort((a, b) => a.at.compareTo(b.at));
    return alerts.take(60).toList();
  }

  static int _id(String userId, String paymentId, String kind) {
    var hash = 0x811c9dc5;
    for (final unit in '$userId:$paymentId:$kind'.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }
}
