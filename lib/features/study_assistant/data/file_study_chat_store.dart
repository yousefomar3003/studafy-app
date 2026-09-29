import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/study_assistant_repository.dart';

/// Chats with the helper, one file per account in the app's private support
/// directory - which the OS encrypts at rest and no other app can read.
///
/// The file is named by a hash of the account id, so a directory listing
/// says nothing about whose it is, and several accounts on one device never
/// see each other's chats. Signing an account out of the device deletes its
/// file ([forgetUser]).
class FileStudyChatStore implements StudyChatStore {
  FileStudyChatStore({
    required this.currentUserId,
    Future<Directory> Function()? directory,
  }) : _directory = directory ?? getApplicationSupportDirectory;

  /// Whose chats: the account signed in now.
  final String? Function() currentUserId;
  final Future<Directory> Function() _directory;

  /// Enough to find an old chat again without the file growing forever.
  static const maximumChats = 50;
  static const maximumTurnsPerChat = 200;

  static String _fileName(String userId) =>
      'study_chats_${sha256.convert(utf8.encode(userId))}.json';

  Future<File?> _file([String? userId]) async {
    final id = userId ?? currentUserId();
    if (id == null) return null;
    final directory = await _directory();
    return File(p.join(directory.path, _fileName(id)));
  }

  Future<List<StudyChat>> _read(File file) async {
    if (!file.existsSync()) return [];
    try {
      final json = jsonDecode(await file.readAsString());
      return [
        for (final item in json as List<dynamic>) ?StudyChat.fromJson(item),
      ];
    } on Object {
      // Unreadable is empty: losing a chat history is better than a helper
      // that cannot open at all.
      return [];
    }
  }

  Future<void> _write(File file, List<StudyChat> chats) async {
    if (chats.isEmpty) {
      if (file.existsSync()) await file.delete();
      return;
    }
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      jsonEncode([for (final chat in chats) chat.toJson()]),
      flush: true,
    );
    // Replaced whole, so a crash mid-write leaves the old history intact.
    await temporary.rename(file.path);
  }

  @override
  Future<List<StudyChat>> chats() async {
    final file = await _file();
    if (file == null) return const [];
    final list = await _read(file)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  @override
  Future<void> save(StudyChat chat) async {
    final file = await _file();
    if (file == null) return;
    final kept = chat.turns.length > maximumTurnsPerChat
        ? chat.withTurns(
            chat.turns.sublist(chat.turns.length - maximumTurnsPerChat),
          )
        : chat;
    final list = (await _read(file))..removeWhere((c) => c.id == chat.id);
    list
      ..add(kept)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await _write(file, list.take(maximumChats).toList());
  }

  @override
  Future<void> delete(String chatId) async {
    final file = await _file();
    if (file == null) return;
    final list = (await _read(file))..removeWhere((c) => c.id == chatId);
    await _write(file, list);
  }

  @override
  Future<void> deleteAll() async {
    final file = await _file();
    if (file != null && file.existsSync()) await file.delete();
  }

  /// Deletes an account's chats, whether or not it is the one signed in.
  Future<void> forgetUser(String userId) async {
    final file = await _file(userId);
    if (file != null && file.existsSync()) await file.delete();
  }
}
