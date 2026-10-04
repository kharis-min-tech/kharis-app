import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:kharis_app/core/constants/app_links.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/calendar/presentation/screens/event_detail_screen.dart';
import 'package:kharis_app/features/home/data/news_repository.dart';
import 'package:kharis_app/features/home/presentation/screens/notifications_screen.dart';
import 'package:kharis_app/features/home/presentation/widgets/announcement_detail.dart';
import 'package:kharis_app/features/player/presentation/screens/media_player_screen.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/notification_feed_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

/// How long a shared link waits for its item before saying it can't find
/// it. The lookups report "still loading" while the archive fills or the
/// network is down, and a link must never spin forever.
const Duration kSharedLinkLookupTimeout = Duration(seconds: 20);

/// How long a message link waits for the audio recording of a video-only
/// match while the archive is still filling (see [SharedMessageScreen]).
const Duration kSharedLinkTwinWait = Duration(seconds: 8);

/// Where a message link leaves the member once the player closes.
const String kSharedMessageHome = '/messages';

/// Whether the sermon archive is still filling, so an id may yet resolve to
/// a fuller variant (see [SharedMessageScreen]).
final sharedLinkArchiveFillingProvider = Provider.autoDispose<bool>(
  (ref) => ref.watch(sermonLibraryProvider).isFilling,
);

/// The routes every link the app shares opens ([AppLinks]): on iOS/Android
/// through universal / App Links (cold start included), on the web app at
/// the same URL. Each resolves its id and opens the item; an id that does
/// not resolve gets [SharedLinkNotFoundScreen], with a way Home.
final List<RouteBase> sharedLinkRoutes = [
  GoRoute(
    path: '/${AppLinks.messageSegment}/:id',
    builder: (context, state) => SharedMessageScreen(
      id: state.pathParameters['id']!,
      startAt: AppLinks.parseTime(
        state.uri.queryParameters[AppLinks.timeParam],
      ),
      video: AppLinks.parseVideo(
        state.uri.queryParameters[AppLinks.videoParam],
      ),
    ),
  ),
  GoRoute(
    path: '/${AppLinks.eventSegment}/:id',
    builder: (context, state) =>
        SharedEventScreen(id: state.pathParameters['id']!),
  ),
  GoRoute(
    path: '/${AppLinks.announcementSegment}/:id',
    builder: (context, state) =>
        SharedAnnouncementScreen(id: state.pathParameters['id']!),
  ),
];

/// The live announcement [id]: from the member's campus feed first, then the
/// unscoped feed (a link shared by someone at another campus). Loading while
/// either feed could still hold it; `AsyncData(null)` once neither does.
final sharedAnnouncementProvider = Provider.autoDispose
    .family<AsyncValue<NewsItem?>, String>((ref, id) {
      NewsItem? find(List<NewsItem>? items) {
        for (final item in items ?? const <NewsItem>[]) {
          if (item.id == id && item.isLive) return item;
        }
        return null;
      }

      final campus = ref.watch(campusNewsProvider);
      final mine = find(campus.valueOrNull);
      if (mine != null) return AsyncData(mine);
      final everyone = ref.watch(newsProvider(null));
      final other = find(everyone.valueOrNull);
      if (other != null) return AsyncData(other);
      return campus.isLoading || everyone.isLoading
          ? const AsyncLoading()
          : const AsyncData(null);
    });

// ── Message: /m/:id ───────────────────────────────────────────────────────────

/// Opens a shared message: resolves [id] through [sermonByIdProvider], then
/// lands on the Messages tab and opens the unified player on top of it, at
/// [startAt] and in video when [video] asked for it and the message has one.
/// Closing the player leaves the member in the app, never on an empty stack.
class SharedMessageScreen extends ConsumerStatefulWidget {
  const SharedMessageScreen({
    super.key,
    required this.id,
    this.startAt,
    this.video = false,
  });

