import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kharis_app/core/theme/app_colors.dart';
import 'package:kharis_app/core/theme/app_typography.dart';
import 'package:kharis_app/shared/widgets/artwork_image.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

/// Discover / Browse: search the full library plus a grid of topic tiles.
/// Reached from the Home search icon; the dashboard tab bar stays visible.
class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key});

  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  final _controller = TextEditingController();
  String _query = '';

  static const _tileGradients = <List<Color>>[
    [Color(0xFF4A3670), Color(0xFFB9A6E8)],
    [Color(0xFF4E2340), Color(0xFFC98BA8)],
    [Color(0xFF0E7490), Color(0xFF22D3EE)],
    [Color(0xFFC2410C), Color(0xFFFB923C)],
    [Color(0xFF1D4ED8), Color(0xFF60A5FA)],
    [Color(0xFF047857), Color(0xFF34D399)],
    [Color(0xFF9F1239), Color(0xFFFB7185)],
    [Color(0xFF6B5426), Color(0xFFD9B36C)],
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

    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
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
                      style: AppTypography.displayLg.copyWith(
                        fontSize: 30,
                        letterSpacing: -0.6,
                        color: AppColors.heading,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SearchField(
                      controller: _controller,
                      onChanged: (v) => setState(() => _query = v),
                    ),
                    const SizedBox(height: 22),
                  ],
                ),
              ),
            ),

            if (searching)
              _ResultsSliver(results: results)
            else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                  child: Text(
                    'Browse all',
                    style: AppTypography.titleMd.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.heading,
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
        Image.asset('assets/figma/dove_logo.png', height: 22,
            color: Colors.white),
        const SizedBox(width: 8),
        Text(
          'DISCOVER',
          style: AppTypography.labelMd.copyWith(
            fontSize: 12,
            letterSpacing: 2.4,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
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
                color: Color(0xFFCFC8D4), size: 20),
          ),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: AppTypography.bodySm.copyWith(
        fontSize: 14,
        color: AppColors.onSurface,
      ),
      cursorColor: AppColors.secondary,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        hintText: 'Artists, messages, or topics',
        hintStyle: AppTypography.bodySm.copyWith(
          fontSize: 14,
          color: AppColors.textMuted,
        ),
        prefixIcon: const Icon(Icons.search_rounded,
            color: AppColors.textMuted, size: 20),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
              color: AppColors.secondary.withValues(alpha: 0.5)),
        ),
      ),
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
          borderRadius: BorderRadius.circular(20),
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
              style: AppTypography.titleMd.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.15,
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
  const _ResultsSliver({required this.results});

  final List<Sermon> results;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (results.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 40, 20, 0),
          child: Center(
            child: Text(
              'No messages match your search.',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList.separated(
        itemCount: results.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final s = results[i];
          return GestureDetector(
            onTap: () => ref.read(audioPlayerServiceProvider).play(s),
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                SizedBox(
                  width: 52,
                  height: 52,
                  child: ArtworkImage(
                    url: s.artworkUrl,
                    gradientIndex: s.artworkColor ?? i,
                    radius: 11,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        s.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySm.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        s.category != null
                            ? '${s.speaker}  \u00b7  ${s.category}'
                            : s.speaker,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySm.copyWith(
                          fontSize: 12.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
