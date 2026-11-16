import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/messages/data/downloads_repository.dart';
import 'cache_provider.dart';
import 'clock_provider.dart';

export '../../features/messages/data/downloads_repository.dart'
    show
        DownloadedMessage,
        DownloadFailureReason,
        DownloadStatus,
        NotDownloaded,
        Downloading,
        Downloaded,
        DownloadFailed;

/// Message audio saved on this device. Start, stop and remove through it:
/// `download(sermon)`, `cancel(sermonId)`, `delete(sermonId)`. The audio
/// player asks it for a message's file before it streams.
final downloadsRepositoryProvider = Provider<DownloadsRepository>((ref) {
  final repository = DownloadsRepository(
    ref.watch(cacheServiceProvider),
    clock: ref.watch(clockProvider),
  );
  ref.onDispose(repository.dispose);
  return repository;
});

/// Re-runs the watching provider whenever the repository changes.
DownloadsRepository _watchDownloads(Ref ref) {
  final repository = ref.watch(downloadsRepositoryProvider);
  void changed() => ref.invalidateSelf();
  repository.changes.addListener(changed);
  ref.onDispose(() => repository.changes.removeListener(changed));
  return repository;
}

/// Saved messages, most recently saved first, each with its size and the
/// date it was saved.
final downloadsProvider = Provider<List<DownloadedMessage>>(
  (ref) => _watchDownloads(ref).downloads(),
);

/// Where one message is with being saved: not saved, downloading (with
/// progress), saved, or failed (with the reason).
final downloadStatusProvider = Provider.autoDispose
    .family<DownloadStatus, String>(
      (ref, sermonId) => _watchDownloads(ref).statusOf(sermonId),
    );

/// Whether a message's audio is saved on this device.
final isDownloadedProvider = Provider.autoDispose.family<bool, String>(
  (ref, sermonId) => ref.watch(
    downloadStatusProvider(sermonId).select((status) => status is Downloaded),
  ),
);
