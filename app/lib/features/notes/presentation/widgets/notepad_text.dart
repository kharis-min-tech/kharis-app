import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/notes/data/notepad.dart';

/// How a timestamp token reads inside notepad text: a tinted, semibold time
/// with even-width figures, so it scans as a link to that moment.
TextStyle notepadTimestampStyle(BuildContext context, TextStyle? base) =>
    (base ?? const TextStyle()).copyWith(
      color: context.kc.onChip,
      backgroundColor: context.kc.chipBg,
      fontWeight: FontWeight.w600,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

/// Splits [text] into spans, styling every timestamp token and, when
/// [onTap] is given, wiring it up. [recognizers] is the caller's pool,
/// reused across rebuilds and disposed by the caller.
TextSpan _notepadSpan(
  BuildContext context,
  String text, {
  required TextStyle? style,
  List<TapGestureRecognizer> recognizers = const [],
  ValueChanged<Duration>? onTap,
  TextRange composing = TextRange.empty,
}) {
  final stamps = findNoteTimestamps(text);
  final cuts = <int>{
    0,
    text.length,
    for (final s in stamps) ...[s.start, s.end],
    if (composing.isValid && !composing.isCollapsed) ...[
      composing.start,
      composing.end,
    ],
  }.toList()..sort();

  final tokenStyle = notepadTimestampStyle(context, style);
  final children = <InlineSpan>[];
  var stampIndex = 0;
  for (var i = 0; i + 1 < cuts.length; i++) {
    final start = cuts[i];
    final end = cuts[i + 1];
    if (start == end) continue;
    while (stampIndex < stamps.length && stamps[stampIndex].end <= start) {
      stampIndex++;
    }
    final stamp =
        stampIndex < stamps.length &&
            stamps[stampIndex].start <= start &&
            end <= stamps[stampIndex].end
        ? stamps[stampIndex]
        : null;
    var segmentStyle = stamp == null ? style : tokenStyle;
    if (composing.isValid &&
        !composing.isCollapsed &&
        composing.start <= start &&
        end <= composing.end) {
      segmentStyle = (segmentStyle ?? const TextStyle()).merge(
        const TextStyle(decoration: TextDecoration.underline),
      );
    }

    TapGestureRecognizer? recognizer;
    if (stamp != null && onTap != null) {
      final index = stamps.indexOf(stamp);
      while (recognizers.length <= index) {
        recognizers.add(TapGestureRecognizer());
      }
      recognizer = recognizers[index]..onTap = () => onTap(stamp.position);
    }
    children.add(
      TextSpan(
        text: text.substring(start, end),
        style: segmentStyle,
        recognizer: recognizer,
      ),
    );
  }
  return TextSpan(style: style, children: children);
}

/// The notepad's editing controller: plain text underneath, with every
/// `[m:ss]` token painted as a link.
///
/// Paint only: an editable field may not carry span gesture recognizers
/// (RenderEditable asserts on them), so [NotepadEditor] resolves taps on a
/// stamp itself.
class NotepadTextController extends TextEditingController {
  NotepadTextController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (findNoteTimestamps(text).isEmpty) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    return _notepadSpan(
      context,
      text,
      style: style,
      composing: withComposing && value.isComposingRangeValid
          ? value.composing
          : TextRange.empty,
    );
  }
}

/// Read-only notepad text — the notebook's preview — with tappable
/// timestamps.
class NotepadText extends StatefulWidget {
  const NotepadText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.onTimestampTap,
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final ValueChanged<Duration>? onTimestampTap;

  @override
  State<NotepadText> createState() => _NotepadTextState();
}

class _NotepadTextState extends State<NotepadText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      _notepadSpan(
        context,
        widget.text,
        style: widget.style,
        recognizers: _recognizers,
        onTap: widget.onTimestampTap,
      ),
      maxLines: widget.maxLines,
      overflow: widget.maxLines == null ? null : TextOverflow.ellipsis,
    );
  }
}
