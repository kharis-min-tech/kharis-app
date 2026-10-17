import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/core/utils/media_url.dart';
import 'package:kharis_app/features/calendar/data/event_repository.dart';
import 'package:kharis_app/features/calendar/presentation/widgets/event_card.dart';
import 'package:kharis_app/features/home/data/featured_video_repository.dart';
import 'package:kharis_app/features/home/data/news_repository.dart';
import 'package:kharis_app/features/player/presentation/playback_launcher.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/notification_feed_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

import 'announcement_detail.dart';
import 'upcoming_events_strip.dart';

// ── Slides ────────────────────────────────────────────────────────────────────

/// One page of the Home hero.
sealed class HeroSlide {
  const HeroSlide();

  /// Stable id: the kind plus the Studio id.
  String get id;
}

/// The Studio's featured clip: a muted, looping preview.
final class VideoHeroSlide extends HeroSlide {
  const VideoHeroSlide(this.video);
  final FeaturedVideo video;
  @override
  String get id => 'video:${video.videoId}';
}

/// An upcoming event's flyer.
final class EventHeroSlide extends HeroSlide {
  const EventHeroSlide(this.event);
  final Event event;
  @override
  String get id => 'event:${event.id}';
}

/// An announcement's image.
final class AnnouncementHeroSlide extends HeroSlide {
  const AnnouncementHeroSlide(this.item);
  final NewsItem item;
  @override
  String get id => 'news:${item.id}';
}

/// The newest message's artwork, when the Studio has nothing else to show.
final class LatestMessageHeroSlide extends HeroSlide {
  const LatestMessageHeroSlide(this.sermon);
  final Sermon sermon;
  @override
  String get id => 'message:${sermon.id}';
}

/// Most event flyers the hero carries; the strip below has the rest.
const int kHeroEventLimit = 3;

/// Most announcement images the hero carries; the carousel has the rest.
const int kHeroAnnouncementLimit = 3;

/// How long an image slide stays before the hero moves on.
const Duration kHeroAdvanceInterval = Duration(seconds: 6);

/// The hero's slides, in order:
/// 1. the Studio's featured clip ([featuredVideoProvider]);
/// 2. up to [kHeroEventLimit] upcoming events with a flyer, from the same
///    app-visible, Branch-scoped feed as the events strip, featured first and
///    then soonest;
/// 3. up to [kHeroAnnouncementLimit] live announcements with an image,
///    skipping one that promotes an event already shown as a flyer;
/// 4. only when none of those exist, the newest message's artwork.
///
/// Empty while any of the Studio feeds is still loading (so the fallback or
/// a partial set never flashes first) and when there is nothing to show:
/// Home then hides the hero.
final homeHeroSlidesProvider = Provider<List<HeroSlide>>((ref) {
  final video = ref.watch(featuredVideoProvider);
  final events = ref.watch(campusUpcomingEventsProvider);
  final news = ref.watch(campusNewsProvider);
  final feeds = <AsyncValue<Object?>>[video, events, news];
  if (feeds.any((f) => !f.hasValue && !f.hasError)) return const [];

  final flyers = [...?events.valueOrNull?.where((e) => e.imageUrl != null)]
    ..sort((a, b) {
      if (a.isFeatured != b.isFeatured) return a.isFeatured ? -1 : 1;
      return a.startTime.compareTo(b.startTime);
    });
  final shownEvents = flyers.take(kHeroEventLimit).toList();
  final shownEventIds = {for (final e in shownEvents) e.id};

  final slides = <HeroSlide>[
    if (video.valueOrNull case final clip?) VideoHeroSlide(clip),
    for (final event in shownEvents) EventHeroSlide(event),
    ...(news.valueOrNull ?? const <NewsItem>[])
        .where(
          (n) =>
              usableMediaUrl(n.imageUrl) != null &&
              !shownEventIds.contains(n.eventId?.trim()),
        )
        .take(kHeroAnnouncementLimit)
        .map(AnnouncementHeroSlide.new),
  ];
  if (slides.isNotEmpty) return slides;

  final latest = ref.watch(latestSermonsProvider).firstOrNull;
  if (latest == null || usableMediaUrl(latest.artworkUrl) == null) {
    return const [];
  }
  return [LatestMessageHeroSlide(latest)];
});

