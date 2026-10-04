import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/gestures.dart' show kPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart' show PlayerState, ProcessingState;

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/giving/presentation/screens/giving_screen.dart';
import 'package:kharis_app/features/home/data/daily_content_repository.dart';
import 'package:kharis_app/features/home/data/live_repository.dart';
import 'package:kharis_app/features/home/data/news_repository.dart';
import 'package:kharis_app/features/calendar/data/event_repository.dart';
import 'package:kharis_app/features/home/presentation/widgets/campus_card.dart';
import 'package:kharis_app/features/home/presentation/widgets/live_now_card.dart';
import 'package:kharis_app/features/home/presentation/widgets/news_section.dart';
import 'package:kharis_app/features/home/presentation/widgets/upcoming_events_strip.dart';
import 'package:kharis_app/features/onboarding/data/branch_repository.dart';
import 'package:kharis_app/shared/models/campus_config.dart';
import 'package:kharis_app/shared/providers/admin_provider.dart';
import 'package:kharis_app/features/home/presentation/widgets/todays_reading_card.dart';
import 'package:kharis_app/features/messages/presentation/screens/messages_screen.dart';
import 'package:kharis_app/features/notes/data/note_repository.dart';
import 'package:kharis_app/features/player/presentation/screens/media_player_screen.dart';
import 'package:kharis_app/features/player/presentation/widgets/mini_player.dart';
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

import 'support/fake_audio_player_service.dart';
import 'support/fake_cache_service.dart';
import 'support/fake_sermon_repository.dart';

/// DESIGN.md: "No glows", "No glassmorphism", restrained flat surfaces.
/// The only shadow allowed is the design system's [AppShadows.card].
bool _isCardShadow(BoxShadow s) => AppShadows.card.contains(s);

