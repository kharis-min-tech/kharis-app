import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';
import 'package:kharis_app/features/messages/presentation/widgets/sermon_list_item.dart';

/// The artwork gradient palette (mirrors sermon_list_item.dart).
const _kArtworkGradients = [
  [Color(0xFFFD7F20), Color(0xFFFF4E00)],
  [Color(0xFF6B34FA), Color(0xFF9B5DE5)],
  [Color(0xFF22C55E), Color(0xFF16A34A)],
  [Color(0xFF3B82F6), Color(0xFF2563EB)],
  [Color(0xFFF59E0B), Color(0xFFD97706)],
  [Color(0xFF800654), Color(0xFFBE185D)],
  [Color(0xFF06B6D4), Color(0xFF0284C7)],
  [Color(0xFFEF4444), Color(0xFFDC2626)],
  [Color(0xFF10B981), Color(0xFF059669)],
  [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
];

List<Color> _gradientFor(int? index) {
  if (index == null) return _kArtworkGradients[0];
  return _kArtworkGradients[index % _kArtworkGradients.length];
}

/// A full playlist screen with a mosaic header, shuffle button, and
/// reorderable sermon list.
class PlaylistScreen extends ConsumerStatefulWidget {
  const PlaylistScreen({
    super.key,
    required this.playlistName,
    required this.sermons,
  });

  final String playlistName;
  final List<Sermon> sermons;

  @override
  ConsumerState<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends ConsumerState<PlaylistScreen> {
  late List<Sermon> _sermons;

  @override
  void initState() {
    super.initState();
    _sermons = List.of(widget.sermons);
  }

  // ── Total duration ─────────────────────────────────────────────────────────

  String _totalDuration() {
    final totalSeconds = _sermons.fold<int>(
      0,
      (acc, s) => acc + (s.duration?.inSeconds ?? 0),
    );
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  // ── Reorder callback ───────────────────────────────────────────────────────

  // onReorderItem supplies an already-adjusted newIndex (item already removed).
  void _onReorderItem(int oldIndex, int newIndex) {
    setState(() {
      final item = _sermons.removeAt(oldIndex);
      _sermons.insert(newIndex, item);
    });
  }

  // ── Shuffle ────────────────────────────────────────────────────────────────

  void _shuffle() {
    setState(() => _sermons.shuffle());
  }

  @override
  Widget build(BuildContext context) {
    final currentSermon = ref.watch(currentSermonProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      body: CustomScrollView(
        slivers: [
          // ── App bar ────────────────────────────────────────────────────
          SliverAppBar(
            backgroundColor: AppColors.surfaceDark,
            expandedHeight: 0,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new,
                  color: AppColors.textPrimary, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.more_vert,
                    color: AppColors.textPrimary, size: 22),
                onPressed: () {},
              ),
            ],
          ),

          // ── Header ─────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 2×2 mosaic
                  _MosaicArtwork(sermons: _sermons),
                  const SizedBox(height: 20),

                  // Playlist name
                  Text(
                    widget.playlistName,
                    style: GoogleFonts.mavenPro(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Metadata row
                  Text(
                    '${_sermons.length} sermons · ${_totalDuration()}',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: AppColors.textBody,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Shuffle button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _shuffle,
                      icon: const Icon(Icons.shuffle_rounded,
                          size: 18, color: AppColors.textPrimary),
                      label: Text(
                        'Shuffle Play',
                        style: GoogleFonts.dmSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.orange,
                        foregroundColor: AppColors.textPrimary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.button),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // ── Draggable list ─────────────────────────────────────────────
          SliverReorderableList(
            itemCount: _sermons.length,
            onReorderItem: _onReorderItem,
            itemBuilder: (context, index) {
              final sermon = _sermons[index];
              final isPlaying = currentSermon?.id == sermon.id;
              final publishedAt = sermon.publishedAt ?? DateTime.now();

              return ReorderableDelayedDragStartListener(
                key: ValueKey(sermon.id),
                index: index,
                child: SermonListItem(
                  title: sermon.title,
                  speaker: sermon.speaker,
                  duration: sermon.formattedDuration,
                  pubDate: publishedAt,
                  artworkColor: sermon.artworkColor,
                  isPlaying: isPlaying,
                  onTap: () {
                    ref.read(currentSermonProvider.notifier).state = sermon;
                  },
                  trailing: ReorderableDragStartListener(
                    index: index,
                    child: const Icon(
                      Icons.drag_handle_rounded,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                  ),
                ),
              );
            },
          ),

          // Bottom padding
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }
}

// ── 2×2 mosaic widget ─────────────────────────────────────────────────────────

class _MosaicArtwork extends StatelessWidget {
  const _MosaicArtwork({required this.sermons});

  final List<Sermon> sermons;

  @override
  Widget build(BuildContext context) {
    // Take the first 4 (pad with index if fewer).
    final indices = List.generate(
      4,
      (i) => i < sermons.length ? sermons[i].artworkColor : i,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: SizedBox(
        width: 120,
        height: 120,
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  _MosaicTile(gradientColors: _gradientFor(indices[0])),
                  const SizedBox(width: 2),
                  _MosaicTile(gradientColors: _gradientFor(indices[1])),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Expanded(
              child: Row(
                children: [
                  _MosaicTile(gradientColors: _gradientFor(indices[2])),
                  const SizedBox(width: 2),
                  _MosaicTile(gradientColors: _gradientFor(indices[3])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MosaicTile extends StatelessWidget {
  const _MosaicTile({required this.gradientColors});

  final List<Color> gradientColors;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
        ),
      ),
    );
  }
}