// ── Video surface ─────────────────────────────────────────────────────────────

/// Builds the live clip for [videoId]. It must call [onPlaying] with `true`
/// once frames are showing and `false` when playback stops or fails; until
/// then the hero keeps the thumbnail over it.
typedef HeroVideoSurfaceBuilder =
    Widget Function(String videoId, ValueChanged<bool> onPlaying);

/// The hero's live clip. Null shows the thumbnail only: on web, where the
/// iframe player's platform view fails silently in release builds (see
/// `YoutubeWebEmbed`), and in tests.
final heroVideoSurfaceProvider = Provider<HeroVideoSurfaceBuilder?>(
  (ref) => kIsWeb
      ? null
      : (videoId, onPlaying) =>
            _YoutubeHeroSurface(videoId: videoId, onPlaying: onPlaying),
);

/// Neutral backdrop behind the media: flyers are letterboxed on it, never
/// cropped, and the status bar's light icons stay legible over it.
const Color _kBackdrop = AppColors.surfaceDark;

/// Height of the hero's media: about 58% of a phone's screen, clamped so a
/// landscape phone keeps some list and a tablet is not all banner.
double homeHeroMediaHeight(Size screen) =>
    (screen.height * 0.58).clamp(260.0, 560.0);

/// Height of the band at the top of the media that the floating header
/// (logo and bell chips) occupies below the status bar.
const double kHeroTopBarExtent = 58;

// ── Hero ──────────────────────────────────────────────────────────────────────

/// Full-bleed paged banner at the very top of Home, under the status bar:
/// [slides] (see [homeHeroSlidesProvider]) with [topBar] floating over the
/// top, then the current slide's title, date and action below the media,
/// then page dots.
///
/// Text never sits on the media. The clip plays only while its slide is
/// current, the hero is [inView], Home is the visible tab with nothing
/// pushed over it ([TickerMode]), the app is in the foreground, and the
/// member has not asked for reduced motion; otherwise it is disposed and the
/// thumbnail shows. Image slides advance every [kHeroAdvanceInterval] until
/// the member drags the pager.
class HomeHero extends ConsumerStatefulWidget {
  const HomeHero({
    super.key,
    required this.slides,
    required this.topBar,
    this.inView = true,
  });

  final List<HeroSlide> slides;
  final Widget topBar;

  /// False once Home has scrolled the media out of view.
  final bool inView;

  @override
  ConsumerState<HomeHero> createState() => _HomeHeroState();
}