  /// The message's canonical id (any id [sermonByIdProvider] resolves).
  final String id;

  /// Position on the AUDIO timeline.
  final Duration? startAt;

  /// Whether the link asks for the video.
  final bool video;

  @override
  ConsumerState<SharedMessageScreen> createState() =>
      _SharedMessageScreenState();
}

class _SharedMessageScreenState extends ConsumerState<SharedMessageScreen> {
  late Timer _timeout;
  bool _timedOut = false;
  bool _opened = false;

  /// Bounds the wait for a video-only variant's audio twin (see [build]).
  Timer? _twinWait;
  bool _twinWaitOver = false;

  @override
  void initState() {
    super.initState();
    _armTimeout();
  }

  void _armTimeout() {
    _timedOut = false;
    _timeout = Timer(kSharedLinkLookupTimeout, () {
      if (mounted) setState(() => _timedOut = true);
    });
  }

  @override
  void dispose() {
    _timeout.cancel();
    _twinWait?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lookup = ref.watch(sermonByIdProvider(widget.id));
    final sermon = lookup.valueOrNull;
    if (sermon != null) {
      // While the archive is still filling, a `yt_` id can resolve to the
      // video-only feed entry before its audio recording is known. That
      // recording decides audio-first and where the message sits inside a
      // full-service video (what `t` is measured against), so give it a
      // moment to arrive.
      final awaitingTwin =
          !sermon.hasAudio &&
          sermon.hasVideo &&
          ref.watch(sharedLinkArchiveFillingProvider) &&
          !_twinWaitOver;
      if (!awaitingTwin) {
        _open(sermon);
      } else {
        _twinWait ??= Timer(kSharedLinkTwinWait, () {
          if (mounted) setState(() => _twinWaitOver = true);
        });
      }
      return const _Opening(label: 'Opening message');
    }
    if (lookup.isLoading && !_timedOut) {
      return const _Opening(label: 'Opening message');
    }
    return SharedLinkNotFoundScreen(
      title: 'We couldn\u2019t find that message',
      onRetry: () {
        ref.invalidate(sermonByIdProvider(widget.id));
        setState(_armTimeout);
      },
    );
  }

  void _open(Sermon sermon) {
    if (_opened) return;
    _opened = true;
    _timeout.cancel();
    _twinWait?.cancel();
    final queue = ref.read(sermonsProvider).valueOrNull ?? const <Sermon>[];
    final player = MaterialPageRoute<void>(
      builder: (_) => MediaPlayerScreen(
        sermon: sermon,
        mode: widget.video ? MediaMode.video : null,
        queue: queue,
        startAt: widget.startAt,
      ),
    );
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      goThenPush(GoRouter.of(context), kSharedMessageHome, player);
    });
  }
}

/// Replaces the stack with [location], then pushes [route] above it once the
/// router has built [location], so popping [route] lands there. A route
/// pushed before the rebuild would be dropped with the page it sat on.
@visibleForTesting
void goThenPush(GoRouter router, String location, Route<void> route) {
  router.go(location);
  void pushWhenSettled(int framesLeft) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      final settled =
          router.routerDelegate.currentConfiguration.uri.path == location;
      if (!settled && framesLeft > 0) {
        pushWhenSettled(framesLeft - 1);
        return;
      }
      unawaited(router.routerDelegate.navigatorKey.currentState?.push(route));
    });
    SchedulerBinding.instance.scheduleFrame();
  }

  pushWhenSettled(10);
}

// ── Event: /e/:id ─────────────────────────────────────────────────────────────

/// Opens a shared event in [EventDetailScreen]; an id that does not resolve
/// gets [SharedLinkNotFoundScreen].
class SharedEventScreen extends ConsumerWidget {
  const SharedEventScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lookup = ref.watch(eventByIdProvider(id));
    final event = lookup.valueOrNull;
    if (event == null && !lookup.isLoading) {
      return SharedLinkNotFoundScreen(
        title: 'We couldn\u2019t find that event',
        onRetry: () => ref.invalidate(eventByIdProvider(id)),
      );
    }
    // While loading the detail screen paints its own skeleton.
    return EventDetailScreen(eventId: id, initial: event);
  }
}

