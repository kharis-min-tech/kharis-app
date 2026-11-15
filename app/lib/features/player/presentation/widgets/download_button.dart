import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/downloads_provider.dart';
import 'package:kharis_app/ui/components/components.dart';

/// Saves the message's audio for offline listening, from the player.
///
/// - Not downloaded: "Download message" starts the download.
/// - Downloading: a progress ring around a close icon; a tap cancels.
/// - Downloaded: a check on a filled plate; a tap offers "Remove download"
///   in a small sheet.
/// - Failed: one line saying why, then back to not downloaded.
///
/// Draws nothing for a message with no audio recording.
class DownloadButton extends ConsumerStatefulWidget {
  const DownloadButton({super.key, required this.sermon});

  final Sermon sermon;

  /// What the member is told when a download fails, by reason.
  static String failureMessage(DownloadFailureReason reason) =>
      switch (reason) {
        DownloadFailureReason.noAudio =>
          'This message has no audio to download.',
        DownloadFailureReason.noSpace =>
          'Your phone is out of storage. Free some space and try again.',
        DownloadFailureReason.connection =>
          'Couldn\u2019t download. Check your connection and try again.',
        DownloadFailureReason.server =>
          'This message can\u2019t be downloaded right now. Try again later.',
        DownloadFailureReason.storage =>
          'Couldn\u2019t save the download. Try again.',
        DownloadFailureReason.unsupported =>
          'Downloads aren\u2019t available on this device.',
      };

  @override
  ConsumerState<DownloadButton> createState() => _DownloadButtonState();
}

class _DownloadButtonState extends ConsumerState<DownloadButton> {
  String get _id => widget.sermon.id;

  @override
  void initState() {
    super.initState();
    // A failure left from before this screen opened is reported once too.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reportFailure(ref.read(downloadStatusProvider(_id)));
    });
  }

  /// Says why the download failed, then forgets the failure so the button
  /// offers the download again.
  void _reportFailure(DownloadStatus status) {
    if (status is! DownloadFailed) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(DownloadButton.failureMessage(status.reason)),
        behavior: SnackBarBehavior.floating,
      ),
    );
    ref.read(downloadsRepositoryProvider).clearFailure(_id);
  }

  void _offerRemoval() {
    final repository = ref.read(downloadsRepositoryProvider);
    final id = _id;
    unawaited(
      showKBottomSheet<void>(
        context: context,
        title: 'Downloaded',
        builder: (sheetContext) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.sermon.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: KharisText.meta.copyWith(color: sheetContext.k.muted),
            ),
            const SizedBox(height: KSpace.x3),
            KButton(
              key: const Key('player-download-remove'),
              label: 'Remove download',
              variant: KButtonVariant.outline,
              expand: true,
              onPressed: () {
                Navigator.of(sheetContext).pop();
                unawaited(repository.delete(id));
              },
            ),
            const SizedBox(height: KSpace.md),
            KButton(
              label: 'Keep download',
              variant: KButtonVariant.text,
              expand: true,
              onPressed: () => Navigator.of(sheetContext).pop(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sermon = widget.sermon;
    if (!sermon.hasAudio) return const SizedBox.shrink();

    ref.listen<DownloadStatus>(
      downloadStatusProvider(_id),
      (_, next) => _reportFailure(next),
    );
    final status = ref.watch(downloadStatusProvider(_id));
    final repository = ref.read(downloadsRepositoryProvider);
    final k = context.k;

    return switch (status) {
      Downloading(:final fraction) => Semantics(
        button: true,
        label: 'Cancel download',
        value: fraction == null
            ? 'Downloading'
            : '${(fraction * 100).round()}% downloaded',
        onTap: () => repository.cancel(_id),
        excludeSemantics: true,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.square(
              dimension: KSize.chip,
              child: CircularProgressIndicator(
                key: const Key('player-download-progress'),
                value: fraction,
                strokeWidth: KSize.tabUnderline,
                color: k.primary,
                backgroundColor: k.surface2,
              ),
            ),
            KIconButton(
              key: const Key('player-download'),
              icon: KIcons.close,
              label: 'Cancel download',
              onPressed: () => repository.cancel(_id),
            ),
          ],
        ),
      ),
      Downloaded() => KIconButton(
        key: const Key('player-download'),
        icon: KIcons.check,
        label: 'Downloaded',
        variant: KIconButtonVariant.filled,
        onPressed: _offerRemoval,
      ),
      NotDownloaded() || DownloadFailed() => KIconButton(
        key: const Key('player-download'),
        icon: KIcons.download,
        label: 'Download message',
        onPressed: () => unawaited(repository.download(sermon)),
      ),
    };
  }
}