class _HomeHeroState extends ConsumerState<HomeHero> {
  final _pages = PageController();
  late final AppLifecycleListener _lifecycle;
  Timer? _advance;
  int _index = 0;
  bool _foreground = true;
  bool _userDragged = false;
  bool _videoPlaying = false;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        final foreground = state == AppLifecycleState.resumed;
        if (foreground != _foreground) setState(() => _foreground = foreground);
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _scheduleAdvance();
  }

  @override
  void didUpdateWidget(HomeHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_index >= widget.slides.length) {
      _index = 0;
      _videoPlaying = false;
      if (_pages.hasClients) _pages.jumpToPage(0);
    }
    if (oldWidget.slides.length != widget.slides.length) _scheduleAdvance();
  }

  @override
  void dispose() {
    _advance?.cancel();
    _lifecycle.dispose();
    _pages.dispose();
    super.dispose();
  }

  void _scheduleAdvance() {
    _advance?.cancel();
    _advance = null;
    if (_userDragged || _reduceMotion || widget.slides.length < 2) return;
    _advance = Timer(kHeroAdvanceInterval, _onAdvance);
  }

  void _onAdvance() {
    if (!mounted) return;
    final current = widget.slides[_index];
    final hold =
        !_canPlay(context) || (current is VideoHeroSlide && _videoPlaying);
    if (hold || !_pages.hasClients) {
      _scheduleAdvance();
      return;
    }
    unawaited(
      _pages.animateToPage(
        (_index + 1) % widget.slides.length,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      ),
    );
  }

  /// Whether anything on the hero may move or play right now.
  bool _canPlay(BuildContext context) =>
      widget.inView &&
      _foreground &&
      !_reduceMotion &&
      TickerMode.valuesOf(context).enabled;

  bool _onPagerScroll(ScrollStartNotification n) {
    if (n.dragDetails != null && !_userDragged) {
      _userDragged = true;
      _advance?.cancel();
      _advance = null;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final slides = widget.slides;
    final padding = MediaQuery.paddingOf(context);
    final mediaHeight = homeHeroMediaHeight(MediaQuery.sizeOf(context));
    final canPlay = _canPlay(context);
    final current = slides[_index.clamp(0, slides.length - 1)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: mediaHeight,
          child: Stack(
            children: [
              Positioned.fill(
                child: ColoredBox(
                  color: _kBackdrop,
                  child: NotificationListener<ScrollStartNotification>(
                    onNotification: _onPagerScroll,
                    child: PageView.builder(
                      key: const Key('home-hero-pager'),
                      controller: _pages,
                      itemCount: slides.length,
                      onPageChanged: (i) {
                        setState(() {
                          _index = i;
                          _videoPlaying = false;
                        });
                        _scheduleAdvance();
                      },
                      itemBuilder: (context, i) => _SlideMedia(
                        key: ValueKey('home-hero-slide-${slides[i].id}'),
                        slide: slides[i],
                        topInset: padding.top + kHeroTopBarExtent,
                        active: canPlay && i == _index,
                        onPlayingChanged: (playing) => _videoPlaying = playing,
                        onOpen: () => _openSlide(context, ref, slides[i]),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: padding.top + 8,
                left: 20,
                right: 20,
                child: widget.topBar,
              ),
            ],
          ),
        ),
        _HeroCaption(
          slide: current,
          onOpen: () => _openSlide(context, ref, current),
        ),
        if (slides.length > 1)
          _HeroDots(
            count: slides.length,
            index: _index,
            animate: !_reduceMotion,
          ),
      ],
    );
  }
}

/// What tapping a slide (or its caption action) does: the full video, the
/// event detail, the announcement, or the message in the player.
void _openSlide(BuildContext context, WidgetRef ref, HeroSlide slide) {
  switch (slide) {
    case VideoHeroSlide(:final video):
      unawaited(
        launchUrl(
          Uri.parse(video.url),
          mode: LaunchMode.externalApplication,
        ).catchError((Object _) => false),
      );
    case EventHeroSlide(:final event):
      openEventDetail(context, event);
    case AnnouncementHeroSlide(:final item):
      unawaited(openAnnouncement(context, item));
    case LatestMessageHeroSlide(:final sermon):
      unawaited(startPlayback(context, ref, sermon));
  }
}

String _slideTitle(HeroSlide slide) => switch (slide) {
  VideoHeroSlide(:final video) => video.title,
  EventHeroSlide(:final event) => event.title,
  AnnouncementHeroSlide(:final item) => item.title,
  LatestMessageHeroSlide(:final sermon) => sermon.title,
};

// ── Media ─────────────────────────────────────────────────────────────────────

class _SlideMedia extends StatelessWidget {
  const _SlideMedia({
    super.key,
    required this.slide,
    required this.topInset,
    required this.active,
    required this.onPlayingChanged,
    required this.onOpen,
  });

  final HeroSlide slide;

  /// Room left above a flyer for the status bar and the floating header, so
  /// neither covers the flyer's own text.
  final double topInset;
  final bool active;
  final ValueChanged<bool> onPlayingChanged;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final title = _slideTitle(slide);
    final media = switch (slide) {
      VideoHeroSlide(:final video) => _VideoMedia(
        video: video,
        active: active,
        onPlayingChanged: onPlayingChanged,
        onPlay: onOpen,
      ),
      EventHeroSlide(:final event) => _FlyerMedia(
        url: event.imageUrl!,
        topInset: topInset,
      ),
      AnnouncementHeroSlide(:final item) => _FlyerMedia(
        url: usableMediaUrl(item.imageUrl)!,
        topInset: topInset,
      ),
      LatestMessageHeroSlide(:final sermon) => Stack(
        fit: StackFit.expand,
        children: [
          _FlyerMedia(
            url: usableMediaUrl(sermon.artworkUrl)!,
            topInset: topInset,
          ),
          Center(
            child: _PlayButton(label: 'Play $title', onTap: onOpen),
          ),
        ],
      ),
    };
    return Semantics(
      button: true,
      label: title,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onOpen,
        child: media,
      ),
    );
  }
}

