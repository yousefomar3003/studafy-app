import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// A person's profile photo, kept on this device only.
///
/// It is never uploaded: it is for the person's own screens, a server copy
/// would cost storage for every account, and the photo of a child is not
/// something the service needs to hold. One small JPEG per account, in the
/// app's private storage, named by a hash of the account id; it is deleted
/// when that account signs out of the device.
class ProfilePhotos {
  ProfilePhotos._();

  /// Bumped whenever any account's photo changes, so every avatar on screen
  /// redraws together.
  static final changes = ValueNotifier<int>(0);

  static final Map<String, Uint8List?> _memory = {};

  /// Overrides the folder in tests.
  @visibleForTesting
  static Directory? folderOverride;

  static Future<File> _file(String userId) async {
    final base = folderOverride ?? await getApplicationSupportDirectory();
    final name = sha256.convert(userId.codeUnits).toString();
    return File(p.join(base.path, 'profile_photos', '$name.jpg'));
  }

  /// The photo already read for [userId], without waiting; null when there
  /// is none or it has not been read yet. Lets an avatar draw the photo on
  /// its first frame instead of flashing initials first.
  static Uint8List? cached(String userId) => _memory[userId];

  /// The photo for [userId], or null when there is none.
  static Future<Uint8List?> read(String userId) async {
    if (_memory.containsKey(userId)) return _memory[userId];
    final file = await _file(userId);
    final bytes = await file.exists() ? await file.readAsBytes() : null;
    _memory[userId] = bytes;
    return bytes;
  }

  static Future<void> save(String userId, Uint8List bytes) async {
    final file = await _file(userId);
    await file.parent.create(recursive: true);
    final partial = File('${file.path}.part');
    await partial.writeAsBytes(bytes, flush: true);
    await partial.rename(file.path);
    _memory[userId] = bytes;
    changes.value++;
  }

  static Future<void> delete(String userId) async {
    final file = await _file(userId);
    if (await file.exists()) await file.delete();
    _memory[userId] = null;
    changes.value++;
  }

  /// Lets the person choose or take a photo, already small: 400 pixels and
  /// JPEG, a few tens of kilobytes. Null when they cancel.
  static Future<Uint8List?> pick(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 400,
      maxHeight: 400,
      imageQuality: 80,
      requestFullMetadata: false,
    );
    return picked == null ? null : await picked.readAsBytes();
  }
}

/// A round avatar: the account's photo when there is one on this device,
/// otherwise [fallback] (initials or an icon).
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.userId,
    required this.radius,
    required this.fallback,
    this.backgroundColor,
  });

  final String? userId;
  final double radius;
  final Widget fallback;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final id = userId;
    return ValueListenableBuilder<int>(
      valueListenable: ProfilePhotos.changes,
      builder: (context, _, _) => FutureBuilder<Uint8List?>(
        future: id == null ? Future.value() : ProfilePhotos.read(id),
        initialData: id == null ? null : ProfilePhotos.cached(id),
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          return CircleAvatar(
            radius: radius,
            backgroundColor: backgroundColor,
            backgroundImage: bytes == null ? null : MemoryImage(bytes),
            child: bytes == null ? fallback : null,
          );
        },
      ),
    );
  }
}
