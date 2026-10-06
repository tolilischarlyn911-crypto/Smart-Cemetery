import 'dart:convert';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import 'firebase_setup.dart';

class PhotoService {
  static Future<XFile?> pick(ImageSource source) => ImagePicker().pickImage(
    source: source,
    maxWidth: 1024,
    maxHeight: 1024,
    imageQuality: 72,
  );

  static Future<String> save(XFile photo, {required String path}) async {
    var bytes = await photo.readAsBytes();
    if (bytes.isEmpty) throw StateError('The selected photo is empty.');
    var mime =
        photo.mimeType ??
        (photo.name.toLowerCase().endsWith('.png')
            ? 'image/png'
            : 'image/jpeg');
    if (!['image/jpeg', 'image/png', 'image/webp'].contains(mime)) {
      throw StateError('Choose a JPG, PNG, or WebP image.');
    }
    final limit = FirebaseSetup.configured ? 2 * 1024 * 1024 : 500 * 1024;
    if (bytes.length > limit) {
      final compressed = await compute(_compressPhoto, bytes);
      if (compressed == null || compressed.length > limit) {
        throw StateError(
          'This photo could not be reduced to the upload size limit.',
        );
      }
      bytes = compressed;
      mime = 'image/jpeg';
    }
    if (FirebaseSetup.configured) {
      if (FirebaseSetup.storageBucket.isEmpty) {
        throw StateError('Firebase Storage bucket is not configured.');
      }
      final extension = mime == 'image/png'
          ? 'png'
          : mime == 'image/webp'
          ? 'webp'
          : 'jpg';
      final reference = FirebaseStorage.instance.ref('$path.$extension');
      await reference.putData(bytes, SettableMetadata(contentType: mime));
      return reference.getDownloadURL();
    }
    return 'data:$mime;base64,${base64Encode(bytes)}';
  }

  static ImageProvider<Object>? provider(String? source) {
    if (source == null || source.isEmpty) return null;
    if (source.startsWith('assets/')) return AssetImage(source);
    if (source.startsWith('data:image/')) {
      final separator = source.indexOf(',');
      if (separator < 0) return null;
      try {
        return MemoryImage(base64Decode(source.substring(separator + 1)));
      } catch (_) {
        return null;
      }
    }
    final uri = Uri.tryParse(source);
    if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
      return NetworkImage(source);
    }
    return null;
  }
}

Uint8List? _compressPhoto(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final oriented = img.bakeOrientation(decoded);
  for (final (dimension, quality) in [(900, 75), (650, 65), (480, 50)]) {
    final longest = oriented.width > oriented.height
        ? oriented.width
        : oriented.height;
    final resized = longest > dimension
        ? img.copyResize(
            oriented,
            width: oriented.width >= oriented.height ? dimension : null,
            height: oriented.height > oriented.width ? dimension : null,
            interpolation: img.Interpolation.average,
          )
        : oriented;
    final encoded = img.encodeJpg(resized, quality: quality);
    if (encoded.length <= 500 * 1024) return encoded;
  }
  return null;
}
