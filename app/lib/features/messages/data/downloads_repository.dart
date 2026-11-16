import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'package:kharis_app/core/constants/http_constants.dart';
import 'package:kharis_app/core/services/cache_service.dart';
import 'package:kharis_app/shared/models/sermon.dart';

/// A message whose audio is saved on this device.
@immutable
class DownloadedMessage {
  const DownloadedMessage({
    required this.sermon,
    required this.fileName,
    required this.bytes,
    required this.savedAt,
  });

  /// The message as it was when it was saved, so the Downloads list works
  /// with no connection and before the library has loaded.
  final Sermon sermon;

  /// Name of the audio file inside the downloads folder. Never a full path:
  /// iOS moves the app's folders between installs.
  final String fileName;

  /// Size of the audio file.
  final int bytes;

  final DateTime savedAt;

  Map<String, dynamic> toJson() => {
    'sermon': sermon.toJson(),
    'file': fileName,
    'bytes': bytes,
    'savedAt': savedAt.millisecondsSinceEpoch,
  };

  static DownloadedMessage? fromJson(Object? json) {
    if (json is! Map) return null;
    final sermon = json['sermon'];
    final file = json['file'];
    final bytes = json['bytes'];
    final savedAt = json['savedAt'];
    if (sermon is! Map || file is! String || bytes is! num || savedAt is! num) {
      return null;
    }
    try {
      return DownloadedMessage(
        sermon: Sermon.fromJson(Map<String, dynamic>.from(sermon)),
        fileName: file,
        bytes: bytes.toInt(),
        savedAt: DateTime.fromMillisecondsSinceEpoch(savedAt.toInt()),
      );
    } on Object {
      return null;
    }
  }
}

/// Why a download did not finish.
enum DownloadFailureReason {
  /// The message has no audio recording to save.
  noAudio,

  /// The phone ran out of storage.
  noSpace,

  /// No connection, or it dropped or timed out.
  connection,

  /// The server refused or no longer has the file.
  server,

  /// The file could not be written for another reason.
  storage,

  /// This platform keeps no files (the web app).
  unsupported,
}

/// Where one message is with being saved to this device.
sealed class DownloadStatus {
  const DownloadStatus();
}

class NotDownloaded extends DownloadStatus {
  const NotDownloaded();
}

class Downloading extends DownloadStatus {
  const Downloading({required this.received, this.total});

  /// Bytes received so far.
  final int received;

  /// Size of the file, or null when the server did not say.
  final int? total;

  /// Fraction received, or null when the size is unknown.
  double? get fraction {
    final all = total;
    if (all == null || all <= 0) return null;
    return (received / all).clamp(0.0, 1.0);
  }
}

class Downloaded extends DownloadStatus {
  const Downloaded(this.message);

  final DownloadedMessage message;
}

/// The last attempt failed. Stays until the next attempt or
/// [DownloadsRepository.clearFailure].
class DownloadFailed extends DownloadStatus {
  const DownloadFailed(this.reason);

  final DownloadFailureReason reason;
}

class _Active {
  _Active(this.token);

  final CancelToken token;
  Downloading progress = const Downloading(received: 0);
  late final Future<DownloadStatus> done;
}

/// Saves message audio to app storage for listening with no connection.
///
/// Files live in `downloads/` under the app support folder, which members
/// cannot browse and the system does not clear. The list of what is saved
/// (with a copy of each message) is a [CacheService] preference; each entry
/// names its file, and the folder is looked up afresh on every launch.
///
/// A download is written to `<name>.part` and renamed when complete, so a
/// file with its final name is always whole. [ready] drops entries whose
/// file is gone and partial files left by a closed app.
class DownloadsRepository {
  DownloadsRepository(
    this._cache, {
    Dio? dio,
    Future<Directory> Function()? directory,
    DateTime Function()? clock,
  }) : _dio = dio ?? Dio(_options),
       _directory = directory ?? _appDownloads,
       _clock = clock ?? DateTime.now {
    ready = _prepare();
  }

