import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/failures.dart';
import '../../core/file_upload_repository.dart';
import 'cache_scope.dart';
import 'session_cache_binder.dart';

/// Attachments opened on this device, kept so they open again offline.
///
/// One folder per signed-in person next to their cache files, named by a
/// hash of the user id, erased with them at sign-out
/// ([OfflineFileCache.wipeUser]). Files are named by a hash of the file id,
/// never by the file's own name. The oldest are dropped past [maxBytes].
class OfflineFileCache {
  OfflineFileCache(
    this._binder, {
    Future<String> Function()? root,
    this.maxBytes = 200 * 1024 * 1024,
  }) : _root = root ?? getDatabasesPath;

  final SessionCacheBinder _binder;
  final Future<String> Function() _root;
  final int maxBytes;

  static String _folderName(String userId) =>
      'studafy_files_${CacheScope(userId: userId).userFileKey}';

  static String _fileKey(String fileId) =>
      sha256.convert(utf8.encode(fileId)).toString().substring(0, 40);

  Future<Directory?> _folder() async {
    final userId = _binder.scope?.userId;
    if (userId == null) return null;
    return Directory(join(await _root(), _folderName(userId)));
  }

  Future<DownloadedFile?> read(String fileId) async {
    final folder = await _folder();
    if (folder == null) return null;
    final key = _fileKey(fileId);
    final meta = File(join(folder.path, '$key.json'));
    final bytes = File(join(folder.path, '$key.bin'));
    if (!await meta.exists() || !await bytes.exists()) return null;
    final info = jsonDecode(await meta.readAsString()) as Map<String, dynamic>;
    return DownloadedFile(
      displayName: info['displayName'] as String,
      mediaType: info['mediaType'] as String,
      bytes: await bytes.readAsBytes(),
    );
  }

  Future<void> write(String fileId, DownloadedFile file) async {
    final folder = await _folder();
    if (folder == null || file.bytes.length > maxBytes) return;
    await folder.create(recursive: true);
    final key = _fileKey(fileId);
    await File(join(folder.path, '$key.bin')).writeAsBytes(file.bytes);
    await File(join(folder.path, '$key.json')).writeAsString(
      jsonEncode({
        'displayName': file.displayName,
        'mediaType': file.mediaType,
      }),
    );
    await _trim(folder);
  }

  /// Drops the least recently written files until the folder fits.
  Future<void> _trim(Directory folder) async {
    final blobs = <File, FileStat>{};
    await for (final entry in folder.list()) {
      if (entry is File && entry.path.endsWith('.bin')) {
        blobs[entry] = await entry.stat();
      }
    }
    var total = blobs.values.fold<int>(0, (sum, stat) => sum + stat.size);
    final oldestFirst = blobs.entries.toList()
      ..sort((a, b) => a.value.modified.compareTo(b.value.modified));
    for (final entry in oldestFirst) {
      if (total <= maxBytes) break;
      total -= entry.value.size;
      await entry.key.delete();
      final meta = File(
        entry.key.path.replaceFirst(RegExp(r'\.bin$'), '.json'),
      );
      if (await meta.exists()) await meta.delete();
    }
  }

  /// Erases everything kept for [userId]. Called with the rest of their
  /// cache when they sign out or another account takes over the device.
  static Future<void> wipeUser(String userId, {String? root}) async {
    final folder = Directory(
      join(root ?? await getDatabasesPath(), _folderName(userId)),
    );
    if (await folder.exists()) await folder.delete(recursive: true);
  }
}

/// Opens attachments from the server when it answers, and from the device
/// when it cannot be reached. A refusal is never covered up: a file the
/// person may no longer open is not served from the device either.
class CachingFileRepository implements FileUploadRepository {
  CachingFileRepository(this._inner, this._cache);

  final FileUploadRepository _inner;
  final OfflineFileCache _cache;

  @override
  Future<DownloadedFile> download(String fileId) async {
    try {
      final file = await _inner.download(fileId);
      try {
        await _cache.write(fileId, file);
      } on Object {
        // Out of space or signed out mid-way: the file still opens.
      }
      return file;
    } on Object catch (error) {
      if (Failure.fromError(error).code != Failure.networkCode) rethrow;
      DownloadedFile? kept;
      try {
        kept = await _cache.read(fileId);
      } on Object {
        kept = null;
      }
      if (kept == null) rethrow;
      return kept;
    }
  }

  @override
  Future<QuarantinedFile> upload(FileUploadCommand command) =>
      _inner.upload(command);

  @override
  Future<String> publishToClass({
    required String fileId,
    required FileAudience audience,
  }) => _inner.publishToClass(fileId: fileId, audience: audience);
}
