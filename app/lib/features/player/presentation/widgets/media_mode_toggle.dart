import 'package:flutter/material.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/shared/models/sermon.dart';

import '../media_mode.dart';

/// Audio | Video segmented toggle for the unified player.
///
/// A chip is enabled only when the sermon actually carries that medium; a
/// missing medium renders greyed-out, non-interactive, with a tooltip and
/// semantics label saying why. The active chip is gold and never re-fires
/// [onSelect].
class MediaModeToggle extends StatelessWidget {
  const MediaModeToggle({
    super.key,
    required this.sermon,
    required this.activeMode,
    required this.onSelect,
  });

  final Sermon sermon;
  final MediaMode activeMode;
  final ValueChanged<MediaMode> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ModeChip(
          label: 'Audio',
          active: activeMode == MediaMode.audio,
          enabled: sermon.hasAudio,
          disabledReason: 'No audio recording for this message',
          onTap: sermon.hasAudio && activeMode != MediaMode.audio
              ? () => onSelect(MediaMode.audio)
              : null,
        ),
        const SizedBox(width: 9),
        _ModeChip(
          label: 'Video',
          active: activeMode == MediaMode.video,
          enabled: sermon.hasVideo,
          disabledReason: 'No video recording for this message',
          onTap: sermon.hasVideo && activeMode != MediaMode.video
              ? () => onSelect(MediaMode.video)
              : null,
        ),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.active,
    required this.enabled,
    required this.disabledReason,
    this.onTap,
  });

  final String label;
  final bool active;
  final bool enabled;
  final String disabledReason;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color bg = active ? context.kc.accent : context.kc.surfaceMuted;
    final Color fg = active
        ? context.kc.onAccent
        : (enabled
            ? context.kc.muted
            : context.kc.muted.withValues(alpha: 0.4));

    final chip = GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          label,
          style: AppTypography.ui(
            size: 13,
            weight: FontWeight.w600,
            color: fg,
          ),
        ),
      ),
    );

    if (!enabled) {
      return Tooltip(
        message: disabledReason,
        child: Semantics(
          button: true,
          enabled: false,
          label: '$label — $disabledReason',
          excludeSemantics: true,
          child: chip,
        ),
      );
    }

    return Semantics(
      button: true,
      selected: active,
      label: active ? '$label, selected' : 'Switch to $label',
      excludeSemantics: true,
      child: chip,
    );
  }
}