  static final BaseOptions _options = BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    // Longest silence allowed between two chunks, not the whole download.
    receiveTimeout: const Duration(seconds: 30),
  );

  static Future<Directory> _appDownloads() async {
    final base = await getApplicationSupportDirectory();
    return Directory('${base.path}/downloads');
  }

  /// Preference key of the saved list, as JSON.
  static const String indexKey = 'downloads_index';

  static const String _partSuffix = '.part';

  /// `ENOSPC`, the same number on Android and iOS.
  static const int _noSpaceErrno = 28;

  final CacheService _cache;
  final Dio _dio;
  final Future<Directory> Function() _directory;
  final DateTime Function() _clock;

  /// Bumped when the saved list, a download's progress or a failure changes.
  final ValueNotifier<int> changes = ValueNotifier(0);

  /// Completes once the downloads folder is known and the saved list has
  /// been checked against it. Never fails.
  late final Future<void> ready;

  Directory? _folder;
  List<DownloadedMessage>? _items;
  final Map<String, _Active> _active = {};
  final Map<String, DownloadFailureReason> _failures = {};
  bool _disposed = false;

  // ── Reads ──────────────────────────────────────────────────────────────────

  /// Saved messages, most recently saved first.
  List<DownloadedMessage> downloads() => List.unmodifiable(_saved());

  /// Bytes all saved audio takes up.
  int get totalBytes => _saved().fold(0, (sum, d) => sum + d.bytes);

  bool isDownloaded(String sermonId) => _find(sermonId) != null;

  DownloadStatus statusOf(String sermonId) {
    final active = _active[sermonId];
    if (active != null) return active.progress;
    final saved = _find(sermonId);
    if (saved != null) return Downloaded(saved);
    final failure = _failures[sermonId];
    return failure == null ? const NotDownloaded() : DownloadFailed(failure);
  }

  /// The file [sermon]'s audio is saved in, or null to stream it.
  ///
  /// Only a file saved from the very address [sermon] streams from: if the
  /// recording behind a message is ever replaced, the stale file is not
  /// played. Synchronous, because the player builds its sources that way;
  /// null until [ready].
  Uri? localAudioUri(Sermon sermon) {
    final folder = _folder;
    if (folder == null || !sermon.hasAudio) return null;
    for (final saved in _saved()) {
      if (saved.sermon.audioUrl != sermon.audioUrl) continue;
      final file = File('${folder.path}/${saved.fileName}');
      return file.existsSync() ? file.uri : null;
    }
    return null;
  }

  // ── Writes ─────────────────────────────────────────────────────────────────

  /// Saves [sermon]'s audio. Never throws: the answer is [Downloaded],
  /// [DownloadFailed] with the reason, or [NotDownloaded] when [cancel]
  /// stopped it. Asking again while it runs joins the download under way.
  Future<DownloadStatus> download(Sermon sermon) {
    final saved = _find(sermon.id);
    if (saved != null) return Future.value(Downloaded(saved));
    final running = _active[sermon.id];
    if (running != null) return running.done;
    if (!sermon.hasAudio) {
      return Future.value(_failed(sermon.id, DownloadFailureReason.noAudio));
    }
    if (kIsWeb) {
      return Future.value(
        _failed(sermon.id, DownloadFailureReason.unsupported),
      );
    }
    _failures.remove(sermon.id);
    final active = _Active(CancelToken());
    _active[sermon.id] = active;
    _notify();
    return active.done = _run(sermon, active).then((status) {
      _active.remove(sermon.id);
      if (status is DownloadFailed) _failures[sermon.id] = status.reason;
      _notify();
      return status;
    });
  }

  /// Stops [sermonId]'s download, if one is running, and discards what it
  /// had received.
  void cancel(String sermonId) => _active[sermonId]?.token.cancel();

  /// Forgets [sermonId]'s last failure, so its status reads [NotDownloaded].
  void clearFailure(String sermonId) {
    if (_failures.remove(sermonId) != null) _notify();
  }

  /// Removes [sermonId]'s saved audio, or stops its download.
  Future<void> delete(String sermonId) async {
    cancel(sermonId);
    final saved = _find(sermonId);
    if (saved == null) return;
    _saved().remove(saved);
    _persist();
    _notify();
    await ready;
    final folder = _folder;
    if (folder == null) return;
    await _discard(File('${folder.path}/${saved.fileName}'));
  }

  /// Stops every download under way.
  void dispose() {
    _disposed = true;
    for (final active in _active.values) {
      active.token.cancel();
    }
  }

  // ── Internals ──────────────────────────────────────────────────────────────

  Future<DownloadStatus> _run(Sermon sermon, _Active active) async {
    await ready;
    final folder = _folder;
    if (folder == null) {
      return const DownloadFailed(DownloadFailureReason.storage);
    }
    final name = fileNameFor(sermon);
    final part = File('${folder.path}/$name$_partSuffix');
    try {
      var lastStep = -1;
      await _dio.download(
        sermon.audioUrl,
        part.path,
        cancelToken: active.token,
        // The host refuses anything that is not a browser.
        options: Options(headers: const {'User-Agent': kBrowserUserAgent}),
        onReceiveProgress: (received, total) {
          final known = total > 0;
          active.progress = Downloading(
            received: received,
            total: known ? total : null,
          );
          // One redraw per percent, or per 512 KB when the size is unknown.
          final step = known ? received * 100 ~/ total : received >> 19;
          if (step == lastStep) return;
          lastStep = step;
          _notify();
        },
      );
      final file = await part.rename('${folder.path}/$name');
      final item = DownloadedMessage(
        sermon: sermon,
        fileName: name,
        bytes: await file.length(),
        savedAt: _clock(),
      );
      _saved().insert(0, item);
      _persist();
      return Downloaded(item);
    } on DioException catch (error) {
      await _discard(part);
      if (CancelToken.isCancel(error)) return const NotDownloaded();
      return DownloadFailed(_reasonOf(error));
    } on FileSystemException catch (error) {
      await _discard(part);
      return DownloadFailed(_fileReason(error));
    }
  }

  static DownloadFailureReason _reasonOf(DioException error) {
    final cause = error.error;
    if (cause is FileSystemException) return _fileReason(cause);
    return error.response == null
        ? DownloadFailureReason.connection
        : DownloadFailureReason.server;
  }

  static DownloadFailureReason _fileReason(FileSystemException error) =>
      error.osError?.errorCode == _noSpaceErrno
      ? DownloadFailureReason.noSpace
      : DownloadFailureReason.storage;

  /// The file name [sermon]'s audio is saved under: its id, made safe for a
  /// file system, with the recording's own extension (players tell the
  /// format from it).
  @visibleForTesting
  static String fileNameFor(Sermon sermon) {
    final id = sermon.id.replaceAll(RegExp('[^A-Za-z0-9_-]'), '_');
    final path = Uri.tryParse(sermon.audioUrl)?.path ?? '';
    final extension = RegExp(r'\.[A-Za-z0-9]{1,5}$').firstMatch(path)?[0];
    return '$id${extension ?? '.mp3'}';
  }

  Future<void> _prepare() async {
    if (kIsWeb) return;
    try {
      final folder = await _directory();
      await folder.create(recursive: true);
      final onDisk = <String>{};
      await for (final entity in folder.list()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        if (name.endsWith(_partSuffix)) {
          await _discard(entity);
        } else {
          onDisk.add(name);
        }
      }
      _folder = folder;
      final items = _saved();
      final before = items.length;
      items.removeWhere((d) => !onDisk.contains(d.fileName));
      if (items.length != before) _persist();
      _notify();
    } on Object catch (error) {
      // No app storage here (a test host, a platform without the plugin):
      // nothing is offered offline and downloads report a storage failure.
      debugPrint('DownloadsRepository: no downloads folder: $error');
    }
  }

  static Future<void> _discard(File file) async {
    try {
      await file.delete();
    } on FileSystemException {
      // Already gone.
    }
  }

  DownloadedMessage? _find(String sermonId) {
    for (final saved in _saved()) {
      if (saved.sermon.id == sermonId) return saved;
    }
    return null;
  }

  List<DownloadedMessage> _saved() => _items ??= _load();

  List<DownloadedMessage> _load() {
    final raw = _cache.getPreference<Object?>(indexKey, null);
    if (raw is! String) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return [for (final entry in decoded) ?DownloadedMessage.fromJson(entry)]
        ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    } on FormatException {
      return [];
    }
  }

  void _persist() => _cache.cachePreference(
    indexKey,
    jsonEncode([for (final d in _saved()) d.toJson()]),
  );

  DownloadFailed _failed(String sermonId, DownloadFailureReason reason) {
    _failures[sermonId] = reason;
    _notify();
    return DownloadFailed(reason);
  }

  void _notify() {
    if (!_disposed) changes.value++;
  }
}
