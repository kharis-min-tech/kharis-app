import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/providers/notification_feed_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

import 'announcement_detail.dart';
import '../screens/clip_player_screen.dart';

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
/// 1. the channel's best Shorts ([heroShortsProvider]: the Senior Pastor's
///    sayings and longer previews), else the Studio's featured clip
///    ([featuredVideoProvider]);
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
  final shorts = ref.watch(heroShortsProvider);
  final video = ref.watch(featuredVideoProvider);
  final events = ref.watch(campusUpcomingEventsProvider);
  final news = ref.watch(campusNewsProvider);
  final feeds = <AsyncValue<Object?>>[shorts, video, events, news];
  if (feeds.any((f) => !f.hasValue && !f.hasError)) return const [];

  final flyers = [...?events.valueOrNull?.where((e) => e.imageUrl != null)]
    ..sort((a, b) {
      if (a.isFeatured != b.isFeatured) return a.isFeatured ? -1 : 1;
      return a.startTime.compareTo(b.startTime);
    });
  final shownEvents = flyers.take(kHeroEventLimit).toList();
  final shownEventIds = {for (final e in shownEvents) e.id};

  final slides = <HeroSlide>[
    if (shorts.valueOrNull case final clips? when clips.isNotEmpty)
      for (final clip in clips) VideoHeroSlide(clip)
    else if (video.valueOrNull case final clip?)
      VideoHeroSlide(clip),
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

/// Builds the live clip for [videoId], muted while `muted` is true (it
/// starts muted). It must call `onPlaying` with `true` while frames are
/// moving and `false` in every other state (loading, buffering, paused,
/// ended, failed); the hero keeps the thumbnail over it until `true`.
typedef HeroVideoSurfaceBuilder =
    Widget Function(String videoId, bool muted, ValueChanged<bool> onPlaying);

/// The hero's live clip. Null shows the thumbnail only: on web, where the
/// iframe player's platform view fails silently in release builds (see
/// `YoutubeWebEmbed`), and in tests.
final heroVideoSurfaceProvider = Provider<HeroVideoSurfaceBuilder?>(
  (ref) => kIsWeb
      ? null
      : (videoId, muted, onPlaying) => _YoutubeHeroSurface(
          videoId: videoId,
          muted: muted,
          onPlaying: onPlaying,
        ),
);

/// Neutral backdrop behind the media: flyers are letterboxed on it, never
/// cropped, and the status bar's light icons stay legible over it.
const Color _kBackdrop = AppColors.surfaceDark;

/// Height of the hero: 62% of the screen (clamped for landscape phones and
/// tablets), so the greeting and Today show on the first screen. The media
/// fills the width at its own shape from the top; its lower part fades into
/// the page, as on the Kharis website.
double homeHeroMediaHeight(Size screen) =>
    (screen.height * 0.62).clamp(260.0, 600.0);

/// Height of the band at the top of the media that the floating header
/// (logo and bell chips) occupies below the status bar.
const double kHeroTopBarExtent = 58;

// ── Hero ──────────────────────────────────────────────────────────────────────

/// Full-bleed paged banner at the very top of Home, under the status bar:
/// [slides] (see [homeHeroSlidesProvider]) with [topBar] floating over the
/// top, then page dots. The media carries no words: a slide opens on tap
/// (a video in the app's own full-screen player).
///
/// The clip plays (muted unless the member unmutes it) only while its slide
/// is current, the hero is [inView], Home is the visible tab with nothing
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
    this.scroll,
  });

  final List<HeroSlide> slides;
  final Widget topBar;

  /// Home's scroll: the media drifts up slower than the page and fades into
  /// it as the content rises (none in tests that host the hero alone).
  final ScrollController? scroll;

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

    final bg = context.kc.bg;

    // Everything stays inside the hero's box: the clip is a native view that
    // Flutter cannot paint over outside it, so nothing may overhang.
    return SizedBox(
      height: mediaHeight,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: mediaHeight,
            child: _ScrollFade(
              scroll: widget.scroll,
              distance: mediaHeight,
              background: bg,
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
                      bottomInset: 0,
                      active: canPlay && i == _index,
                      onPlayingChanged: (playing) => _videoPlaying = playing,
                      onOpen: () => _openSlide(context, ref, slides[i]),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // The media melts into the page where the content begins.
          Positioned(
            left: 0,
            right: 0,
            top: mediaHeight * 0.55,
            height: mediaHeight * 0.45,
            child: IgnorePointer(
              child: DecoratedBox(
                key: const Key('home-hero-fade'),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [bg.withValues(alpha: 0), bg],
                    stops: const [0, 0.78],
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
          if (slides.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 14,
              child: _HeroDots(
                count: slides.length,
                index: _index,
                animate: !_reduceMotion,
              ),
            ),
        ],
      ),
    );
  }
}

/// Moves [child] up at 40% of the page's speed and fades it into
/// [background] over [distance] of scroll: the hero drifts away behind the
/// content instead of scrolling off with it. A colour wash rather than
/// [Opacity], which the clip's platform view does not honour everywhere.
class _ScrollFade extends StatelessWidget {
  const _ScrollFade({
    required this.scroll,
    required this.distance,
    required this.background,
    required this.child,
  });

