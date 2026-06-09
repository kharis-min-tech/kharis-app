import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';

class PlaylistScreen extends ConsumerWidget {
  const PlaylistScreen({
    super.key,
    required this.playlistName,
    required this.sermons,
  });

  final String playlistName;
  final List<Sermon> sermons;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioService = ref.read(audioPlayerServiceProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  // Dove logo + Playlist label
                  Center(
                    child: Image.asset(
                      'assets/figma/dove_logo.png',
                      height: 32,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Playlist',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: AppColors.textMuted,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // ACTS SERIES artwork card
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
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
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
                  // Description
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
            // Episode list
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
                        Icons.play_arrow_rounded,
                        color: AppColors.accent,
                        size: 28,
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
