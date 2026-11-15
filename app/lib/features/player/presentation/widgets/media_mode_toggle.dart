import 'package:flutter/material.dart';

import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/ui/components/components.dart';

import '../media_mode.dart';

/// Audio | Video segmented control for the unified player.
///
/// An option is enabled only when the sermon actually carries that medium; a
/// missing medium renders dimmed, non-interactive, with a tooltip and
/// semantics label saying why. The active option sits on the surface plate
/// and never re-fires [onSelect].
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

  KSegment _segment(
    MediaMode mode, {
    required String label,
    required bool available,
    required String disabledReason,
  }) {
    final active = activeMode == mode;
    if (!available) {
      return KSegment(
        label: label,
        semanticLabel: '$label, $disabledReason',
        selected: active,
        enabled: false,
        tooltip: disabledReason,
      );
    }
    return KSegment(
      label: label,
      semanticLabel: active ? '$label, selected' : 'Switch to $label',
      selected: active,
      onTap: active ? null : () => onSelect(mode),
    );
  }

  @override
  Widget build(BuildContext context) {
    return KSegmentedControl(
      segments: [
        _segment(
          MediaMode.audio,
          label: 'Audio',
          available: sermon.hasAudio,
          disabledReason: 'No audio recording for this message',
        ),
        _segment(
          MediaMode.video,
          label: 'Video',
          available: sermon.hasVideo,
          disabledReason: 'No video recording for this message',
        ),
      ],
    );
  }
}
