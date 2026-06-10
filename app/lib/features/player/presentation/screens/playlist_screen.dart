import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

class PlaylistScreen extends ConsumerWidget {
  const PlaylistScreen({
    super.key,
    this.playlistName = 'ACTS SERIES',
  });

  final String playlistName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioService = ref.read(audioPlayerServiceProvider);
    final sermonsAsync = ref.watch(sermonsProvider);

    final sermons = sermonsAsync.when(
      data: (all) {
        // Audio only — exclude YouTube videos
        final audio = all
            .where((s) => !s.isYouTubeVideo && s.audioUrl.isNotEmpty)
            .toList();
        // Prefer sermons whose category or title contains 'acts'
        final acts = audio.where((s) {
          final cat = (s.category ?? '').toLowerCase();
          final title = s.title.toLowerCase();
          return cat.contains('acts') || title.contains('acts');
        }).toList();
        return acts.isNotEmpty ? acts : audio.take(5).toList();
      },
      loading: () => <Sermon>[],
      error: (_, _) => <Sermon>[],
    );

    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  // Dove logo
                  Center(
                    child: Image.asset(
                      'assets/figma/dove_logo.png',
                      height: 32,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Playlist title
                  Text(
                    'Playlist',
                    style: GoogleFonts.mavenPro(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  // ── ACTS SERIES artwork card ─────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [AppColors.purple, AppColors.accent],
                          ),
                        ),
                        child: Center(
                          child: Text(
                            playlistName.isNotEmpty
                                ? playlistName.toUpperCase()
                                : 'ACTS SERIES',
                            style: GoogleFonts.mavenPro(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 2,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // ── Description ─────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Going Through the book of ACTS exploring what God is doing line upon line precept upon precept',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        color: AppColors.textBody,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Playlist · ${sermons.length} Messages',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Color(0xFF252525)),
                ],
              ),
            ),

            // ── Loading indicator ────────────────────────────────────────
            if (sermonsAsync.isLoading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.accent,
                      strokeWidth: 2,
                    ),
                  ),
                ),
              ),

            // ── Episode list ─────────────────────────────────────────────
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final sermon = sermons[index];
                  final durationStr = sermon.duration != null
                      ? '${sermon.duration!.inMinutes} min'
                      : '';
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 4,
                    ),
                    leading: IconButton(
                      onPressed: () => audioService.play(sermon),
                      icon: const Icon(
                        Icons.play_circle_rounded,
                        color: AppColors.accent,
                        size: 32,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    title: Text(
                      sermon.title,
                      style: GoogleFonts.mavenPro(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      durationStr.isNotEmpty
                          ? '${sermon.speaker} · $durationStr'
                          : sermon.speaker,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    onTap: () => audioService.play(sermon),
                  );
                },
                childCount: sermons.length,
              ),
            ),

            // Bottom padding
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }
}
