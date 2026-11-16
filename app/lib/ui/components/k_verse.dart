import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../../theme/kharis_theme.dart';
import 'k_icon.dart';

/// A translation footnote marker after a piece of verse text: a small letter
/// that opens the note.
@immutable
class KVerseFootnote {
  const KVerseFootnote({required this.letter, required this.onTap});

  final String letter;
  final VoidCallback onTap;
}

/// One run of scripture inside a [KVerse]: a verse, or the piece of one that
/// falls in this paragraph.
@immutable
class KVersePart {
  const KVersePart({
    required this.text,
    this.number,
    this.highlight,
    this.marked = false,
    this.related = false,
    this.onTap,
    this.footnotes = const [],
  });

  /// The words, with whatever space or line break follows them.
  final String text;

  /// The verse number, shown before the text where the verse starts.
  final int? number;

  /// 1 or 2 for a verse the member highlighted (`verseHighlight1` or
  /// `verseHighlight2` behind the text); null for none.
  final int? highlight;

  /// A verse the member searched for: a primaryTint behind the text.
  final bool marked;

  /// Ends the text with the soundwave marker: this verse has related
  /// messages. Set it on the verse's last part only.
  final bool related;

  /// Opens the verse sheet.
  final VoidCallback? onTap;
  final List<KVerseFootnote> footnotes;
}

/// A block of scripture: one verse, or a paragraph of several. Verse numbers
/// are small and raised in primaryText, the words are in the reading style,
/// and there is no container. Tapping a verse calls its part's `onTap`.
///
/// A highlighted or searched-for verse is tinted behind its words. When the
/// whole block carries one tint, the tint fills the block.
class KVerse extends StatefulWidget {
  const KVerse({
    super.key,
    required this.parts,
    this.indent = 0,
    this.dense = false,
  });

  final List<KVersePart> parts;

  /// Poetry indent levels.
  final int indent;

  /// No space above and below, for consecutive lines of poetry.
  final bool dense;

  @override
  State<KVerse> createState() => _KVerseState();
}

class _KVerseState extends State<KVerse> {
  final _recognizers = <TapGestureRecognizer>[];

  void _releaseRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _releaseRecognizers();
    super.dispose();
  }

  Color? _tint(KharisColors k, KVersePart part) => switch (part.highlight) {
    1 => k.verseHighlight1,
    2 => k.verseHighlight2,
    _ => part.marked ? k.primaryTint : null,
  };

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final parts = widget.parts;
    final body = KharisText.reading.copyWith(color: k.text);
    final number = KharisText.caption.copyWith(
      fontWeight: FontWeight.w800,
      color: k.primaryText,
    );

    // One tint over every part fills the block; otherwise each tinted verse
    // is tinted behind its own words.
    final first = parts.isEmpty ? null : _tint(k, parts.first);
    final blockTint =
        first != null && parts.every((p) => _tint(k, p) == first)
        ? first
        : null;

    _releaseRecognizers();
    final spans = <InlineSpan>[];
    for (final part in parts) {
      final tint = blockTint == null ? _tint(k, part) : null;
      final verse = part.number;
      if (verse != null) {
        spans.add(
          tint != null
              // In the text run, so the tint runs through the number; the
              // height gives the smaller number the body's line box.
              ? TextSpan(
                  text: '$verse\u00A0\u00A0',
                  semanticsLabel: '',
                  style: number.copyWith(
                    backgroundColor: tint,
                    height: body.fontSize! * body.height! / number.fontSize!,
                  ),
                )
              : WidgetSpan(
                  alignment: PlaceholderAlignment.top,
                  child: ExcludeSemantics(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: part.onTap,
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(
                          end: KSpace.sm,
                        ),
                        child: Text('$verse', style: number),
                      ),
                    ),
                  ),
                ),
        );
      }

      TapGestureRecognizer? recognizer;
      if (part.onTap != null) {
        recognizer = TapGestureRecognizer()..onTap = part.onTap;
        _recognizers.add(recognizer);
      }
      final marks = switch (part.highlight) {
        null => '',
        final colour => 'Highlighted, colour $colour. ',
      };
      spans.add(
        TextSpan(
          // The no-break space keeps the marker with the last word.
          text: part.related && part.footnotes.isEmpty
              ? '${part.text.trimRight()}\u00A0'
              : part.text,
          semanticsLabel:
              '${verse == null ? '' : 'Verse $verse. '}$marks${part.text}',
          recognizer: recognizer,
          style: tint == null ? null : TextStyle(backgroundColor: tint),
        ),
      );
      for (final note in part.footnotes) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.top,
            child: Semantics(
              button: true,
              label: 'Footnote ${note.letter}',
              excludeSemantics: true,
              child: GestureDetector(
                key: Key('bible-note-${note.letter}'),
                behavior: HitTestBehavior.opaque,
                onTap: note.onTap,
                // Padding widens the tap target around the small letter.
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: KSpace.xxs,
                    end: KSpace.sm,
                    bottom: KSpace.md,
                  ),
                  child: Text(
                    note.letter,
                    style: KharisText.small.copyWith(color: k.primaryText),
                  ),
                ),
              ),
            ),
          ),
        );
      }
      if (part.related) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: KIcon(
              KIcons.soundwave,
              size: KSize.iconXs,
              color: k.highlightText,
              semanticLabel: 'Has related messages',
            ),
          ),
        );
      }
      // The words that follow start after a space.
      if (part.related || part.footnotes.isNotEmpty) {
        spans.add(const TextSpan(text: ' '));
      }
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: blockTint,
        borderRadius: const BorderRadius.all(Radius.circular(KRadius.xs)),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: KSpace.md + widget.indent * KSpace.x3,
          end: KSpace.md,
          top: widget.dense ? 0 : KSpace.sm,
          bottom: widget.dense ? 0 : KSpace.sm,
        ),
        child: Text.rich(TextSpan(style: body, children: spans)),
      ),
    );
  }
}
