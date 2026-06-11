import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:kharis_app/core/theme/app_colors.dart';
import 'package:kharis_app/core/theme/app_spacing.dart';
import 'package:kharis_app/core/utils/artwork_gradient.dart';
import 'package:kharis_app/features/player/presentation/screens/media_player_screen.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

/// Messages tab - the sermon library as a podcast show page.
///
/// Layout mirrors a Spotify show page in the Kharis system: show header,
/// Following pill, Episodes/About tabs, episode feed with descriptions,
/// per-episode action row, and an accent play button per episode.
class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

/// Episodes loaded per auto-scroll batch.
const int _kPageSize = 15;

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _searchOpen = false;
  int _tab = 0; // 0 = Episodes, 1 = About
  int _visibleCount = _kPageSize;
  bool _batchScheduled = false;

  /// Grows the visible window by one batch after the current frame.
  ///
  /// Triggered from itemBuilder when the trailing rows are laid out, so it
  /// must never call setState synchronously (mid-build/layout). The
  /// post-frame callback is safe on every input method (touch, wheel, fling).
  void _scheduleNextBatch(int total) {
    if (_batchScheduled || _visibleCount >= total) return;
    _batchScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _visibleCount = (_visibleCount + _kPageSize).clamp(0, total);
        _batchScheduled = false;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sermonsAsync = ref.watch(sermonsProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      body: SafeArea(
        child: sermonsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          ),
          error: (_, _) => _ErrorState(
            onRetry: () => ref.invalidate(sermonsProvider),
          ),
          data: (sermons) => _buildShowPage(context, sermons),
        ),
      ),
    );
  }

  Widget _buildShowPage(BuildContext context, List<Sermon> allSermons) {
    final library = ref.watch(librarySermonsProvider);
    final query = _searchQuery.toLowerCase();
    final episodes = query.isEmpty
        ? library
        : library
            .where((s) => s.title.toLowerCase().contains(query))
            .toList();
    final visible = episodes.take(_visibleCount).toList();
    final hasMore = episodes.length > visible.length;
    final showArt =
        allSermons.isNotEmpty ? allSermons.first.artworkUrl : null;

    return RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: AppColors.surfaceElevated,
      onRefresh: () async => ref.invalidate(sermonsProvider),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _ShowHeader(artworkUrl: showArt)),
          SliverToBoxAdapter(child: _actionRow()),
          if (_searchOpen) SliverToBoxAdapter(child: _searchField()),
          SliverToBoxAdapter(child: _tabs()),
          if (_tab == 0) ...[
            SliverToBoxAdapter(child: _filterRow(episodes.length)),
            if (visible.isEmpty)
              const SliverToBoxAdapter(child: _EmptyState())
            else
              SliverList.separated(
                itemCount: visible.length,
                separatorBuilder: (_, _) => const Divider(
                  color: AppColors.surfaceSubtle,
                  height: 1,
                  thickness: 1,
                ),
                itemBuilder: (context, i) {
                  // Building one of the last 3 rows means the user has
                  // scrolled them into view: schedule the next batch.
                  if (hasMore && i >= visible.length - 3) {
                    _scheduleNextBatch(episodes.length);
                  }
                  return _EpisodeTile(sermon: visible[i]);
                },
              ),
              if (hasMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: AppColors.accent,
                          strokeWidth: 2.5,
                        ),
                      ),
                    ),
                  ),
                ),
              const SliverToBoxAdapter(
                child: SizedBox(height: AppSpacing.xxxl),
              ),
            ] else
              const SliverToBoxAdapter(child: _AboutTab()),
          ],
        ),
    );
  }

  // ── Action row: Following pill + bell + search + more ─────────────────────

  Widget _actionRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0,
      ),
      child: Row(
        children: [
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.accent, width: 1.2),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: 6,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            child: Text(
              'Following',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.accent,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: AppColors.textMuted,
              size: 22,
            ),
          ),
          IconButton(
            onPressed: () => setState(() {
              _searchOpen = !_searchOpen;
              if (!_searchOpen) {
                _searchController.clear();
                _searchQuery = '';
              }
            }),
            icon: Icon(
              _searchOpen ? Icons.close_rounded : Icons.search_rounded,
              color: _searchOpen ? AppColors.accent : AppColors.textMuted,
              size: 22,
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.more_horiz_rounded,
              color: AppColors.textMuted,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0,
      ),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        onChanged: (v) => setState(() {
          _searchQuery = v;
          _visibleCount = _kPageSize;
        }),
        style: GoogleFonts.dmSans(color: AppColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search episodes...',
          hintStyle:
              GoogleFonts.dmSans(color: AppColors.textMuted, fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded,
              color: AppColors.textMuted, size: 20),
          filled: true,
          fillColor: AppColors.surfaceSubtle,
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // ── Episodes | About tabs ──────────────────────────────────────────────────

  Widget _tabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0,
      ),
      child: Row(
        children: [
          _TabLabel(
            label: 'Episodes',
            active: _tab == 0,
            onTap: () => setState(() => _tab = 0),
          ),
          const SizedBox(width: AppSpacing.xl),
          _TabLabel(
            label: 'About',
            active: _tab == 1,
            onTap: () => setState(() => _tab = 1),
          ),
        ],
      ),
    );
  }

  // ── Sort • Filter row ──────────────────────────────────────────────────────

  Widget _filterRow(int matchCount) {
    final sort = ref.watch(sermonSortProvider);
    final category = ref.watch(selectedCategoryProvider);
    final label = category == 'All' ? 'All Episodes' : category;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm,
      ),
      child: GestureDetector(
        onTap: _showSortFilterSheet,
        child: Row(
          children: [
            const Icon(Icons.tune_rounded,
                color: AppColors.textPrimary, size: 18),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                '${sort.label} • $label',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '$matchCount episodes',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSortFilterSheet() {
    final labels = ref.read(categoryLabelsProvider);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.75,
            ),
            child: Consumer(
              builder: (context, sheetRef, _) {
                final sort = sheetRef.watch(sermonSortProvider);
                final category = sheetRef.watch(selectedCategoryProvider);

                void resetPaging() =>
                    setState(() => _visibleCount = _kPageSize);

                return ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.lg,
                  ),
                  children: [
                    _sheetHeading('Sort by'),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.sm,
                      ),
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          for (final s in SermonSort.values)
                            ChoiceChip(
                              label: Text(s.label),
                              selected: sort == s,
                              showCheckmark: false,
                              selectedColor:
                                  AppColors.accent.withValues(alpha: 0.18),
                              backgroundColor: AppColors.surfaceSubtle,
                              side: BorderSide(
                                color: sort == s
                                    ? AppColors.accent
                                    : Colors.transparent,
                              ),
                              labelStyle: GoogleFonts.dmSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: sort == s
                                    ? AppColors.accent
                                    : AppColors.textBody,
                              ),
                              onSelected: (_) {
                                sheetRef
                                    .read(sermonSortProvider.notifier)
                                    .state = s;
                                resetPaging();
                              },
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _sheetHeading('Category'),
                    for (final c in labels)
                      ListTile(
                        dense: true,
                        title: Text(
                          c == 'All' ? 'All Episodes' : c,
                          style: GoogleFonts.dmSans(
                            color: category == c
                                ? AppColors.accent
                                : AppColors.textPrimary,
                            fontWeight: category == c
                                ? FontWeight.w700
                                : FontWeight.w400,
                            fontSize: 14,
                          ),
                        ),
                        trailing: category == c
                            ? const Icon(Icons.check_rounded,
                                color: AppColors.accent, size: 20)
                            : null,
                        onTap: () {
                          sheetRef
                              .read(selectedCategoryProvider.notifier)
                              .state = c;
                          resetPaging();
                          Navigator.of(sheetContext).pop();
                        },
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _sheetHeading(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

// ── Show header ───────────────────────────────────────────────────────────────

class _ShowHeader extends StatelessWidget {
  const _ShowHeader({this.artworkUrl});

  final String? artworkUrl;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 96,
              height: 96,
              child: artworkUrl != null
                  ? Image.network(
                      artworkUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const _ArtFallback(size: 96),
                    )
                  : const _ArtFallback(size: 96),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Messages by David Antwi',
                  style: GoogleFonts.mavenPro(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Kharis Church',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtFallback extends StatelessWidget {
  const _ArtFallback({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: sermonGradient(0),
        ),
      ),
      child: Icon(Icons.podcasts_rounded,
          color: Colors.white, size: size * 0.4),
    );
  }
}

// ── Tab label with accent underline ──────────────────────────────────────────

class _TabLabel extends StatelessWidget {
  const _TabLabel({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? AppColors.textPrimary : AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 2.5,
            width: 28,
            decoration: BoxDecoration(
              color: active ? AppColors.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Episode tile (Spotify-style feed row) ─────────────────────────────────────

class _EpisodeTile extends ConsumerWidget {
  const _EpisodeTile({required this.sermon});

  final Sermon sermon;

  void _open(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (context) => MediaPlayerScreen(sermon: sermon),
      ),
    );
  }

  static String _relativeDate(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return DateFormat('EEE').format(dt);
    return DateFormat('d MMM').format(dt);
  }

  static String _durationLabel(Duration? d) {
    if (d == null) return '';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return h > 0 ? '${h}h ${m}min' : '${m}min';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = sermonGradient(sermon.artworkColor ?? 0);
    final meta = [
      _relativeDate(sermon.publishedAt),
      _durationLabel(sermon.duration),
    ].where((s) => s.isNotEmpty).join(' • ');

    return InkWell(
      onTap: () => _open(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Artwork + title
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: sermon.artworkUrl != null
                        ? Image.network(
                            sermon.artworkUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: palette,
                                ),
                              ),
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: palette,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    sermon.title,
                    style: GoogleFonts.mavenPro(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            // Description
            if (sermon.description != null &&
                sermon.description!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                sermon.description!,
                style: GoogleFonts.dmSans(
                  fontSize: 12.5,
                  color: AppColors.textBody,
                  height: 1.45,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            // Meta
            const SizedBox(height: AppSpacing.sm),
            Text(
              meta,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textMuted,
              ),
            ),

            // Actions
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const Icon(Icons.add_circle_outline_rounded,
                    color: AppColors.textMuted, size: 22),
                const SizedBox(width: AppSpacing.xl),
                const Icon(Icons.arrow_circle_down_outlined,
                    color: AppColors.textMuted, size: 22),
                const SizedBox(width: AppSpacing.xl),
                const Icon(Icons.ios_share_rounded,
                    color: AppColors.textMuted, size: 20),
                const SizedBox(width: AppSpacing.xl),
                const Icon(Icons.more_horiz_rounded,
                    color: AppColors.textMuted, size: 22),
                const Spacer(),
                GestureDetector(
                  onTap: () => _open(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── About tab ─────────────────────────────────────────────────────────────────

class _AboutTab extends StatelessWidget {
  const _AboutTab();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weekly messages from Kharis Church with Rev Dr David Antwi. '
            'Sermons, prayer series, and teaching from every branch - '
            'new episodes every week.',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              color: AppColors.textBody,
              height: 1.6,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Hosted by Rev Dr David Antwi',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Kharis Church • Audio via SoundCloud',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty + error states ──────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.search_off_rounded,
                color: AppColors.textMuted, size: 40),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No episodes match',
              style: GoogleFonts.dmSans(
                color: AppColors.textBody,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded,
              color: AppColors.textMuted, size: 40),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Could not load episodes',
            style: GoogleFonts.dmSans(
              color: AppColors.textBody,
              fontSize: 14,
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(
              'Retry',
              style: GoogleFonts.dmSans(
                color: AppColors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
