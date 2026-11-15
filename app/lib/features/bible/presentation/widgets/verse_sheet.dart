import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/related_messages_provider.dart';
import 'package:kharis_app/shared/providers/verse_marks_provider.dart';
import 'package:kharis_app/ui/components/components.dart';

/// Opens the OS share sheet with a verse. A provider so tests can stand in
/// for the platform.
final verseShareProvider = Provider<Future<void> Function(String text)>(
  (ref) =>
      (text) => SharePlus.instance.share(ShareParams(text: text)),
);

/// What Share and Copy hand over: the verse, then its reference and version.
String verseShareText({
  required String reference,
  required String text,
  required String version,
}) => '\u201c${text.trim()}\u201d\n$reference ($version)';

/// The verse sheet: the verse and its reference, the two highlight colours
/// and Clear, a note, Share and Copy, and the messages preached from it.
///
/// [reference] and [text] are the verse as the reader shows it, in the
/// version abbreviated [version]. [onPlayMessage] runs after the sheet has
/// closed, with the message tapped and the verse's messages as its queue.
Future<void> showVerseSheet(
  BuildContext context, {
  required VerseRef verse,
  required String reference,
  required String text,
  required String version,
  required void Function(Sermon message, List<Sermon> queue) onPlayMessage,
}) async {
  final played = await showKBottomSheet<Sermon>(
    context: context,
    builder: (_) => VerseSheet(
      verse: verse,
      reference: reference,
      text: text,
      version: version,
    ),
  );
  if (played == null || !context.mounted) return;
  final queue = ProviderScope.containerOf(context)
      .read(
        relatedMessagesProvider((book: verse.book, chapter: verse.chapter)),
      )
      .forVerse(verse.verse);
  onPlayMessage(played, queue);
}

class VerseSheet extends ConsumerStatefulWidget {
  const VerseSheet({
    super.key,
    required this.verse,
    required this.reference,
    required this.text,
    required this.version,
  });

  final VerseRef verse;
  final String reference;
  final String text;
  final String version;

  @override
  ConsumerState<VerseSheet> createState() => _VerseSheetState();
}

class _VerseSheetState extends ConsumerState<VerseSheet> {
  final _note = TextEditingController();

  /// Whether the note field is showing.
  bool _noteOpen = false;

  /// What just happened ("Copied"), read out and shown under the actions.
  String? _status;

  ({String book, int chapter}) get _chapter =>
      (book: widget.verse.book, chapter: widget.verse.chapter);

