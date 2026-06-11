import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/home/data/live_repository.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';
import 'package:kharis_app/features/player/presentation/screens/media_player_screen.dart';

class LiveBanner extends ConsumerStatefulWidget {
  const LiveBanner({super.key});

  @override
  ConsumerState<LiveBanner> createState() => _LiveBannerState();
}

class _LiveBannerState extends ConsumerState<LiveBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _fadeAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(liveStatusProvider);

    return statusAsync.when(
      data: (status) {
        if (!status.isLive) return const SizedBox.shrink();
        return _buildBanner(context, status);
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildBanner(BuildContext context, LiveStatus status) {
    return GestureDetector(
      onTap: () {
        final sermon = Sermon(
          id: 'live',
          title: status.title ?? 'Live Stream',
          speaker: 'Kharis Church',
          audioUrl: '',
          videoId: status.videoId,
          source: 'youtube',
        );
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(
            builder: (_) => MediaPlayerScreen(sermon: sermon),
          ),
        );
      },
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.redAccent.withValues(alpha: 0.4),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'LIVE NOW',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.redAccent,
                      letterSpacing: 1.2,
                    ),
                  ),
                  if (status.title != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      status.title!,
                      style: GoogleFonts.mavenPro(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.play_circle_fill_rounded,
              color: AppColors.accent,
              size: 36,
            ),
          ],
        ),
      ),
    );
  }
}
