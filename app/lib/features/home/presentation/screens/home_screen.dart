import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/core/utils/artwork_gradient.dart';
import 'package:kharis_app/features/player/presentation/screens/media_player_screen.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';
import 'package:kharis_app/shared/widgets/skeleton.dart';
import '../widgets/todays_reading_card.dart';
import '../widgets/live_banner.dart';
import '../widgets/news_section.dart';

/// Home tab - Apple TV style: full-bleed hero at top, content rails below.
///
/// The hero renders the latest YouTube video as a cinematic full-bleed
/// card (edge-to-edge, no padding, gradient scrim, dove logo floats over
/// the top). Content scrolls up from underneath.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videosAsync = ref.watch(videosProvider);
    final video = videosAsync.valueOrNull?.isNotEmpty == true
        ? videosAsync.valueOrNull!.first
        : null;

    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      body: RefreshIndicator(
        color: AppColors.secondary,
        edgeOffset: MediaQuery.of(context).padding.top,
        onRefresh: () async {
          ref.invalidate(videosProvider);
          ref.invalidate(sermonsProvider);
          ref.invalidate(dailyContentProvider);
        },
        child: CustomScrollView(
          slivers: [
            // ── Hero: full-bleed, edge-to-edge ──────────────────────
            SliverToBoxAdapter(child: _Hero(video: video)),

            // ── Live banner (realtime, zero footprint when not live) ─
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: LiveBanner(),
              ),
            ),

            // ── Today's reading pill ────────────────────────────────
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: TodaysReadingCard(),
              ),
            ),

            // ── News & Updates ──────────────────────────────────────
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: NewsSection(),
              ),
            ),

            // Bottom safe area
            const SliverToBoxAdapter(child: SizedBox(height: 96)),
          ],
        ),
      ),
    );
  }
}

/// Apple TV-style cinematic hero.
///
/// Full-bleed (no side padding), aspect ~9:16 cropped to 56% of screen height.
/// Dove logo floats top-centre. Title + speaker + gold WATCH CTA overlaid on
/// a bottom gradient scrim. Taps open the in-app player.
class _Hero extends StatelessWidget {
  const _Hero({required this.video});

  final Sermon? video;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final heroHeight = screenHeight * 0.56;
    final topPad = MediaQuery.of(context).padding.top;

    if (video == null) {
      return SizedBox(
        height: heroHeight,
        child: const Center(
          child: Skeleton(width: double.infinity, height: double.infinity),
        ),
      );
    }

    final v = video!;
    final gradientColors = sermonGradient(v.artworkColor ?? 0);

    return GestureDetector(
      onTap: () {
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(
            builder: (context) => MediaPlayerScreen(sermon: v),
          ),
        );
      },
      child: SizedBox(
        height: heroHeight,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background: YouTube thumbnail or gradient
            if (v.artworkUrl != null)
              Image.network(
                v.artworkUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: gradientColors,
                    ),
                  ),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradientColors,
                  ),
                ),
              ),

            // Top fade: transparent -> slight dark at very top (status bar)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: topPad + 60,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xAA131313), Colors.transparent],
                  ),
                ),
              ),
            ),

            // Bottom scrim: transparent -> solid dark
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: heroHeight * 0.55,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xEE131313)],
                    stops: [0.0, 1.0],
                  ),
                ),
              ),
            ),

            // Dove logo: floating top-centre over the hero
            Positioned(
              top: topPad + 12,
              left: 0,
              right: 0,
              child: Center(
                child: Image.asset(
                  'assets/figma/dove_logo.png',
                  height: 36,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ),

            // Content: bottom overlay
            Positioned(
              bottom: 24,
              left: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Speaker pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      v.speaker.toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.secondary,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Title
                  Text(
                    v.title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.15,
                      letterSpacing: -0.5,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 14),
                  // CTA row
                  Row(
                    children: [
                      // WATCH button
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.secondary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.play_arrow_rounded,
                              color: Color(0xFF3C2F00),
                              size: 20,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Watch',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF3C2F00),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Share icon
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.ios_share_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