  final ScrollController? scroll;
  final double distance;
  final Color background;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scroll = this.scroll;
    if (scroll == null || MediaQuery.disableAnimationsOf(context)) {
      return child;
    }
    return AnimatedBuilder(
      animation: scroll,
      child: child,
      builder: (context, child) {
        final offset = scroll.hasClients
            ? scroll.offset.clamp(0.0, distance)
            : 0.0;
        // Reaches the page colour by 60% of the way, so no dim band of
        // video lingers behind the content.
        final t = distance <= 0
            ? 0.0
            : (offset / (distance * 0.6)).clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(0, offset * 0.4),
          child: Stack(
            fit: StackFit.expand,
            children: [
              child!,
              IgnorePointer(
                child: ColoredBox(color: background.withValues(alpha: t)),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// What tapping a slide does: the full video, the event detail, the
/// announcement, or the message in the player.
void _openSlide(BuildContext context, WidgetRef ref, HeroSlide slide) {
  switch (slide) {
    case VideoHeroSlide(:final video):
      // Played in the app, never handed to YouTube.
      unawaited(openClipPlayer(context, video));
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
    required this.bottomInset,
    required this.active,
    required this.onPlayingChanged,
    required this.onOpen,
  });

  final HeroSlide slide;

  /// Room left below a flyer for the title card that rises over the media.
  final double bottomInset;

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
        title: title,
        active: active,
        onPlayingChanged: onPlayingChanged,
        topInset: topInset,
        bottomInset: bottomInset,
      ),
      EventHeroSlide(:final event) => _FlyerMedia(
        url: event.imageUrl!,
        topInset: topInset,
        bottomInset: bottomInset,
      ),
      AnnouncementHeroSlide(:final item) => _FlyerMedia(
        url: usableMediaUrl(item.imageUrl)!,
        topInset: topInset,
        bottomInset: bottomInset,
      ),
      LatestMessageHeroSlide(:final sermon) => _FlyerMedia(
        url: usableMediaUrl(sermon.artworkUrl)!,
        topInset: topInset,
        bottomInset: bottomInset,
      ),
    };
    // The title is what a screen reader says for the slide; the words show
    // never on the media itself.
    return Semantics(
      container: true,
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
  const _FlyerMedia({
    required this.url,
    required this.topInset,
    required this.bottomInset,
  });

  final String url;
  final double topInset;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: topInset, bottom: bottomInset),
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

/// The featured clip filling the media, with its thumbnail over it whenever
/// the live surface is not playing (and while it is inactive or has
/// failed), and, while the clip is live, a mute toggle in the bottom-right
/// corner. The slide tap opens the full video.
///
/// The clip is always muted when it starts: going inactive (slide changed,
/// scrolled away, another tab, app in the background) resets it.
class _VideoMedia extends ConsumerStatefulWidget {
  const _VideoMedia({
    required this.video,
    required this.title,
    required this.active,
    required this.onPlayingChanged,
    required this.topInset,
    required this.bottomInset,
  });

  final FeaturedVideo video;

  /// Room kept clear for the floating header (landscape clips) and the
  /// title card, as for flyers.
  final double topInset;
  final double bottomInset;
  final String title;
  final bool active;
  final ValueChanged<bool> onPlayingChanged;

  @override
  ConsumerState<_VideoMedia> createState() => _VideoMediaState();
}

class _VideoMediaState extends ConsumerState<_VideoMedia> {
  bool _playing = false;
  bool _muted = true;

  /// Holds the thumbnail for [kHeroRevealDelay] after frames start moving,
  /// past the pause glyph YouTube flashes as playback begins.
  Timer? _reveal;

  @override
  void didUpdateWidget(_VideoMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Going inactive disposes the surface: the next activation starts on the
    // thumbnail again, and silent.
    if (!widget.active) {
      _reveal?.cancel();
      _playing = false;
      _muted = true;
    }
  }

  @override
  void dispose() {
    _reveal?.cancel();
    super.dispose();
  }

  void _onPlaying(bool playing) {
    if (!mounted || !widget.active) return;
    widget.onPlayingChanged(playing);
    _reveal?.cancel();
    if (!playing) {
      if (_playing) setState(() => _playing = false);
      return;
    }
    if (_playing) return;
    _reveal = Timer(kHeroRevealDelay, () {
      if (mounted && widget.active) setState(() => _playing = true);
    });
  }

  void _toggleMute() {
    if (_muted) {
      // One sound at a time: a message playing in the app pauses first.
      final audio = ref.read(audioPlayerServiceProvider);
      if (audio.currentSermon != null) unawaited(audio.pause());
    }
    setState(() => _muted = !_muted);
  }

  @override
  Widget build(BuildContext context) {
    final surface = widget.active ? ref.watch(heroVideoSurfaceProvider) : null;
    final ratio = widget.video.vertical ? 9 / 16 : 16 / 9;
    return Stack(
      fit: StackFit.expand,
      children: [
        // The clip whole, at its own shape, centred in the room left between
        // the floating header (landscape) and the title card: fitted, never
        // cropped or enlarged.
        Padding(
          padding: EdgeInsets.only(
            top: widget.video.vertical ? 0 : widget.topInset,
            bottom: widget.video.vertical ? 0 : widget.bottomInset,
          ),
          // A Short spans the full width from the top and runs past the
          // bottom (clipped there, under the fade); a landscape clip sits
          // whole in the middle.
          child: _FrameLayout(
            vertical: widget.video.vertical,
            ratio: ratio,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (surface != null)
                  IgnorePointer(
                    child: KeyedSubtree(
                      key: const Key('home-hero-video-surface'),
                      child: surface(widget.video.videoId, _muted, _onPlaying),
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
              ],
            ),
          ),
        ),
        if (surface != null)
          Positioned(
            right: 17,
            bottom: 16,
            child: _MuteButton(muted: _muted, onTap: _toggleMute),
          ),
      ],
    );
  }
}

/// Round surface chip, like the floating logo and bell, that mutes and
/// unmutes the clip inline. 48 px hit area around the 42 px circle.
class _MuteButton extends StatelessWidget {
  const _MuteButton({required this.muted, required this.onTap});

  final bool muted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    return Semantics(
      container: true,
      button: true,
      label: muted ? 'Unmute video' : 'Mute video',
      excludeSemantics: true,
      child: GestureDetector(
        key: const Key('home-hero-mute'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kc.surface,
              boxShadow: AppShadows.card,
            ),
            child: Icon(
              muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              color: kc.onBg,
              size: 21,
            ),
          ),
        ),
      ),
    );
  }
}

/// How long the thumbnail stays over a clip that has started playing, so
/// the pause glyph YouTube flashes at the start is never seen.
const Duration kHeroRevealDelay = Duration(seconds: 3);

/// How long before its end the clip jumps back to the start.
const Duration kHeroLoopLead = Duration(milliseconds: 1500);

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
  const _YoutubeHeroSurface({
    required this.videoId,
    required this.muted,
    required this.onPlaying,
  });

