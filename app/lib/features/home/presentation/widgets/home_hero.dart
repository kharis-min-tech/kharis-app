import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/player/presentation/playback_launcher.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

// ── The wall's media ─────────────────────────────────────────────────────────

/// One card on the hero wall: a photo, or a looping silent video shown over
/// its poster. The same media, in the same order and rows, as the hero of
/// kharis.org, bundled with the app so Home looks the same on every launch.
@immutable
class HeroWallItem {
  const HeroWallItem.image(this.image, this.alt) : video = null;
  const HeroWallItem.video(this.video, {required String poster})
    : image = poster,
      alt = '';

  /// The photo, or the video's poster.
  final String image;

  /// A bundled MP4, or null for a photo.
  final String? video;

  final String alt;
}

const _dir = 'assets/hero';

/// Row one, left to right: the two videos and every other photo.
const List<HeroWallItem> kHeroWallTop = [
  HeroWallItem.video('$_dir/hero-a.mp4', poster: '$_dir/hero-a-poster.jpg'),
  HeroWallItem.image(
    '$_dir/sunday-service-stage.jpg',
    'Pastor raising his Bible on stage at Kharis Sunday Service',
  ),
  HeroWallItem.image(
    '$_dir/easter-bibles-raised.jpg',
    'The congregation raising their Bibles at the Easter service',
  ),
  HeroWallItem.video('$_dir/hero-b.mp4', poster: '$_dir/hero-b-poster.jpg'),
  HeroWallItem.image(
    '$_dir/impartation-celebration.jpg',
    'Pastor David celebrating with the congregation at the Impartation '
        'Service',
  ),
  HeroWallItem.image(
    '$_dir/easter-pastor-david.jpg',
    'Pastor David preaching at the Easter Saturday service',
  ),
  HeroWallItem.image(
    '$_dir/outreach-community.jpg',
    'Kharis community outreach day in a local playground',
  ),
];

/// Row two, left to right: the other photos.
const List<HeroWallItem> kHeroWallBottom = [
  HeroWallItem.image(
    '$_dir/worship-altar.jpg',
    'The congregation worshipping at the altar during a Kharis service',
  ),
  HeroWallItem.image(
    '$_dir/preaching-open-bible.jpg',
    'Preaching with arms outstretched and an open Bible in hand',
  ),
  HeroWallItem.image(
    '$_dir/outreach-street.jpg',
    'Kharis outreach team sharing the gospel on the street',
  ),
  HeroWallItem.image(
    '$_dir/sunday-bible-raised.jpg',
    'A worshipper raising her Bible at a Sunday service',
  ),
];

/// Seconds each row takes to move one card along (as on kharis.org).
const List<double> kHeroWallSecondsPerCard = [6, 7.5];

/// A card's width as a share of the screen's.
const double kHeroWallCardWidth = 0.8;

/// Space between rows and between cards.
const double kHeroWallGap = 12;

/// The wall's colour behind and between the cards.
const Color kHeroWallBackground = Color(0xFF0A0614);

/// How long a card takes to come into, or leave, the spotlight.
const Duration kHeroSpotDuration = Duration(milliseconds: 900);

// ── Sizes ────────────────────────────────────────────────────────────────────

/// Height of the hero: 62% of the screen (clamped for landscape phones and
/// tablets), so the greeting and Today show on the first screen.
double homeHeroMediaHeight(Size screen) =>
    (screen.height * 0.62).clamp(260.0, 600.0);

/// Height of the band at the top of the hero that the floating header
/// (logo and bell chips) occupies below the status bar; the wall starts
/// under it, as kharis.org's starts under its navigation.
const double kHeroTopBarExtent = 58;

// ── Video surface ────────────────────────────────────────────────────────────

/// Builds a wall video: [asset] looping and silent while [playing], its
/// poster otherwise. Swapped out in tests, which have no video plugin.
typedef HeroWallVideoBuilder =
    Widget Function(String asset, String poster, bool playing);

final heroWallVideoProvider = Provider<HeroWallVideoBuilder>(
  (ref) =>
      (asset, poster, playing) =>
          _WallVideo(asset: asset, poster: poster, playing: playing),
);

// ── What a tap plays ─────────────────────────────────────────────────────────

/// The message the hero plays on a tap: the newest one with a video.
final heroMessageProvider = Provider<Sermon?>((ref) {
  for (final s in ref.watch(latestSermonsProvider)) {
    if (s.videoId?.isNotEmpty ?? false) return s;
  }
  return null;
});

// ── Hero ─────────────────────────────────────────────────────────────────────