/// A flyer or artwork whole, letterboxed on the backdrop; never cropped.
class _FlyerMedia extends StatelessWidget {
  const _FlyerMedia({required this.url, required this.topInset});

  final String url;
  final double topInset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: topInset),
      child: Image.network(
        url,
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => const SizedBox.expand(),
      ),
    );
  }
}

/// The featured clip filling the media: its thumbnail until the live
/// surface reports frames (and whenever it is inactive or has failed), with
/// the round play button opening the full video.
class _VideoMedia extends ConsumerStatefulWidget {
  const _VideoMedia({
    required this.video,
    required this.active,
    required this.onPlayingChanged,
    required this.onPlay,
  });

  final FeaturedVideo video;
  final bool active;
  final ValueChanged<bool> onPlayingChanged;
  final VoidCallback onPlay;

  @override
  ConsumerState<_VideoMedia> createState() => _VideoMediaState();
}

class _VideoMediaState extends ConsumerState<_VideoMedia> {
  bool _playing = false;

  @override
  void didUpdateWidget(_VideoMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Going inactive disposes the surface: the next activation starts on the
    // thumbnail again.
    if (!widget.active) _playing = false;
  }

  void _onPlaying(bool playing) {
    if (!mounted || !widget.active) return;
    widget.onPlayingChanged(playing);
    if (playing != _playing) setState(() => _playing = playing);
  }

  @override
  Widget build(BuildContext context) {
    final surface = widget.active ? ref.watch(heroVideoSurfaceProvider) : null;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (surface != null)
          IgnorePointer(
            child: _CoverBox(
              key: const Key('home-hero-video-surface'),
              child: surface(widget.video.videoId, _onPlaying),
            ),
          ),
        if (surface == null || !_playing)
          Image.network(
            widget.video.thumbnailUrl,
            key: const Key('home-hero-video-thumbnail'),
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => const SizedBox.expand(),
          ),
        Center(
          child: _PlayButton(
            label: 'Watch ${widget.video.title}',
            onTap: widget.onPlay,
          ),
        ),
      ],
    );
  }
}

/// Sizes a 16:9 child to cover the box (centred, overflow clipped) without
/// scaling it, so the platform view renders at its real size.
class _CoverBox extends StatelessWidget {
  const _CoverBox({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        const ratio = 16 / 9;
        final wide = box.maxWidth / box.maxHeight > ratio;
        final width = wide ? box.maxWidth : box.maxHeight * ratio;
        final height = wide ? box.maxWidth / ratio : box.maxHeight;
        return ClipRect(
          child: OverflowBox(
            minWidth: width,
            maxWidth: width,
            minHeight: height,
            maxHeight: height,
            child: child,
          ),
        );
      },
    );
  }
}

/// Round, surface-coloured play button.
class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        key: const Key('home-hero-play'),
        color: kc.surface,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 64,
            height: 64,
            child: Icon(Icons.play_arrow_rounded, size: 34, color: kc.onBg),
          ),
        ),
      ),
    );
  }
}

/// The muted, looping, control-less YouTube preview behind the hero's video
/// slide. One instance at most: the hero only builds it for the current,
/// visible slide, and it closes its controller when removed.
///
/// The controller's WebView is rendered inline rather than through the
/// package's [YoutubePlayer], which on mobile floats the WebView in an
/// overlay above the whole page: there it escaped the hero's
/// [IgnorePointer], swallowed vertical drags (Home would not scroll from the
/// clip) and covered the logo and bell.
class _YoutubeHeroSurface extends StatefulWidget {
  const _YoutubeHeroSurface({required this.videoId, required this.onPlaying});

  final String videoId;
  final ValueChanged<bool> onPlaying;

  @override
  State<_YoutubeHeroSurface> createState() => _YoutubeHeroSurfaceState();
}