// ── Announcement: /a/:id ──────────────────────────────────────────────────────

/// Opens a shared announcement over the announcements list, exactly as a tap
/// in the feed does ([openAnnouncement]): its full text, or the event it
/// promotes. Back from the list goes Home.
class SharedAnnouncementScreen extends ConsumerStatefulWidget {
  const SharedAnnouncementScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<SharedAnnouncementScreen> createState() =>
      _SharedAnnouncementScreenState();
}

class _SharedAnnouncementScreenState
    extends ConsumerState<SharedAnnouncementScreen> {
  late Timer _timeout;
  bool _timedOut = false;
  bool _opened = false;

  @override
  void initState() {
    super.initState();
    _armTimeout();
  }

  void _armTimeout() {
    _timedOut = false;
    _timeout = Timer(kSharedLinkLookupTimeout, () {
      if (mounted) setState(() => _timedOut = true);
    });
  }

  @override
  void dispose() {
    _timeout.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lookup = ref.watch(sharedAnnouncementProvider(widget.id));
    final item = lookup.valueOrNull;
    if (item != null || _opened) {
      if (item != null) _open(item);
      return const NotificationsScreen.announcements();
    }
    if (lookup.isLoading && !_timedOut) {
      return const _Opening(label: 'Opening announcement');
    }
    return SharedLinkNotFoundScreen(
      title: 'We couldn\u2019t find that announcement',
      message:
          'It may have ended or been removed. If you\u2019re offline, '
          'check your connection and try again.',
      onRetry: () {
        ref.invalidate(newsProvider(null));
        unawaited(refreshCampusContent(ref));
        setState(_armTimeout);
      },
    );
  }

  void _open(NewsItem item) {
    if (_opened) return;
    _opened = true;
    _timeout.cancel();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(openAnnouncement(context, item));
    });
  }
}

// ── Shared pieces ─────────────────────────────────────────────────────────────

/// Back that never dead-ends: pops when there is somewhere to go, else Home.
void _backOrHome(BuildContext context) {
  final router = GoRouter.of(context);
  router.canPop() ? router.pop() : router.go('/home');
}

class _Opening extends StatelessWidget {
  const _Opening({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: Icon(Icons.arrow_back_rounded, color: context.kc.onBg),
          onPressed: () => _backOrHome(context),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: context.kc.accentInk,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              label,
              style: AppTypography.bodySm.copyWith(color: context.kc.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// What a shared link shows when its item cannot be found: what happened,
/// a way Home and, when given, a retry. Never a dead end.
class SharedLinkNotFoundScreen extends StatelessWidget {
  const SharedLinkNotFoundScreen({
    super.key,
    required this.title,
    this.message =
        'It may have been removed, or the link may be incomplete. If '
        'you\u2019re offline, check your connection and try again.',
    this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: Icon(Icons.arrow_back_rounded, color: context.kc.onBg),
          onPressed: () => _backOrHome(context),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.link_off_rounded, color: context.kc.muted, size: 44),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTypography.ui(
                  size: 17,
                  weight: FontWeight.w600,
                ).copyWith(color: context.kc.onBg),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTypography.bodySm.copyWith(color: context.kc.muted),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                key: const Key('shared-link-home'),
                style: FilledButton.styleFrom(
                  backgroundColor: context.kc.accent,
                  foregroundColor: context.kc.onAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.button),
                  ),
                ),
                onPressed: () => context.go('/home'),
                child: const Text('Go to Home'),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: AppSpacing.xs),
                TextButton(
                  onPressed: onRetry,
                  child: Text(
                    'Try again',
                    style: AppTypography.bodySm.copyWith(
                      color: context.kc.accentInk,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
