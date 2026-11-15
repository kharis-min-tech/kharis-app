import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/gestures.dart' show kPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/giving/presentation/screens/giving_screen.dart';
import 'package:kharis_app/features/home/data/daily_content_repository.dart';
import 'package:kharis_app/features/home/data/live_repository.dart';
import 'package:kharis_app/features/home/data/news_repository.dart';
import 'package:kharis_app/features/home/presentation/widgets/campus_card.dart';
import 'package:kharis_app/features/home/presentation/widgets/daily_message_card.dart';
import 'package:kharis_app/features/home/presentation/widgets/live_now_card.dart';
import 'package:kharis_app/features/home/presentation/widgets/home_branch_news.dart';
import 'package:kharis_app/features/onboarding/data/branch_repository.dart';
import 'package:kharis_app/shared/models/campus_config.dart';
import 'package:kharis_app/shared/providers/admin_provider.dart';
import 'package:kharis_app/features/messages/presentation/screens/messages_screen.dart';
import 'package:kharis_app/features/notes/data/note_repository.dart';
import 'package:kharis_app/features/player/presentation/screens/media_player_screen.dart';
import 'package:kharis_app/features/player/presentation/widgets/player_controls.dart';
import 'package:kharis_app/features/playlists/data/playlist_repository.dart';
import 'package:kharis_app/features/playlists/providers/playlist_providers.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/cache_provider.dart';
import 'package:kharis_app/shared/providers/notes_provider.dart';
import 'package:kharis_app/shared/providers/notification_feed_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';
import 'package:kharis_app/shared/widgets/artwork_image.dart';
import 'package:kharis_app/theme/kharis_theme.dart' as redesign;

import 'support/fake_audio_player_service.dart';
import 'support/fake_cache_service.dart';
import 'support/fake_sermon_repository.dart';

/// DESIGN.md: "No glows", "No glassmorphism", restrained flat surfaces.
/// The only shadows allowed are the design tokens ([redesign.KShadow]);
/// [AppShadows.card] stays only while the old theme still exists.
final _tokenShadows = <BoxShadow>{
  ...AppShadows.card,
  ...redesign.KShadow.cardLight,
  ...redesign.KShadow.cardDark,
  ...redesign.KShadow.floatingLight,
  ...redesign.KShadow.floatingDark,
  ...redesign.KShadow.sheet,
  ...redesign.KShadow.grace,
};
bool _isCardShadow(BoxShadow s) => _tokenShadows.contains(s);

/// A scrim keeps text legible over a photo: grey/black only, never a hue.
bool _isNeutral(Color c) => c.r == c.g && c.g == c.b;

/// An edge fade: one colour going to or from transparent (only the alpha
/// changes), e.g. a list fading into the canvas. Not decoration.
bool _isFade(List<Color> colors) => colors.every(
  (c) =>
      c.r == colors.first.r && c.g == colors.first.g && c.b == colors.first.b,
);

