import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/transcript_provider.dart';

/// The full transcript text for one message. Opened from the player, mirrors
/// [SermonNotesSheet]'s chrome (grabber, header, scrollable body) so the two
/// sheets read as the same feature family, not two different UI styles.
///
/// Text is fetched lazily by [transcriptProvider] the moment this sheet
/// opens, not any earlier — see that provider for why.
class TranscriptSheet extends ConsumerWidget {
  const TranscriptSheet({super.key, required this.sermon});

  final Sermon sermon;

  static Future<void> show(BuildContext context, Sermon sermon) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TranscriptSheet(sermon: sermon),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = sermon.transcriptUrl;
    final transcript = url == null
        ? const AsyncValue<String>.data('')
        : ref.watch(transcriptProvider(url));

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        decoration: BoxDecoration(
          color: context.kc.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _grabber(context),
            _header(context),
            Flexible(child: _body(context, ref, transcript)),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  Widget _grabber(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: AppSpacing.sm),
        height: 4,
        width: 40,
        decoration: BoxDecoration(
          color: context.kc.divider,
          borderRadius: BorderRadius.circular(2),
        ),
      );

  Widget _header(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Transcript',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.kc.onBg,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sermon.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: context.kc.muted,
              ),
            ),
          ],
        ),
      );

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<String> transcript,
  ) {
    final url = sermon.transcriptUrl;
    if (url == null) {
      return _message(context, 'No transcript is available for this message.');
    }

    return transcript.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => _message(
        context,
        'Couldn’t load the transcript. Check your connection and try again.',
        onRetry: () => ref.invalidate(transcriptProvider(url)),
      ),
      data: (text) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: SelectableText(
          text,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            height: 1.6,
            color: context.kc.onBg,
          ),
        ),
      ),
    );
  }

  Widget _message(BuildContext context, String text, {VoidCallback? onRetry}) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              height: 1.5,
              color: context.kc.muted,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.md),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ],
      ),
    );
  }
}