  @override
  void initState() {
    super.initState();
    final saved = ref.read(chapterMarksProvider(_chapter)).notes[widget
        .verse
        .verse];
    if (saved != null) {
      _note.text = saved.body;
      _noteOpen = true;
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  String get _shareText => verseShareText(
    reference: widget.reference,
    text: widget.text,
    version: widget.version,
  );

  void _highlight(int colour) {
    ref
        .read(verseMarksRepositoryProvider)
        .setHighlight(
          widget.verse,
          colour,
          text: widget.text,
          version: widget.version,
        );
    setState(() => _status = 'Highlighted');
  }

  void _clearHighlight() {
    ref.read(verseMarksRepositoryProvider).clearHighlight(widget.verse);
    setState(() => _status = 'Highlight cleared');
  }

  void _saveNote() {
    final empty = _note.text.trim().isEmpty;
    ref
        .read(verseMarksRepositoryProvider)
        .saveNote(
          widget.verse,
          _note.text,
          text: widget.text,
          version: widget.version,
        );
    FocusScope.of(context).unfocus();
    setState(() {
      _status = empty ? 'Note deleted' : 'Note saved';
      if (empty) _noteOpen = false;
    });
  }

  void _deleteNote() {
    ref.read(verseMarksRepositoryProvider).deleteNote(widget.verse);
    _note.clear();
    FocusScope.of(context).unfocus();
    setState(() {
      _status = 'Note deleted';
      _noteOpen = false;
    });
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _shareText));
    if (mounted) setState(() => _status = 'Copied');
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final verse = widget.verse;
    final marks = ref.watch(chapterMarksProvider(_chapter));
    final highlight = marks.highlights[verse.verse]?.colour;
    final hasNote = marks.notes.containsKey(verse.verse);
    final related = ref
        .watch(relatedMessagesProvider(_chapter))
        .forVerse(verse.verse);
    final status = _status;

    return SingleChildScrollView(
      // Keeps the note field above the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    widget.reference,
                    style: KharisText.section.copyWith(color: k.text),
                  ),
                ),
              ),
              const SizedBox(width: KSpace.md),
              KIconButton(
                key: const Key('verse-sheet-close'),
                icon: KIcons.close,
                label: 'Close',
                variant: KIconButtonVariant.filled,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: KSpace.md),
          Text(
            widget.text,
            key: const Key('verse-sheet-text'),
            style: KharisText.reading.copyWith(color: k.text),
          ),
          const SizedBox(height: KSpace.xs),
          Text(
            widget.version,
            style: KharisText.caption.copyWith(color: k.muted),
          ),
          const SizedBox(height: KSpace.x3),
          Semantics(
            container: true,
            label: 'Highlight',
            child: Wrap(
              spacing: KSpace.md,
              runSpacing: KSpace.md,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final colour in const [1, 2])
                  KHighlightSwatch(
                    key: Key('verse-highlight-$colour'),
                    colour: colour,
                    selected: highlight == colour,
                    onTap: () => _highlight(colour),
                  ),
                KButton(
                  key: const Key('verse-highlight-clear'),
                  label: 'Clear highlight',
                  variant: KButtonVariant.text,
                  onPressed: highlight == null ? null : _clearHighlight,
                ),
              ],
            ),
          ),
          const SizedBox(height: KSpace.xl),
          Wrap(
            spacing: KSpace.md,
            runSpacing: KSpace.md,
            children: [
              KButton(
                key: const Key('verse-note'),
                label: hasNote ? 'Edit note' : 'Add note',
                icon: KIcons.note,
                variant: KButtonVariant.outline,
                onPressed: () => setState(() => _noteOpen = true),
              ),
              KButton(
                key: const Key('verse-share'),
                label: 'Share',
                icon: KIcons.share,
                variant: KButtonVariant.outline,
                onPressed: () =>
                    unawaited(ref.read(verseShareProvider)(_shareText)),
              ),
              KButton(
                key: const Key('verse-copy'),
                label: 'Copy',
                variant: KButtonVariant.outline,
                onPressed: _copy,
              ),
            ],
          ),
          if (status != null) ...[
            const SizedBox(height: KSpace.md),
            Semantics(
              liveRegion: true,
              child: Text(
                status,
                key: const Key('verse-sheet-status'),
                style: KharisText.caption.copyWith(color: k.muted),
              ),
            ),
          ],
          if (_noteOpen) ...[
            const SizedBox(height: KSpace.x3),
            KTextField(
              key: const Key('verse-note-field'),
              label: 'Note',
              hint: 'Write a note on this verse',
              controller: _note,
              textCapitalization: TextCapitalization.sentences,
              keyboardType: TextInputType.multiline,
              minLines: 3,
              maxLines: 6,
            ),
            const SizedBox(height: KSpace.md),
            Wrap(
              spacing: KSpace.md,
              runSpacing: KSpace.md,
              children: [
                KButton(
                  key: const Key('verse-note-save'),
                  label: 'Save note',
                  onPressed: _saveNote,
                ),
                if (hasNote)
                  KButton(
                    key: const Key('verse-note-delete'),
                    label: 'Delete note',
                    variant: KButtonVariant.text,
                    onPressed: _deleteNote,
                  ),
              ],
            ),
          ],
          if (related.isNotEmpty) ...[
            const SizedBox(height: KSpace.gutter),
            Row(
              children: [
                KIcon(
                  KIcons.soundwave,
                  size: KSize.iconXs,
                  color: k.highlightText,
                ),
                const SizedBox(width: KSpace.sm),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      'Related messages',
                      style: KharisText.itemTitle.copyWith(color: k.text),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: KSpace.md),
            KListGroup(
              children: [
                for (final message in related)
                  KListRow(
                    key: Key('verse-related-${message.id}'),
                    title: message.title,
                    meta: message.speaker.isEmpty ? null : message.speaker,
                    leading: KThumbnail(image: _artwork(message)),
                    showChevron: true,
                    onTap: () => Navigator.of(context).pop(message),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The message's artwork at thumbnail size, or null for the placeholder.
ImageProvider? _artwork(Sermon message) {
  final url = message.artworkUrl;
  if (url == null || url.isEmpty) return null;
  const size = 3 * 40;
  return ResizeImage(
    CachedNetworkImageProvider(url),
    width: size,
    height: size,
  );
}
