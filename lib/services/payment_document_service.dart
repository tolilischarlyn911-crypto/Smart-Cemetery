import 'dart:convert';
import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:file_selector/file_selector.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/cemetery_models.dart';
import 'firebase_setup.dart';

class PaymentDocumentService {
  static const _mimeByExtension = <String, String>{
    'pdf': 'application/pdf',
    'doc': 'application/msword',
    'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
  };

  static Future<List<XFile>> pick() => openFiles(
    acceptedTypeGroups: [
      const XTypeGroup(
        label: 'Receipts and supporting documents',
        extensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png', 'webp'],
      ),
    ],
  );

  static Future<PaymentAttachment> save(
    XFile file, {
    required String paymentId,
  }) async {
    final extension = file.name.split('.').last.toLowerCase();
    final mimeType = _mimeByExtension[extension];
    if (mimeType == null) {
      throw StateError('Choose a PDF, Word document, JPG, PNG, or WebP file.');
    }
    final bytes = await file.readAsBytes();
    final limit = FirebaseSetup.configured ? 10 * 1024 * 1024 : 500 * 1024;
    if (bytes.isEmpty || bytes.length > limit) {
      throw StateError(
        FirebaseSetup.configured
            ? 'Supporting files must be between 1 byte and 10 MiB.'
            : 'Preview supporting files must be under 500 KiB.',
      );
    }
    if (!FirebaseSetup.configured) {
      return PaymentAttachment(
        name: file.name,
        mimeType: mimeType,
        source: 'data:$mimeType;base64,${base64Encode(bytes)}',
      );
    }
    if (FirebaseSetup.storageBucket.isEmpty) {
      throw StateError('Firebase Storage bucket is not configured.');
    }
    final path =
        'payment-documents/$paymentId/${DateTime.now().microsecondsSinceEpoch}.$extension';
    await FirebaseStorage.instance
        .ref(path)
        .putData(bytes, SettableMetadata(contentType: mimeType));
    return PaymentAttachment(name: file.name, mimeType: mimeType, source: path);
  }

  static Future<Uint8List> read(PaymentAttachment attachment) async {
    if (attachment.source.startsWith('data:')) {
      final separator = attachment.source.indexOf(',');
      if (separator < 0) throw StateError('This file is invalid.');
      return base64Decode(attachment.source.substring(separator + 1));
    }
    final bytes = await FirebaseStorage.instance
        .ref(attachment.source)
        .getData(10 * 1024 * 1024);
    if (bytes == null) throw StateError('This file could not be downloaded.');
    return bytes;
  }

  static Future<void> download(PaymentAttachment attachment) async {
    final bytes = await read(attachment);
    final extension = attachment.name.split('.').last.toLowerCase();
    final fileName = attachment.name.endsWith('.$extension')
        ? attachment.name.substring(
            0,
            attachment.name.length - extension.length - 1,
          )
        : attachment.name;
    await FileSaver.instance.saveFile(
      name: fileName,
      bytes: bytes,
      fileExtension: extension,
      mimeType: MimeType.custom,
      customMimeType: attachment.mimeType,
    );
  }

  static Future<void> delete(PaymentAttachment attachment) async {
    if (attachment.source.startsWith('data:')) return;
    await FirebaseStorage.instance.ref(attachment.source).delete();
  }
}