  final String videoId;

  /// Starts muted; flips sound inline without reloading the clip.
  final bool muted;
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
  late final StreamSubscription<YoutubeVideoState> _positions;

  /// The clip's length once the player has reported it.
  Duration _duration = Duration.zero;

  /// A loop seek is in flight; cleared once playback is back before the end.
  bool _looping = false;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      autoPlay: true,
      params: YoutubePlayerParams(
        mute: widget.muted,
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
    _positions = _controller.videoStateStream.listen(_onPosition);
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
    _duration = value.metaData.duration;
    // The thumbnail covers the surface whenever frames are not moving
    // (unstarted, buffering, paused, cued, ended, failed): YouTube draws its
    // own pause glyph, spinner or end screen in those states.
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
        // Backstop for a missed early loop.
        widget.onPlaying(false);
        _restart();
      default:
        widget.onPlaying(false);
    }
  }

  /// Loops [kHeroLoopLead] before the end, so YouTube's end screen ("More
  /// videos", related clips) never appears. The iframe's own `loop` only
  /// works for playlists.
  void _onPosition(YoutubeVideoState state) {
    final duration = _duration;
    if (duration <= kHeroLoopLead) return;
    final nearEnd = state.position >= duration - kHeroLoopLead;
    if (nearEnd && !_looping) {
      _looping = true;
      _restart();
    } else if (!nearEnd) {
      _looping = false;
    }
  }

  void _restart() {
    unawaited(
      _controller
          .seekTo(seconds: 0, allowSeekAhead: true)
          .then((_) => _controller.playVideo())
          .catchError((Object _) {}),
    );
  }

  @override
  void didUpdateWidget(_YoutubeHeroSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.muted == oldWidget.muted) return;
    if (widget.muted) {
      unawaited(_controller.mute().catchError((Object _) {}));
    } else {
      unawaited(
        _controller
            .unMute()
            .then((_) => _controller.setVolume(100))
            .catchError((Object _) {}),
      );
    }
  }

  @override
  void dispose() {
    unawaited(_values.cancel());
    unawaited(_positions.cancel());
    unawaited(_controller.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller.webViewController);
  }
}

/// Lays out the hero's clip: a vertical Short at the full width from the
/// top (taller than the hero; the hero clips it), a landscape clip fitted
/// whole and centred.
class _FrameLayout extends StatelessWidget {
  const _FrameLayout({
    required this.vertical,
    required this.ratio,
    required this.child,
  });

  final bool vertical;
  final double ratio;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final frame = KeyedSubtree(
      key: const Key('home-hero-video-frame'),
      child: child,
    );
    if (!vertical) {
      return Center(
        child: AspectRatio(aspectRatio: ratio, child: frame),
      );
    }
    return LayoutBuilder(
      builder: (context, box) {
        final height = box.maxWidth / ratio;
        return ClipRect(
          child: OverflowBox(
            alignment: Alignment.topCenter,
            minWidth: box.maxWidth,
            maxWidth: box.maxWidth,
            minHeight: height,
            maxHeight: height,
            child: frame,
          ),
        );
      },
    );
  }
}

// ── Dots ──────────────────────────────────────────────────────────────────────

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
