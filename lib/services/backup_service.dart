import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

class BackupService {
  static const _iterations = 600000;
  static const _fileFormat = 'smart-cemetery-encrypted-backup';
  static const maxFileBytes = 50 * 1024 * 1024;

  static Future<Uint8List> encrypt(
    Map<String, dynamic> snapshot,
    String passphrase,
  ) async {
    if (passphrase.trim().length < 12) {
      throw ArgumentError('Use a backup passphrase of at least 12 characters.');
    }
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final cipher = AesGcm.with256bits();
    final key = await _deriveKey(passphrase, salt);
    final box = await cipher.encrypt(
      utf8.encode(jsonEncode(snapshot)),
      secretKey: key,
    );
    final file = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'format': _fileFormat,
          'version': 1,
          'kdf': 'PBKDF2-HMAC-SHA256',
          'iterations': _iterations,
          'cipher': 'AES-256-GCM',
          'salt': base64Encode(salt),
          'box': base64Encode(box.concatenation()),
        }),
      ),
    );
    if (file.length > maxFileBytes) {
      throw StateError('Backup exceeds the 50 MB file limit.');
    }
    return file;
  }

  static Future<Map<String, dynamic>> decrypt(
    Uint8List file,
    String passphrase,
  ) async {
    if (file.isEmpty || file.length > maxFileBytes) {
      throw const FormatException('Backup file is empty or too large.');
    }
    try {
      final envelope = jsonDecode(utf8.decode(file)) as Map<String, dynamic>;
      if (envelope['format'] != _fileFormat ||
          envelope['version'] != 1 ||
          envelope['kdf'] != 'PBKDF2-HMAC-SHA256' ||
          envelope['iterations'] != _iterations ||
          envelope['cipher'] != 'AES-256-GCM') {
        throw const FormatException('Unsupported backup format.');
      }
      final salt = base64Decode(envelope['salt'] as String);
      if (salt.length != 16) {
        throw const FormatException('Invalid backup salt.');
      }
      final cipher = AesGcm.with256bits();
      final box = SecretBox.fromConcatenation(
        base64Decode(envelope['box'] as String),
        nonceLength: cipher.nonceLength,
        macLength: cipher.macAlgorithm.macLength,
      );
      final key = await _deriveKey(passphrase, salt);
      final plain = await cipher.decrypt(box, secretKey: key);
      return Map<String, dynamic>.from(jsonDecode(utf8.decode(plain)) as Map);
    } on SecretBoxAuthenticationError {
      throw StateError('Incorrect passphrase or damaged backup file.');
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Invalid backup file.');
    }
  }

  static Future<SecretKey> _deriveKey(String passphrase, List<int> salt) =>
      Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: _iterations,
        bits: 256,
      ).deriveKeyFromPassword(password: passphrase, nonce: salt);
}