/// A scrim keeps text legible over a photo: grey/black only, never a hue.
bool _isNeutral(Color c) => c.r == c.g && c.g == c.b;

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
    } else if (flatFills && !gradient.colors.every(_isNeutral)) {
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

  List<Override> playerOverrides() => [
    audioPlayerServiceProvider.overrideWithValue(audio),
    cacheServiceProvider.overrideWithValue(FakeCacheService()),
    sermonsProvider.overrideWith((ref) async => const <Sermon>[]),
    playlistsProvider.overrideWith((ref) => Stream.value(const <Playlist>[])),
    favoritesProvider.overrideWith((ref) => Stream.value(null)),
    notesProvider.overrideWith((ref) => Stream.value(const <Note>[])),
  ];

  for (final brightness in Brightness.values) {
    group('no glow or gloss ($brightness)', () {
      ThemeData theme() => kharisTheme(brightness: brightness);

      testWidgets('full player, audio mode', (tester) async {
        final sermon = _sermon(1, videoId: 'v1');
        await audio.play(sermon);
        await tester.pumpWidget(
          ProviderScope(
            overrides: playerOverrides(),
            child: MaterialApp(
              theme: theme(),
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
              theme: theme(),
              home: MediaPlayerScreen(sermon: sermon, mode: MediaMode.video),
            ),
          ),
        );
        await tester.pump();

        expect(_gloss(tester, flatFills: true), isEmpty);
      });

      testWidgets('mini player', (tester) async {
        await audio.play(_sermon(3));
        await tester.pumpWidget(
          ProviderScope(
            overrides: playerOverrides(),
            child: MaterialApp(
              theme: theme(),
              home: const Scaffold(
                bottomNavigationBar: MiniPlayer(),
                body: SizedBox.expand(),
              ),
            ),
          ),
        );
        audio.playerStates.add(PlayerState(true, ProcessingState.ready));
        await tester.pump();

        expect(find.text('Message 3'), findsOneWidget);
        expect(_gloss(tester, flatFills: true), isEmpty);
      });

      testWidgets('Messages screen with the featured carousel and topics', (
        tester,
      ) async {
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
              categoryLabelsProvider.overrideWith(
                (ref) => const ['All', 'Prayer & Fasting'],
              ),
              recentlyPlayedProvider.overrideWith(
                (ref) => [testSermon('r1', title: 'Recent one')],
              ),
            ],
            child: MaterialApp(theme: theme(), home: const MessagesScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // The first featured card is the active page: it used to glow.
        expect(find.text('FEATURED'), findsWidgets);
        expect(_gloss(tester, flatFills: true), isEmpty);

        // The Recently played play chip used to float on a drop shadow.
        await tester.ensureVisible(find.text('Recent one'));
        await tester.pumpAndSettle();
        expect(_gloss(tester, flatFills: true), isEmpty);

        // A selected topic card used to glow in the accent colour.
        await tester.ensureVisible(find.text('Prayer & Fasting'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Prayer & Fasting'));
        await tester.pumpAndSettle();
        final accent = brightness == Brightness.dark
            ? KharisColors.dark.accent
            : KharisColors.light.accent;
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is DecoratedBox &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).border ==
                    Border.all(color: accent, width: 2.5),
          ),
          findsOneWidget,
          reason: 'the topic card is in its selected state',
        );
        expect(_gloss(tester, flatFills: true), isEmpty);
      });

      Future<void> pumpCard(
        WidgetTester tester,
        Widget card, {
        List<Override> overrides = const [],
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
              theme: theme(),
              home: Scaffold(
                body: Padding(padding: const EdgeInsets.all(20), child: card),
              ),
            ),
          ),
        );
        await tester.pump();
      }

      testWidgets("Home: today's reading card, loaded and loading", (
        tester,
      ) async {
        await pumpCard(
          tester,
          const TodaysReadingCard(),
          overrides: [
            dailyContentProvider.overrideWith(
              (ref) => Stream.value(
                const DailyContent(
                  reading: BibleReading(book: 'John', chapter: 3, verse: '16'),
                  prayer: 'Lord, teach us to pray.',
                  prayerReference: 'Luke 11:1',
                ),
              ),
            ),
          ],
        );
        expect(find.text('Read now'), findsOneWidget);
        expect(_gloss(tester, flatFills: true), isEmpty);

        await pumpCard(
          tester,
          const TodaysReadingCard(),
          overrides: [
            dailyContentProvider.overrideWith(
              (ref) => const Stream<DailyContent>.empty(),
            ),
          ],
        );
        expect(find.text('Read now'), findsNothing, reason: 'skeleton shown');
        expect(_gloss(tester, flatFills: true), isEmpty);
      });

      testWidgets('Home: live now card', (tester) async {
        await pumpCard(
          tester,
          const LiveNowCard(),
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
        expect(find.text('LIVE NOW'), findsOneWidget);
        expect(_gloss(tester, flatFills: true), isEmpty);
      });

      testWidgets('Home: campus card', (tester) async {
        await pumpCard(
          tester,
          const CampusCard(),
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

      testWidgets('Home: upcoming event tiles', (tester) async {
        await pumpCard(
          tester,
          const UpcomingEventsStrip(),
          overrides: [
            campusUpcomingEventsProvider.overrideWithValue(
              AsyncValue.data([
                Event(
                  id: 'e1',
                  title: 'Prayer Night',
                  location: 'Main Hall',
                  startTime: DateTime(2026, 10, 9, 19),
                ),
              ]),
            ),
          ],
        );
        expect(find.text('Prayer Night'), findsOneWidget);
        expect(_gloss(tester, flatFills: true), isEmpty);
      });

      testWidgets('Home: announcement cards', (tester) async {
        await pumpCard(
          tester,
          const AnnouncementsCarousel(),
          overrides: [
            campusNewsProvider.overrideWithValue(
              AsyncValue.data([
                for (var i = 1; i <= 3; i++)
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
        expect(find.text('Notice 1'), findsOneWidget);
        expect(_gloss(tester, flatFills: true), isEmpty);
      });

      testWidgets('Giving: scripture card', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentBranchProvider.overrideWith(
                (ref) => Stream.value('London'),
              ),
            ],
            child: MaterialApp(theme: theme(), home: const GivingScreen()),
          ),
        );
        await tester.pump();
        expect(find.text('2 Corinthians 9:7 (NKJV)'), findsOneWidget);
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
              theme: kharisTheme(),
              home: Scaffold(
                body: Center(child: PlayerControls(transport: transport)),
              ),
            ),
          ),
        );

    final button = find.byKey(const ValueKey('player-play-pause'));
    Material material(WidgetTester tester) => tester.widget<Material>(button);

    testWidgets('is a solid accent circle with no shadow', (tester) async {
      await pump(tester, binding());

      final m = material(tester);
      expect(m.color, KharisColors.light.accent);
      expect(m.elevation, 0);
      expect(m.shape, isA<CircleBorder>());
      expect(
        find.descendant(of: button, matching: find.byType(DecoratedBox)),
        findsNothing,
        reason: 'no glow layer under the glyph',
      );
      expect(_gloss(tester), isEmpty);
    });

    testWidgets('pressing paints an ink highlight on the circle', (
      tester,
    ) async {
      await pump(tester, binding());
      // Paint round-trips colours through 8-bit ARGB, so compare those.
      final highlight = KharisColors.light.onAccent
          .withValues(alpha: 0.16)
          .toARGB32();

      final gesture = await tester.startGesture(tester.getCenter(button));
      // Past the press timeout (tap down fires), then through the fade-in.
      await tester.pump(kPressTimeout);
      await tester.pump(const Duration(milliseconds: 300));

      final inkLayers = tester.allRenderObjects.where(
        (r) => r.runtimeType.toString() == '_RenderInkFeatures',
      );
      // The highlight is a rect clipped to the circle. Other ink in the tree
      // also draws rects, so search for this one rather than the first.
      expect(
        inkLayers,
        contains(
          paints..something(
            (method, args) =>
                method == #drawRect &&
                (args[1] as Paint).color.toARGB32() == highlight,
          ),
        ),
      );

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
        material(tester).color,
        KharisColors.light.accent.withValues(alpha: 0.38),
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