class _YoutubeHeroSurfaceState extends State<_YoutubeHeroSurface> {
  /// Captions off for good: `cc_load_policy=0` only stops forcing them on,
  /// so a viewer default (or YouTube's muted-autoplay captions) still shows
  /// them unless the module is unloaded once playback has loaded it.
  static const _captionsOff = '''
try {
  player.unloadModule("captions");
  player.unloadModule("cc");
  player.setOption("captions", "track", {});
} catch (e) {}
''';

  late final YoutubePlayerController _controller;
  late final StreamSubscription<YoutubePlayerValue> _values;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      autoPlay: true,
      params: const YoutubePlayerParams(
        mute: true,
        showControls: false,
        showFullscreenButton: false,
        enableCaption: false,
        showVideoAnnotations: false,
        strictRelatedVideos: true,
        enableKeyboard: false,
        pointerEvents: PointerEvents.none,
        playsInline: true,
      ),
    );
    _values = _controller.stream.listen(_onValue);
    unawaited(
      _controller.webViewController
          .setBackgroundColor(_kBackdrop)
          .catchError((Object _) {}),
    );
    // Loads the player page; what [YoutubePlayer] would do on mount.
    unawaited(
      _controller
          .initWithParams(params: _controller.params)
          .catchError((Object _) => widget.onPlaying(false)),
    );
  }

  void _onValue(YoutubePlayerValue value) {
    if (value.error != YoutubeError.none) {
      widget.onPlaying(false);
      return;
    }
    switch (value.playerState) {
      case PlayerState.playing:
        unawaited(
          _controller.webViewController
              .runJavaScript(_captionsOff)
              .catchError((Object _) {}),
        );
        widget.onPlaying(true);
      case PlayerState.ended:
        // Loop: the iframe's own `loop` only works for playlists.
        unawaited(_controller.seekTo(seconds: 0, allowSeekAhead: true));
        unawaited(_controller.playVideo());
      default:
        break;
    }
  }

  @override
  void dispose() {
    unawaited(_values.cancel());
    unawaited(_controller.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller.webViewController);
  }
}

// ── Caption + dots ────────────────────────────────────────────────────────────

/// The current slide's kind, title and date (or speaker), with its action,
/// directly below the media.
class _HeroCaption extends StatelessWidget {
  const _HeroCaption({required this.slide, required this.onOpen});

  final HeroSlide slide;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    final (kicker, detail, action) = switch (slide) {
      VideoHeroSlide() => ('Featured video', null, 'Watch'),
      EventHeroSlide(:final event) => ('Event', eventWhenLabel(event), null),
      AnnouncementHeroSlide(:final item) => (item.type, null, null),
      LatestMessageHeroSlide(:final sermon) => (
        'Latest message',
        sermon.speaker.trim().isEmpty ? null : sermon.speaker.trim(),
        'Play',
      ),
    };
    return Padding(
      key: const Key('home-hero-caption'),
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onOpen,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    kicker.toUpperCase(),
                    style: AppTypography.ui(
                      size: 11,
                      weight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ).copyWith(color: kc.muted, height: 1.2),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _slideTitle(slide),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.display(
                      size: 20,
                      weight: FontWeight.w700,
                    ).copyWith(color: kc.onBg, height: 1.2),
                  ),
                  if (detail != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.ui(
                        size: 13,
                        weight: FontWeight.w500,
                      ).copyWith(color: kc.muted, height: 1.3),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (action != null)
            TextButton(
              key: const Key('home-hero-action'),
              onPressed: onOpen,
              style: TextButton.styleFrom(foregroundColor: kc.accentInk),
              child: Text(
                action,
                style: AppTypography.ui(
                  size: 14,
                  weight: FontWeight.w700,
                ).copyWith(color: kc.accentInk),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeroDots extends StatelessWidget {
  const _HeroDots({
    required this.count,
    required this.index,
    required this.animate,
  });

  final int count;
  final int index;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    return Padding(
      key: const Key('home-hero-dots'),
      padding: const EdgeInsets.only(top: 12),
      child: ExcludeSemantics(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < count; i++)
              AnimatedContainer(
                duration: animate
                    ? const Duration(milliseconds: 200)
                    : Duration.zero,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == index ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == index ? kc.accentInk : kc.outline,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
