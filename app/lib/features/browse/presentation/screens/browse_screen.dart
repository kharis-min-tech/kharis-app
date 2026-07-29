import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:kharis_app/core/constants/app_assets.dart';
import 'package:kharis_app/core/theme/app_colors.dart';
import 'package:kharis_app/core/theme/app_radius.dart';
import 'package:kharis_app/core/theme/app_typography.dart';
import 'package:kharis_app/features/messages/presentation/widgets/sermon_list_item.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

/// Discover / Browse: search the full library plus a grid of topic tiles.
/// Reached from the Home search icon; the dashboard tab bar stays visible.
///
/// Dark "library" aesthetic — matches the Messages tab (ink bg, dark search
/// field, and the shared [SermonListItem] row for results).
class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key});

  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  final _controller = TextEditingController();
  String _query = '';

  /// Brand gradients for topic tiles — purple/magenta lead, warm supporting.
  static const _tileGradients = <List<Color>>[
    [Color(0xFF6D4AFF), Color(0xFF9F7AEA)],
    [Color(0xFF8E1A57), Color(0xFFD43F8D)],
    [Color(0xFF0E7490), Color(0xFF22D3EE)],
    [Color(0xFFC2410C), Color(0xFFFB923C)],
    [Color(0xFF1D4ED8), Color(0xFF60A5FA)],
    [Color(0xFF047857), Color(0xFF34D399)],
    [Color(0xFF9F1239), Color(0xFFFB7185)],
    [Color(0xFF8A5A10), Color(0xFFE9C349)],
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Sermon> _search(List<Sermon> all) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return all.where((s) {
      return s.title.toLowerCase().contains(q) ||
          s.speaker.toLowerCase().contains(q) ||
          (s.series ?? '').toLowerCase().contains(q) ||
          (s.category ?? '').toLowerCase().contains(q);
    }).toList();
  }

  void _openCategory(String label) {
    ref.read(selectedCategoryProvider.notifier).state = label;
    context.go('/messages');
  }

  @override
  Widget build(BuildContext context) {
    final categories =
        ref.watch(categoryLabelsProvider).where((c) => c != 'All').toList();
    final allSermons = ref.watch(sermonsProvider).valueOrNull ?? const [];
    final results = _search(allSermons);
    final searching = _query.trim().isNotEmpty;

    final currentSermon = ref.watch(currentSermonProvider);
    final playing = ref.watch(playerStateProvider).valueOrNull?.playing ?? false;

    return Scaffold(
      backgroundColor: AppColors.ink,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TopBar(onHome: () => context.go('/home')),
                    const SizedBox(height: 18),
                    Text(
                      'Browse',
                      style: AppTypography.display(
                        size: 30,
                        weight: FontWeight.w700,
                        color: AppColors.heading,
                      ).copyWith(letterSpacing: -0.6),
                    ),
                    const SizedBox(height: 16),
                    _SearchField(
                      controller: _controller,
                      onChanged: (v) => setState(() => _query = v),
                      onCleared: () {
                        _controller.clear();
                        setState(() => _query = '');
                      },
                    ),
                    const SizedBox(height: 22),
                  ],
                ),
              ),
            ),

            if (searching)
              _ResultsSliver(
                results: results,
                currentSermonId: currentSermon?.id,
                playing: playing,
              )
            else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                  child: Text(
                    'Browse all',
                    style: AppTypography.ui(
                      size: 16,
                      weight: FontWeight.w800,
                      color: AppColors.darkMuted3,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 1.02,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _CategoryTile(
                      label: categories[i],
                      gradient: _tileGradients[i % _tileGradients.length],
                      onTap: () => _openCategory(categories[i]),
                    ),
                    childCount: categories.length,
                  ),
                ),
              ),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 150)),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onHome});

  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Image.asset(AppAssets.doveWhite, height: 22),
        const SizedBox(width: 8),
        Text(
          'DISCOVER',
          style: AppTypography.ui(
            size: 12,
            weight: FontWeight.w700,
            letterSpacing: 2.4,
            color: AppColors.darkMuted2,
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: onHome,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.06),
            ),
            child: const Icon(Icons.home_outlined,
                color: AppColors.darkMuted, size: 20),
          ),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onCleared,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onCleared;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final hasText = value.text.isNotEmpty;
        return TextField(
          controller: controller,
          onChanged: onChanged,
          style: AppTypography.ui(size: 14, color: AppColors.onSurface),
          cursorColor: AppColors.gold,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: AppColors.darkSurface,
            hintText: 'Artists, messages, or topics',
            hintStyle: AppTypography.ui(size: 14, color: AppColors.darkMuted),
            prefixIcon: const Icon(Icons.search_rounded,
                color: AppColors.darkMuted, size: 20),
            suffixIcon: hasText
                ? GestureDetector(
                    onTap: onCleared,
                    child: const Icon(Icons.close_rounded,
                        color: AppColors.darkMuted, size: 18),
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
              borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
            ),
          ),
        );
      },
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.label,
    required this.gradient,
    required this.onTap,
  });

  final String label;
  final List<Color> gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.card),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
        ),
        child: Stack(
          children: [
            Text(
              label,
              style: AppTypography.ui(
                size: 16,
                weight: FontWeight.w800,
                height: 1.15,
                color: Colors.white,
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.18),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.4)),
                ),
                child: Center(
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultsSliver extends ConsumerWidget {
  const _ResultsSliver({
    required this.results,
    required this.currentSermonId,
    required this.playing,
  });

  final List<Sermon> results;
  final String? currentSermonId;
  final bool playing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (results.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 40, 20, 0),
          child: Center(
            child: Text(
              'No messages match your search.',
              style: AppTypography.ui(size: 14, color: AppColors.darkMuted),
            ),
          ),
        ),
      );
    }
    return SliverList.builder(
      itemCount: results.length,
      itemBuilder: (context, i) {
        final s = results[i];
        final dateLabel = s.publishedAt != null
            ? DateFormat('MMM yyyy').format(s.publishedAt!)
            : '';
        return SermonListItem(
          key: ValueKey(s.id),
          title: s.title,
          speaker: s.speaker,
          category: s.category ?? s.series,
          durationLabel: s.formattedDuration,
          dateLabel: dateLabel,
          artworkColor: s.artworkColor,
          artworkUrl: s.artworkUrl,
          listIndex: i,
          isPlaying: currentSermonId == s.id && playing,
          onTap: () => ref.read(audioPlayerServiceProvider).play(s),
        );
      },
    );
  }
}
