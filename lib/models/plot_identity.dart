import 'dart:convert';

import 'package:crypto/crypto.dart';

String normalizedPlotPart(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

/// Stable Firestore document ID for a physical block, lot, and grave number.
String plotIdentityKey(String block, String lot, String number) {
  final parts = [block, lot, number].map(normalizedPlotPart).toList();
  if (parts.any((part) => part.isEmpty)) {
    throw ArgumentError('Block, lot, and grave number are required.');
  }
  return sha256.convert(utf8.encode(parts.join('\u0000'))).toString();
}
