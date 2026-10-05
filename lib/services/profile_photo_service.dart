import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_setup.dart';
import 'photo_service.dart';

class ProfilePhotoService {
  static final ValueNotifier<String?> source = ValueNotifier(null);

  static Future<void> load(String userId) async {
    source.value = null;
    if (FirebaseSetup.configured) {
      source.value = FirebaseAuth.instance.currentUser?.photoURL;
    } else {
      final preferences = await SharedPreferences.getInstance();
      source.value = preferences.getString('profile-photo-$userId');
    }
  }

  static Future<void> save(String userId, XFile photo) async {
    final url = await PhotoService.save(photo, path: 'profiles/$userId/avatar');
    if (FirebaseSetup.configured) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.uid != userId) {
        throw StateError('Sign in to update your profile photo.');
      }
      await user.updatePhotoURL(url);
    } else {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('profile-photo-$userId', url);
    }
    source.value = url;
  }
}
