import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:kharis_app/features/player/presentation/playback_launcher.dart';
import 'package:kharis_app/features/player/presentation/widgets/download_button.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/clock_provider.dart';
import 'package:kharis_app/shared/providers/downloads_provider.dart';
import 'package:kharis_app/shared/providers/notification_feed_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';
import 'package:kharis_app/shared/widgets/branch_picker_sheet.dart';
import 'package:kharis_app/ui/components/components.dart';

/// How long the newest message counts as "New from Sunday".
const Duration kNewFromSundayWindow = Duration(days: 7);

/// The message Home's hero leads with: the newest in the library.
final homeHeroMessageProvider = Provider<Sermon?>(
  (ref) => ref.watch(latestSermonsProvider).firstOrNull,
);

/// "58 min", "1 hr 5 min"; null when the length is unknown.
String? heroDurationLabel(Duration? duration) {
  if (duration == null || duration <= Duration.zero) return null;
  final minutes = (duration.inSeconds / 60).round().clamp(1, 1 << 20);
  if (minutes < 60) return '$minutes min';
  final rest = minutes % 60;
  return rest == 0 ? '${minutes ~/ 60} hr' : '${minutes ~/ 60} hr $rest min';
}

/// The account's real first name, or null for the placeholder names the
/// auth layer gives guests and nameless sign-ins ("Guest", "Member").
String? _firstName(String? displayName) {
  final name = displayName?.trim() ?? '';
  if (name.isEmpty || name == 'Guest' || name == 'Member') return null;
  return name.split(RegExp(r'\s+')).first;
}

/// The top of Home, on ink under the status bar: the greeting with the
/// branch switcher, the bell and the member's avatar, then the newest
/// message with Listen, Watch and its download. [bottomInset] is the room
/// the stats strip overlapping its bottom edge takes.
class HomeHero extends ConsumerWidget {
  const HomeHero({super.key, this.bottomInset = 0});

  final double bottomInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sermon = ref.watch(homeHeroMessageProvider);
    final loading = sermon == null && ref.watch(sermonsProvider).isLoading;
    final artwork = sermon?.artworkUrl?.trim();
    final image = artwork == null || artwork.isEmpty
        ? null
        : CachedNetworkImageProvider(artwork);

    return KHomeHero(
      bottomInset: bottomInset,
      backdrop: image,
      header: const _Header(),
      message: sermon != null
          ? _Message(sermon: sermon, artwork: image)
          : loading
          ? const KHeroMessageSkeleton(key: Key('home-hero-loading'))
          : null,
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header();

  String _greeting(DateTime now) {
    if (now.hour < 12) return 'Good morning';
    if (now.hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final branch =
        ref.watch(currentBranchProvider).valueOrNull ??
        ((user?.branch?.isNotEmpty ?? false) ? user!.branch : null);
    final firstName = _firstName(user?.displayName);
    final greeting = _greeting(ref.watch(clockProvider)());
    final pending = ref.watch(hasPendingNotificationsProvider);

    return Row(
      children: [
        Expanded(
          child: KHeroGreeting(
            greeting: firstName == null ? greeting : '$greeting, $firstName',
            branchLabel: branch ?? 'Choose your branch',
            branchSemanticLabel: branch == null
                ? 'Choose your branch'
                : 'Change branch, now $branch',
            branchKey: const Key('home-branch-change'),
            onBranch: () => pickActiveBranch(context, ref),
          ),
        ),
        const SizedBox(width: KSpace.lg),
        // Same route as a push tap, so Back behaves the same either way.
        KHeroRoundButton(
          key: const Key('home-bell'),
          icon: KIcons.bell,
          label: pending ? 'Notifications, new items' : 'Notifications',
          dot: pending,
          dotKey: const Key('home-bell-unread-dot'),
          onPressed: () => context.push('/notifications'),
        ),
        if (firstName != null) ...[
          const SizedBox(width: KSpace.md),
          KHeroRoundButton(
            key: const Key('home-avatar'),
            initial: firstName.characters.first.toUpperCase(),
            label: 'Your profile',
            onPressed: () => context.go('/more'),
          ),
        ],
      ],
    );
  }
}

class _Message extends ConsumerWidget {
  const _Message({required this.sermon, required this.artwork});

  final Sermon sermon;
  final ImageProvider? artwork;

  void _download(BuildContext context, WidgetRef ref, DownloadStatus status) {
    final repository = ref.read(downloadsRepositoryProvider);
    switch (status) {
      case Downloading():
        repository.cancel(sermon.id);
      case Downloaded():
        unawaited(context.push('/downloads'));
      case NotDownloaded() || DownloadFailed():
        final messenger = ScaffoldMessenger.maybeOf(context);
        unawaited(
          repository.download(sermon).then((result) {
            if (result is! DownloadFailed) return;
            repository.clearFailure(sermon.id);
            messenger?.showSnackBar(
              SnackBar(
                content: Text(DownloadButton.failureMessage(result.reason)),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }),
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final published = sermon.publishedAt;
    final isNew =
        published != null &&
        ref.watch(clockProvider)().difference(published) <=
            kNewFromSundayWindow;
    final speaker = sermon.speaker.trim();
    final length = heroDurationLabel(sermon.duration);
    final status = ref.watch(downloadStatusProvider(sermon.id));

    return KHeroMessage(
      badge: isNew ? 'New from Sunday' : 'Latest message',
      title: sermon.title,
      lines: [if (speaker.isNotEmpty) speaker, ?length],
      artwork: artwork,
      artworkSemanticLabel: speaker.isEmpty
          ? sermon.title
          : '${sermon.title}, with $speaker',
      listenKey: const Key('home-hero-listen'),
      watchKey: const Key('home-hero-watch'),
      downloadKey: const Key('home-hero-download'),
      onListen: sermon.hasAudio
          ? () => unawaited(
              startPlayback(context, ref, sermon, mode: MediaMode.audio),
            )
          : null,
      onWatch: sermon.hasVideo
          ? () => unawaited(
              startPlayback(context, ref, sermon, mode: MediaMode.video),
            )
          : null,
      onDownload: sermon.hasAudio
          ? () => _download(context, ref, status)
          : null,
      downloadState: switch (status) {
        Downloading() => KHeroDownloadState.downloading,
        Downloaded() => KHeroDownloadState.done,
        NotDownloaded() || DownloadFailed() => KHeroDownloadState.idle,
      },
      downloadProgress: status is Downloading ? status.fraction : null,
      downloadLabel: switch (status) {
        Downloading() => 'Cancel download',
        Downloaded() => 'Downloaded. Open downloads',
        NotDownloaded() || DownloadFailed() => 'Download ${sermon.title}',
      },
    );
  }
}