/// Every glow, lift, glass blur, shine or (with [flatFills]) decorative
/// colour gradient in the tree. Gradients inside [ArtworkImage] are message
/// artwork, not chrome, so they are left alone.
List<String> _gloss(WidgetTester tester, {bool flatFills = false}) {
  // skipOffstage: false on both sides: the scan walks off-screen carousel
  // pages too, and their artwork is content just like the visible page's.
  final artwork = find.descendant(
    of: find.byType(ArtworkImage, skipOffstage: false),
    matching: find.byType(DecoratedBox, skipOffstage: false),
    skipOffstage: false,
  );
  final inArtwork = Set<Widget>.identity()..addAll(tester.widgetList(artwork));
  final found = <String>[];
  void checkDecoration(Decoration? decoration, Widget owner) {
    if (decoration is! BoxDecoration) return;
    for (final shadow in decoration.boxShadow ?? const <BoxShadow>[]) {
      if (!_isCardShadow(shadow)) {
        found.add('${owner.runtimeType}: BoxShadow $shadow');
      }
    }
    final gradient = decoration.gradient;
    if (gradient == null || inArtwork.contains(owner)) return;
    if (gradient is! LinearGradient) {
      found.add('${owner.runtimeType}: ${gradient.runtimeType} shine');
    } else if (flatFills &&
        !gradient.colors.every(_isNeutral) &&
        !_isFade(gradient.colors)) {
      found.add('${owner.runtimeType}: colour gradient ${gradient.colors}');
    }
  }

  for (final widget in tester.allWidgets) {
    switch (widget) {
      case BackdropFilter():
        found.add('BackdropFilter');
      case DecoratedBox(:final decoration):
        checkDecoration(decoration, widget);
      case Ink(:final decoration):
        checkDecoration(decoration, widget);
      case PhysicalModel(:final elevation) when elevation > 0:
        found.add('PhysicalModel: elevation $elevation');
      case PhysicalShape(:final elevation) when elevation > 0:
        found.add('PhysicalShape: elevation $elevation');
      default:
        break;
    }
  }
  return found;
}

/// WCAG contrast ratio of [fg] composited over the opaque [bg].
double _contrast(Color fg, Color bg) {
  final a = Color.alphaBlend(fg, bg).computeLuminance();
  final b = bg.computeLuminance();
  final hi = a > b ? a : b;
  final lo = a > b ? b : a;
  return (hi + 0.05) / (lo + 0.05);
}

