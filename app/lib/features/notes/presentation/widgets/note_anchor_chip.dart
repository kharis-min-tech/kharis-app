import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:kharis_app/core/theme/theme.dart';

/// Formats a playback position for display on a note: `MM:SS`, or `H:MM:SS`
/// once a message runs past the hour.
String formatNotePosition(int ms) {
  final d = Duration(milliseconds: ms);
  final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (d.inHours > 0) return '${d.inHours}:$minutes:$seconds';
  return '$minutes:$seconds';
}

/// The "which message, and where in it" badge shown on every note.
///
/// When [onTap] is supplied the chip becomes the seek affordance — it grows a
/// play glyph so it reads as an action rather than a label.
class NoteAnchorChip extends StatelessWidget {
  const NoteAnchorChip({
    super.key,
    required this.title,
    this.positionMs,
    this.onTap,
    this.maxWidth = 220,
  });

  final String title;
  final int? positionMs;
  final VoidCallback? onTap;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final position = positionMs;
    final label =
        position != null ? '$title · ${formatNotePosition(position)}' : title;

    final chip = Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            onTap != null ? Icons.play_arrow_rounded : Icons.headphones_outlined,
            size: 14,
            color: AppColors.primary,
          ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return chip;
    return Semantics(
      button: true,
      label: position != null
          ? 'Play $title from ${formatNotePosition(position)}'
          : 'Play $title',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: chip,
      ),
    );
  }
}
