import 'package:chewie/chewie.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

import 'package:kharis_app/core/theme/app_colors.dart';
import 'package:kharis_app/core/theme/app_spacing.dart';
import '../widgets/live_player_web.dart';

const _kDefaultStreamUrl =
    'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8';
const _kDefaultTitle = 'Kharis Live';

/// Full-screen HLS live-stream player.
///
/// Web: rendered via [LivePlayerWeb] — an srcdoc iframe backed by hls.js,
/// which handles Chrome/Firefox. Safari falls through to native HLS.
///
/// Mobile/Desktop: [VideoPlayerController.networkUrl] + [ChewieController]
/// with isLive:true overlaid controls and a pulsing LIVE badge.
///
/// Pass [streamUrl] and [title] via GoRouter query params from `/live`.
/// Defaults to Apple's public test HLS stream so the screen works today
/// without a church-configured ingest URL.
class LiveStreamScreen extends StatefulWidget {
  /// Default public HLS test stream (Apple Bipbop Advanced / fmp4).
  static const defaultStreamUrl = _kDefaultStreamUrl;

  /// Default title shown in the header.
  static const defaultTitle = _kDefaultTitle;

  const LiveStreamScreen({
    super.key,
    this.streamUrl = _kDefaultStreamUrl,
    this.title = _kDefaultTitle,
  });

  final String streamUrl;
  final String title;

  @override
  State<LiveStreamScreen> createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends State<LiveStreamScreen>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  // Web: no async init needed — iframe handles its own loading.
  bool _initialising = true;
  String? _error;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (kIsWeb) {
      // iframe loads synchronously — mark ready before first build.
      _initialising = false;
    } else {
      _initPlayer();
    }
  }

  Future<void> _initPlayer() async {
    if (mounted) {
      setState(() {
        _initialising = true;
        _error = null;
      });
    }

    // Dispose previous controllers on retry.
    _chewieController?.dispose();
    _chewieController = null;
    await _videoController?.dispose();
    _videoController = null;

    try {
      final video = VideoPlayerController.networkUrl(
        Uri.parse(widget.streamUrl),
      );
      _videoController = video;
      await video.initialize();

      if (!mounted) {
        await video.dispose();
        return;
      }

      final chewie = ChewieController(
        videoPlayerController: video,
        isLive: true,
        allowFullScreen: true,
        allowedScreenSleep: false,
        autoPlay: true,
        looping: false,
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.accent,
          handleColor: AppColors.accent,
          bufferedColor: AppColors.accent.withValues(alpha: 0.3),
          backgroundColor: Colors.white12,
        ),
      );
      _chewieController = chewie;

      if (!mounted) {
        chewie.dispose();
        return;
      }

      setState(() => _initialising = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initialising = false;
        _error = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(child: _buildContent()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.mavenPro(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_initialising) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.accent,
          strokeWidth: 2.5,
        ),
      );
    }

    if (!kIsWeb && _error != null) {
      return _buildErrorState();
    }

    return Center(
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Video layer ─────────────────────────────────────────────────
            if (kIsWeb)
              LivePlayerWeb(streamUrl: widget.streamUrl)
            else
              Chewie(controller: _chewieController!),

            // ── Pulsing LIVE badge – top-left ───────────────────────────────
            Positioned(
              top: AppSpacing.md,
              left: AppSpacing.md,
              child: FadeTransition(
                opacity: _pulseAnimation,
                child: _liveBadge(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _liveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'LIVE',
        style: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_tethering_error_rounded,
              color: AppColors.textMuted,
              size: 56,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Stream unavailable',
              style: GoogleFonts.mavenPro(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Unable to connect to the live stream.\nCheck your connection and try again.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: AppColors.textMuted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            FilledButton.icon(
              onPressed: _initPlayer,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxl,
                  vertical: AppSpacing.md,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.lg),
                ),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(
                'Retry',
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