/// The full-bleed wall at the top of Home, under the status bar, as on
/// kharis.org: two rows of the church's photos and videos drifting right
/// (row one a card every 6 s, row two every 7.5 s, half a card apart). The
/// card nearest the middle of each row is in colour and slightly larger;
/// the rest are grey and dimmed. A sideways drag moves the wall by hand.
///
/// A tap plays the latest message's video. Everything on the wall stands
/// still while that plays (the player covers Home), whenever Home is not
/// the visible tab, the wall has scrolled away ([inView]), the app is in
/// the background, or the member asks for reduced motion. Only the videos
/// on screen play, silent and alongside any message audio.
class HomeHero extends ConsumerStatefulWidget {
  const HomeHero({
    super.key,
    required this.topBar,
    this.inView = true,
    this.scroll,
  });

  final Widget topBar;

  /// Home's scroll: the wall drifts up slower than the page and fades into
  /// it as the content rises (none in tests that host the hero alone).
  final ScrollController? scroll;

  /// False once Home has scrolled the wall out of view.
  final bool inView;

  @override
  ConsumerState<HomeHero> createState() => _HomeHeroState();
}

class _HomeHeroState extends ConsumerState<HomeHero>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  late final AppLifecycleListener _lifecycle;
  bool _foreground = true;

  /// Each row's own drift, in cards moved since the wall appeared.
  final List<double> _drift = [0, 0];

  /// The member's sideways drags, in pixels, shared by both rows.
  double _drag = 0;

  Duration _last = Duration.zero;

  /// Ticks once per frame while the wall moves; the rows listen.
  final ValueNotifier<int> _frame = ValueNotifier(0);

  /// One player per wall video while the wall exists.
  final HeroVideoPool<VideoPlayerController> _videos = _videoPlayerPool();

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        final foreground = state == AppLifecycleState.resumed;
        if (foreground != _foreground) setState(() => _foreground = foreground);
      },
    );
  }

  @override
  void dispose() {
    _ticker.dispose();
    _lifecycle.dispose();
    _frame.dispose();
    _videos.dispose();
    super.dispose();
  }

  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  /// Whether anything on the wall may move or play right now.
  bool _canMove(BuildContext context) =>
      widget.inView &&
      _foreground &&
      !_reduceMotion &&
      TickerMode.valuesOf(context).enabled;

  void _tick(Duration elapsed) {
    final dt = math.min(0.05, (elapsed - _last).inMicroseconds / 1e6);
    _last = elapsed;
    for (var r = 0; r < _drift.length; r++) {
      _drift[r] += dt / kHeroWallSecondsPerCard[r];
    }
    _frame.value++;
  }

  void _syncTicker(bool move) {
    if (move && !_ticker.isActive) {
      _last = Duration.zero;
      unawaited(_ticker.start());
    } else if (!move && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _onDrag(DragUpdateDetails d) {
    _drag += d.delta.dx;
    _frame.value++;
  }

  void _play() {
    final sermon = ref.read(heroMessageProvider);
    if (sermon == null) return;
    unawaited(startPlayback(context, ref, sermon, mode: MediaMode.video));
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final screen = MediaQuery.sizeOf(context);
    final mediaHeight = homeHeroMediaHeight(screen);
    final move = _canMove(context);
    _syncTicker(move);
    final message = ref.watch(heroMessageProvider);

    // Everything stays inside the hero's box: the scroll drift moves the
    // wall at paint time, which a Stack's own clip never sees, so the box
    // clips explicitly and content below scrolls up cleanly.
    return _VideoPoolScope(
      pool: _videos,
      child: SizedBox(
        height: mediaHeight,
        child: ClipRect(
          child: Stack(
            children: [
              Positioned.fill(
                child: _ScrollFade(
                  scroll: widget.scroll,
                  distance: mediaHeight,
                  background: context.kc.bg,
                  child: Semantics(
                    button: message != null,
                    label: message == null
                        ? 'Kharis Church'
                        : 'Play the latest message, ${message.title}',
                    excludeSemantics: true,
                    child: GestureDetector(
                      key: const Key('home-hero-wall'),
                      behavior: HitTestBehavior.opaque,
                      onTap: message == null ? null : _play,
                      onHorizontalDragUpdate: _reduceMotion ? null : _onDrag,
                      child: ColoredBox(
                        color: kHeroWallBackground,
                        child: Padding(
                          padding: EdgeInsets.only(
                            top: padding.top + kHeroTopBarExtent,
                            bottom: kHeroWallGap,
                          ),
                          child: Column(
                            children: [
                              for (final (r, items) in const [
                                kHeroWallTop,
                                kHeroWallBottom,
                              ].indexed) ...[
                                if (r > 0) const SizedBox(height: kHeroWallGap),
                                Expanded(
                                  child: _WallRow(
                                    key: Key('home-hero-row-$r'),
                                    row: r,
                                    items: items,
                                    // Row two sits half a card along.
                                    phase: r * 0.5,
                                    drift: () => _drift[r],
                                    drag: () => _drag,
                                    frame: _frame,
                                    playing: move,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
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
      ),
    );
  }
}

/// Moves [child] up at 40% of the page's speed and fades it into
/// [background] over [distance] of scroll: the wall drifts away behind the
/// content instead of scrolling off with it. A colour wash rather than
/// [Opacity], which video surfaces do not honour everywhere.
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
        // Fades in step with the wall leaving the screen.
        final t = distance <= 0 ? 0.0 : offset / distance;
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

// ── A row ────────────────────────────────────────────────────────────────────

/// One row of the wall: its [items] twice over, so it loops without a seam,
/// shifted right by its drift and the member's drags. The card nearest the
/// middle is the spot.
class _WallRow extends ConsumerWidget {
  const _WallRow({
    super.key,
    required this.row,
    required this.items,
    required this.phase,
    required this.drift,
    required this.drag,
    required this.frame,
    required this.playing,
  });

  final int row;
  final List<HeroWallItem> items;

  /// Where the row starts, in cards: 0 puts the first card in the middle.
  final double phase;

  final double Function() drift;
  final double Function() drag;
  final ValueListenable<int> frame;

  /// Whether the wall may play its videos.
  final bool playing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final video = ref.watch(heroWallVideoProvider);
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth;
        final card = width * kHeroWallCardWidth;
        final step = card + kHeroWallGap;
        final set = step * items.length;
        final track = [...items, ...items];
        return ValueListenableBuilder<int>(
          valueListenable: frame,
          builder: (context, _, _) {
            // First card centred, then [phase] cards along, then the drift
            // and drags, wrapped into one set's width.
            final start = width / 2 - card / 2 + set;
            final raw = start + (phase + drift()) * step + drag();
            final shift = (raw % set + set) % set - set;
            var spot = 0;
            var nearest = double.infinity;
            for (var i = 0; i < track.length; i++) {
              final d = (i * step + card / 2 + shift - width / 2).abs();
              if (d < nearest) {
                nearest = d;
                spot = i;
              }
            }
            return Stack(
              clipBehavior: Clip.none,
              children: [
                for (final (i, item) in track.indexed)
                  Positioned(
                    left: i * step + shift,
                    top: 0,
                    bottom: 0,
                    width: card,
                    child: _WallCard(
                      key: Key('home-hero-card-$row-$i'),
                      item: item,
                      spot: i == spot,
                      // Only videos on screen play.
                      playing:
                          playing &&
                          i * step + shift < width &&
                          i * step + shift + card > 0,
                      video: video,
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Greyscale at 46% brightness with 8% more contrast: the off-spot look.
const List<double> _kOffSpot = [
  0.2126 * _b * _c, 0.7152 * _b * _c, 0.0722 * _b * _c, 0, _o, //
  0.2126 * _b * _c, 0.7152 * _b * _c, 0.0722 * _b * _c, 0, _o, //
  0.2126 * _b * _c, 0.7152 * _b * _c, 0.0722 * _b * _c, 0, _o, //
  0, 0, 0, 1, 0,
];
const double _b = 0.46;
const double _c = 1.08;
const double _o = 255 * 0.5 * (1 - _c);

const List<double> _kIdentity = [
  1, 0, 0, 0, 0, //
  0, 1, 0, 0, 0, //
  0, 0, 1, 0, 0, //
  0, 0, 0, 1, 0,
];

/// A card: in colour and enlarged in the spot, grey and set back otherwise,
/// easing between the two.
class _WallCard extends StatelessWidget {
  const _WallCard({
    super.key,
    required this.item,
    required this.spot,
    required this.playing,
    required this.video,
  });

  final HeroWallItem item;
  final bool spot;
  final bool playing;
  final HeroWallVideoBuilder video;

  @override
  Widget build(BuildContext context) {
    final asset = item.video;
    final media = asset != null
        ? video(asset, item.image, playing)
        : Image.asset(item.image, fit: BoxFit.cover, gaplessPlayback: true);
    return AnimatedScale(
      scale: spot ? 1.05 : 0.965,
      duration: kHeroSpotDuration,
      curve: const Cubic(0.22, 1, 0.36, 1),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: spot ? 0 : 1),
        duration: kHeroSpotDuration,
        curve: const Cubic(0.33, 0, 0.2, 1),
        builder: (context, grey, child) => ColorFiltered(
          colorFilter: ColorFilter.matrix([
            for (var k = 0; k < 20; k++)
              _kIdentity[k] + (_kOffSpot[k] - _kIdentity[k]) * grey,
          ]),
          child: child,
        ),
        child: ColoredBox(
          key: spot ? const Key('home-hero-spot') : null,
          color: const Color(0xFF140C22),
          child: SizedBox.expand(child: media),
        ),
      ),
    );
  }
}

// ── Wall videos ──────────────────────────────────────────────────────────────

/// One player per wall video, shared by every card showing it (each row
/// holds its media twice to loop). A player is made the first time one of
/// its cards is on screen, plays while any is, pauses when none is, and is
/// released only with the wall: cards drifting on and off never make a
/// second one. Generic over the player so its rules are testable.
class HeroVideoPool<T extends Object> {
  HeroVideoPool({
    required this.create,
    required this.play,
    required this.pause,
    required this.release,
  });

  final T Function(String asset) create;
  final void Function(T player) play;
  final void Function(T player) pause;
  final void Function(T player) release;

  final Map<String, T> _players = {};
  final Map<String, Set<Object>> _wanted = {};
  final Map<String, bool> _playing = {};

  /// Players made so far, by asset.
  Map<String, T> get players => Map.unmodifiable(_players);

  /// [card] wants [asset] playing ([on]) or no longer does.
  void want(Object card, String asset, {required bool on}) {
    final wanting = _wanted.putIfAbsent(asset, () => <Object>{});
    if (on) {
      wanting.add(card);
    } else {
      wanting.remove(card);
    }
    var player = _players[asset];
    if (player == null) {
      // Made only once a card actually needs it.
      if (wanting.isEmpty) return;
      player = _players[asset] = create(asset);
    }
    final should = wanting.isNotEmpty;
    if (_playing[asset] == should) return;
    _playing[asset] = should;
    should ? play(player) : pause(player);
  }

  /// Releases every player.
  void dispose() {
    _players.values.forEach(release);
    _players.clear();
    _wanted.clear();
    _playing.clear();
  }
}

/// The wall's pool of real players: silent, looping, mixing with any
/// message playing, never taking the app's sound.
HeroVideoPool<VideoPlayerController> _videoPlayerPool() {
  final ready = <VideoPlayerController, Future<void>>{};
  return HeroVideoPool<VideoPlayerController>(
    create: (asset) {
      final c = VideoPlayerController.asset(
        asset,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      ready[c] = c.initialize().then((_) async {
        await c.setVolume(0);
        await c.setLooping(true);
      });
      return c;
    },
    play: (c) => unawaited(ready[c]?.then((_) => c.play())),
    pause: (c) => unawaited(ready[c]?.then((_) => c.pause())),
    release: (c) {
      ready.remove(c);
      unawaited(c.dispose());
    },
  );
}

/// Gives the wall's cards their shared players.
class _VideoPoolScope extends InheritedWidget {
  const _VideoPoolScope({required this.pool, required super.child});

  final HeroVideoPool<VideoPlayerController> pool;

  static HeroVideoPool<VideoPlayerController>? of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_VideoPoolScope>()?.pool;

  @override
  bool updateShouldNotify(_VideoPoolScope old) => pool != old.pool;
}

/// A wall video card: its [poster], with the shared player over it once
/// that has a frame up. [playing] says whether this card is on screen.
class _WallVideo extends StatefulWidget {
  const _WallVideo({
    required this.asset,
    required this.poster,
    required this.playing,
  });

  final String asset;
  final String poster;
  final bool playing;

  @override
  State<_WallVideo> createState() => _WallVideoState();
}

class _WallVideoState extends State<_WallVideo> {
  HeroVideoPool<VideoPlayerController>? _pool;
  VideoPlayerController? _player;
  bool _showing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _pool = _VideoPoolScope.of(context);
    _sync();
  }

  @override
  void didUpdateWidget(_WallVideo old) {
    super.didUpdateWidget(old);
    if (old.playing != widget.playing) _sync();
  }

  @override
  void dispose() {
    _pool?.want(this, widget.asset, on: false);
    _player?.removeListener(_onValue);
    super.dispose();
  }

  void _sync() {
    final pool = _pool;
    if (pool == null) return;
    pool.want(this, widget.asset, on: widget.playing);
    final player = pool.players[widget.asset];
    if (player != _player) {
      _player?.removeListener(_onValue);
      _player = player?..addListener(_onValue);
      _onValue();
    }
  }

  void _onValue() {
    final v = _player?.value;
    // The poster stays until the shared player has a frame up.
    final showing = v != null && v.isInitialized && v.position > Duration.zero;
    if (showing != _showing && mounted) setState(() => _showing = showing);
  }

  @override
  Widget build(BuildContext context) {
    final c = _player;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(widget.poster, fit: BoxFit.cover, gaplessPlayback: true),
        if (c != null && _showing)
          FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: c.value.size.width,
              height: c.value.size.height,
              child: VideoPlayer(c),
            ),
          ),
      ],
    );
  }
}