Sermon _sermon(int n, {String? videoId}) => Sermon(
  id: 's$n',
  title: 'Message $n',
  speaker: 'Pastor A',
  audioUrl: 'https://cdn.example/s$n.mp3',
  videoId: videoId,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late FakeAudioPlayerService audio;

  setUp(() => audio = FakeAudioPlayerService());

  List<Override> playerOverrides({List<Sermon> library = const []}) => [
    audioPlayerServiceProvider.overrideWithValue(audio),
    cacheServiceProvider.overrideWithValue(FakeCacheService()),
    sermonsProvider.overrideWith((ref) async => library),
    playlistsProvider.overrideWith((ref) => Stream.value(const <Playlist>[])),
    favoritesProvider.overrideWith((ref) => Stream.value(null)),
    notesProvider.overrideWith((ref) => Stream.value(const <Note>[])),
  ];

  testWidgets('a shadow that is not a design token is reported', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: DecoratedBox(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(color: Color(0x667C3AED), blurRadius: 24),
            ],
          ),
          child: SizedBox(width: 40, height: 40),
        ),
      ),
    );
    expect(_gloss(tester), hasLength(1));

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: DecoratedBox(
          decoration: BoxDecoration(boxShadow: redesign.KShadow.cardLight),
          child: SizedBox(width: 40, height: 40),
        ),
      ),
    );
    expect(_gloss(tester), isEmpty);
  });

  for (final brightness in Brightness.values) {
    group('no glow or gloss ($brightness)', () {
      ThemeData theme() => kharisTheme(brightness: brightness);
      // The player is on the redesigned theme.
      ThemeData playerTheme() => brightness == Brightness.dark
          ? redesign.KharisTheme.dark()
          : redesign.KharisTheme.light();

      testWidgets('full player, audio mode', (tester) async {
        final sermon = _sermon(1, videoId: 'v1');
        await audio.play(sermon);
        await tester.pumpWidget(
          ProviderScope(
            overrides: playerOverrides(),
            child: MaterialApp(
              theme: playerTheme(),
              home: MediaPlayerScreen(sermon: sermon, mode: MediaMode.audio),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(PlayerControls), findsOneWidget);
        expect(_gloss(tester, flatFills: true), isEmpty);
      });

      testWidgets('full player, video mode', (tester) async {
        MediaPlayerScreen.debugDisableVideoEngine = true;
        addTearDown(() => MediaPlayerScreen.debugDisableVideoEngine = false);
        final sermon = _sermon(2, videoId: 'v2');
        await tester.pumpWidget(
          ProviderScope(
            overrides: playerOverrides(),
            child: MaterialApp(
              theme: playerTheme(),
              home: MediaPlayerScreen(sermon: sermon, mode: MediaMode.video),
            ),
          ),
        );
        await tester.pump();

        expect(_gloss(tester, flatFills: true), isEmpty);
      });

      testWidgets('full player: artwork, Up next, More like this', (
        tester,
      ) async {
        final sermon = Sermon(
          id: 's1',
          title: 'Message 1',
          speaker: 'Pastor A',
          audioUrl: 'https://cdn.example/s1.mp3',
          artworkUrl: 'https://cdn.example/s1.jpg',
        );
        final queue = [sermon, _sermon(2), _sermon(3)];
        await audio.play(sermon, queue: queue);
        await tester.pumpWidget(
          ProviderScope(
            overrides: playerOverrides(library: queue),
            child: MaterialApp(
              theme: playerTheme(),
              home: MediaPlayerScreen(
                sermon: sermon,
                mode: MediaMode.audio,
                queue: queue,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('player-up-next')), findsOneWidget);
        expect(find.byKey(const Key('player-related')), findsOneWidget);
        expect(_gloss(tester, flatFills: true), isEmpty);
      });

      testWidgets('Messages screen', (tester) async {
        final live = [
          for (var i = 1; i <= 3; i++)
            testSermon(
              '$i',
              title: 'Live message $i',
              publishedAt: DateTime(2026, 9, i),
            ),
        ];
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sermonRepositoryProvider.overrideWithValue(
                FakePagedSermonRepository([live]),
              ),
              sermonArchiveAutoHydrateProvider.overrideWithValue(false),
              cmsSermonsProvider.overrideWith(
                (ref) => Stream.value(const <Sermon>[]),
              ),
              videosProvider.overrideWith((ref) async => const <Sermon>[]),
              firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
              cacheServiceProvider.overrideWithValue(FakeCacheService()),
              audioPlayerServiceProvider.overrideWithValue(audio),
              featuredSermonsProvider.overrideWith((ref) => live),
              recentlyPlayedProvider.overrideWith(
                (ref) => [testSermon('r1', title: 'Recent one')],
              ),
            ],
            child: MaterialApp(
              theme: playerTheme(),
              home: const MessagesScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(MessagesScreen), findsOneWidget);
        expect(_gloss(tester, flatFills: true), isEmpty);

        await tester.fling(
          find.byType(Scrollable).first,
          const Offset(0, -2000),
          3000,
        );
        await tester.pumpAndSettle();
        expect(_gloss(tester, flatFills: true), isEmpty);
      });

      Future<void> pumpCard(
        WidgetTester tester,
        Widget card, {
        List<Override> overrides = const [],
        ThemeData? themeData,
      }) async {
        await tester.pumpWidget(
          ProviderScope(
            // Overrides cannot change on a live scope: each state is fresh.
            key: UniqueKey(),
            overrides: [
              ...playerOverrides(),
              liveStatusProvider.overrideWith(
                (ref) => Stream.value(LiveStatus.notLive),
              ),
              audioTwinByVideoIdProvider.overrideWith(
                (ref) => const <String, Sermon>{},
              ),
              ...overrides,
            ],
            child: MaterialApp(
              theme: themeData ?? theme(),
              home: Scaffold(
                body: Padding(padding: const EdgeInsets.all(20), child: card),
              ),
            ),
          ),
        );
        await tester.pump();
      }

      testWidgets('Home: daily message card', (tester) async {
        await pumpCard(
          tester,
          const DailyMessageCard(),
          themeData: playerTheme(),
          overrides: [
            dailyMessageProvider.overrideWith(
              (ref) => Stream.value(
                const DailyMessage(
                  sermonId: 's1',
                  note: 'God is light, and in Him is no darkness at all.',
                ),
              ),
            ),
            sermonByIdProvider.overrideWith(
              (ref, id) => const AsyncData<Sermon?>(
                Sermon(
                  id: 's1',
                  title: 'Walk in the light',
                  speaker: 'Pastor',
                  audioUrl: 'https://example.org/a.mp3',
                ),
              ),
            ),
          ],
        );
        await tester.pump();
        expect(find.text('Walk in the light'), findsOneWidget);
        expect(_gloss(tester, flatFills: true), isEmpty);
      });

      testWidgets('Home: live now card', (tester) async {
        await pumpCard(
          tester,
          const LiveNowCard(),
          themeData: playerTheme(),
          overrides: [
            liveStatusProvider.overrideWith(
              (ref) => Stream.value(
                const LiveStatus(
                  isLive: true,
                  videoId: 'abc123',
                  title: 'Sunday service',
                ),
              ),
            ),
          ],
        );
        await tester.pump();
        expect(find.text('Sunday service'), findsOneWidget);
        expect(find.text('Live now'), findsOneWidget);
        expect(_gloss(tester, flatFills: true), isEmpty);
      });

      testWidgets('Home: campus card', (tester) async {
        await pumpCard(
          tester,
          const CampusCard(),
          themeData: playerTheme(),
          overrides: [
            currentBranchProvider.overrideWith((ref) => Stream.value('London')),
            branchesProvider.overrideWith(
              (ref) => Stream.value(const [
                Branch(
                  id: 'london',
                  name: 'London',
                  subtitle: '',
                  gradientStart: AppColors.primary,
                  gradientEnd: AppColors.primaryDeep,
                  contact: CampusContact(phone: '020 0000 0000'),
                  venues: [
                    CampusVenue(id: 'v1', name: 'Town Hall', city: 'London'),
                  ],
                  services: [
                    CampusService(
                      id: 's1',
                      name: 'Sunday Service',
                      day: 'Sundays',
                      startTime: '10:00',
                      venueId: 'v1',
                    ),
                  ],
                ),
              ]),
            ),
          ],
        );
        await tester.pump();
        expect(find.text('Sunday Service'), findsOneWidget);
        expect(_gloss(tester, flatFills: true), isEmpty);
      });

      testWidgets('Home: branch news carousel', (tester) async {
        await pumpCard(
          tester,
          const HomeBranchNews(),
          themeData: playerTheme(),
          overrides: [
            campusNewsProvider.overrideWithValue(
              AsyncValue.data([
                for (var i = 3; i >= 1; i--)
                  NewsItem(
                    id: 'n$i',
                    title: 'Notice $i',
                    type: 'Announcement',
                    publishedAt: DateTime(2026, 10, i),
                  ),
              ]),
            ),
          ],
        );
        expect(find.text('Notice 3'), findsOneWidget);
        expect(_gloss(tester, flatFills: true), isEmpty);
      });

      testWidgets('Giving: scripture card', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentBranchProvider.overrideWith(
                (ref) => Stream.value('London'),
              ),
              branchesProvider.overrideWith(
                (ref) => Stream.value(const <Branch>[]),
              ),
            ],
            child: MaterialApp(
              theme: playerTheme(),
              home: const GivingScreen(),
            ),
          ),
        );
        await tester.pump();
        expect(find.text('2 CORINTHIANS 9:7 \u00b7 KJV'), findsOneWidget);
        expect(_gloss(tester, flatFills: true), isEmpty);
      });
    });
  }

  test('text on the solid fills and page colours keeps 4.5:1 contrast', () {
    const deep = AppColors.primaryDeep;
    final pairs = <String, (Color, Color)>{
      'reading/giving: white on primaryDeep': (Colors.white, deep),
      'reading: prayer white 88% on primaryDeep': (
        Colors.white.withValues(alpha: .88),
        deep,
      ),
      'reading: gold eyebrow on primaryDeep': (AppColors.secondary, deep),
      'reading: date and prayer label white 85% on primaryDeep': (
        Colors.white.withValues(alpha: .85),
        deep,
      ),
      'live: ink badge on accentPink': (AppColors.ink, AppColors.accentPink),
      'giving: reference darkMuted2 on primaryDeep': (
        AppColors.darkMuted2,
        deep,
      ),
      'settings: avatar initial on primary': (
        AppColors.onPrimary,
        AppColors.primary,
      ),
      for (final (name, kc) in [
        ('light', KharisColors.light),
        ('dark', KharisColors.dark),
      ]) ...{
        'player ($name): onBg on bg': (kc.onBg, kc.bg),
        'player ($name): muted on bg': (kc.muted, kc.bg),
        'cards ($name): muted on surface': (kc.muted, kc.surface),
        'cards ($name): onChip on surface': (kc.onChip, kc.surface),
        'cards ($name): onChip on chipBg': (kc.onChip, kc.chipBg),
        'player ($name): speed pill accentInk on bg': (kc.accentInk, kc.bg),
      },
    };
    for (final MapEntry(key: name, value: (fg, bg)) in pairs.entries) {
      final ratio = _contrast(fg, bg);
      debugPrint('contrast ${ratio.toStringAsFixed(2)}:1  $name');
      expect(ratio, greaterThanOrEqualTo(4.5), reason: name);
    }
  });

  group('play / pause button', () {
    late List<String> taps;

    setUp(() => taps = []);

    TransportBinding binding({
      bool playing = false,
      bool buffering = false,
      bool enabled = true,
    }) => TransportBinding(
      isPlaying: playing,
      isBuffering: buffering,
      speed: 1,
      repeatOn: false,
      onPlay: enabled ? () => taps.add('play') : null,
      onPause: enabled ? () => taps.add('pause') : null,
      onSetSpeed: (_) {},
      onToggleRepeat: () {},
    );

    Future<void> pump(WidgetTester tester, TransportBinding transport) =>
        tester.pumpWidget(
          ProviderScope(
            overrides: playerOverrides(),
            child: MaterialApp(
              theme: redesign.KharisTheme.light(),
              home: Scaffold(
                body: Center(child: PlayerControls(transport: transport)),
              ),
            ),
          ),
        );

    final button = find.byKey(const ValueKey('player-play-pause'));
    Material material(WidgetTester tester) => tester.widget<Material>(
      find.descendant(of: button, matching: find.byType(Material)),
    );

    testWidgets('is a solid primary circle with no shadow', (tester) async {
      await pump(tester, binding());

      final m = material(tester);
      expect(m.color, redesign.KharisColors.light.primary);
      expect(m.elevation, 0);
      expect(m.shape, isA<CircleBorder>());
      expect(
        find.descendant(of: button, matching: find.byType(DecoratedBox)),
        findsNothing,
        reason: 'no glow layer under the glyph',
      );
      expect(_gloss(tester), isEmpty);
    });

    testWidgets('a press and release plays', (tester) async {
      await pump(tester, binding());

      final gesture = await tester.startGesture(tester.getCenter(button));
      await tester.pump(kPressTimeout);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(taps, ['play']);
    });

    testWidgets('buffering shows a spinner, says Loading, still pauses', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, binding(playing: true, buffering: true));

      expect(
        find.descendant(
          of: button,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(button),
        matchesSemantics(
          label: 'Pause',
          value: 'Loading',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );

      await tester.tap(button);
      expect(taps, ['pause']);
      semantics.dispose();
    });

    testWidgets('disabled dims the circle and ignores taps', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, binding(enabled: false));

      expect(
        tester
            .widget<Opacity>(
              find.descendant(of: button, matching: find.byType(Opacity)),
            )
            .opacity,
        lessThan(1),
      );
      expect(
        tester.getSemantics(button),
        matchesSemantics(
          label: 'Play',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
        ),
      );

      await tester.tap(button, warnIfMissed: false);
      expect(taps, isEmpty);
      semantics.dispose();
    });
  });
}
