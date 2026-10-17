import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/core/utils/playback_timestamp.dart';
import 'package:kharis_app/features/notes/data/note_repository.dart';
import 'package:kharis_app/features/notes/data/notepad.dart';
import 'package:kharis_app/features/notes/presentation/widgets/notepad_text.dart';
import 'package:kharis_app/features/notes/presentation/widgets/sermon_notes_sheet.dart'
    show NoteTimelineBinding;
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/providers/notes_provider.dart';

/// One message's notepad: free typing, with the playback moment one tap away.
///
/// Opens with [notes] folded into one text by [composeNotepad] — so notes
/// from older one-note-per-moment builds appear as `[m:ss] text` lines — and
/// autosaves: [saveDelay] after the member stops typing, when the app goes to
/// the background, and when the editor closes. The first save retires the
/// merged notes (see [NoteRepository.saveNotepad]).
///
/// "Insert" writes the active engine's position at the cursor as a `[m:ss]`
/// token; tapping any token calls [onSeek].
class NotepadEditor extends ConsumerStatefulWidget {
  const NotepadEditor({
    super.key,
    required this.notes,
    required this.messageKey,
    required this.title,
    required this.isThisMessage,
    required this.onSeek,
    this.timeline,
  });

  /// Everything stored against this message when the notepad opened.
  final List<Note> notes;

  /// The key the notepad is saved under (canonical where known).
  final String messageKey;

  /// The message title stored with the notepad, for the notebook. Null keeps
  /// whatever the notepad already carries.
  final String? title;

  /// Whether the audio engine's loaded message is this one — only then is its
  /// position this message's. Ignored when [timeline] is supplied.
  final bool Function(Sermon playing) isThisMessage;

  /// Seeks (or starts) playback at a tapped timestamp.
  final Future<void> Function(Duration position) onSeek;

  /// The engine that owns playback where the notepad was opened; null reads
  /// the audio service.
  final NoteTimelineBinding? timeline;

  static const Duration saveDelay = Duration(milliseconds: 800);

  @override
  ConsumerState<NotepadEditor> createState() => _NotepadEditorState();
}

enum _SaveStatus { idle, saving, saved, failed }

class _NotepadEditorState extends ConsumerState<NotepadEditor>
    with WidgetsBindingObserver {
  late final NotepadTextController _controller;
  final FocusNode _focus = FocusNode();
  final GlobalKey _fieldKey = GlobalKey();
  late NoteRepository _repo;

  /// The stored notepad, once there is one.
  Note? _pad;

  /// Notes folded into the text that have not been retired yet.
  late List<String> _pending;

  /// The text as last saved (or as opened, when nothing needs merging).
  late String _savedText;

  Timer? _debounce;
  Future<void> _saves = Future.value();
  _SaveStatus _status = _SaveStatus.idle;

  @override
  void initState() {
    super.initState();
    final draft = composeNotepad(widget.notes);
    _pad = draft.pad;
    _pending = [...draft.replaces];
    _savedText = draft.body;
    _controller = NotepadTextController(text: draft.body)
      ..addListener(_onChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Closing the notepad is a save point — including the lazy merge of
    // older notes, so a notepad that was only read is still migrated.
    unawaited(_flush());
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      unawaited(_flush());
    }
  }

  bool _dirtyFor(String text) => text != _savedText || _pending.isNotEmpty;

  void _onChanged() {
    if (!_dirtyFor(_controller.text)) return;
    _debounce?.cancel();
    _debounce = Timer(NotepadEditor.saveDelay, () => unawaited(_flush()));
  }

  /// Queues a save of the text as it is now. Saves run one at a time.
  ///
  /// Everything the save needs is read here, synchronously: the last flush
  /// runs from [dispose], and completes after the controller is gone.
  Future<void> _flush() {
    _debounce?.cancel();
    final text = _controller.text;
    final repo = _repo;
    final key = widget.messageKey;
    final title = widget.title ?? _pad?.sermonTitle;
    return _saves = _saves.then((_) => _save(text, repo, key, title));
  }

  Future<void> _save(
    String text,
    NoteRepository repo,
    String key,
    String? title,
  ) async {
    if (!_dirtyFor(text)) return;
    final retiring = [..._pending];
    _setStatus(_SaveStatus.saving);
    try {
      final pad = _pad;
      if (text.trim().isEmpty) {
        // Cleared: there is no notepad left to keep.
        for (final id in [?pad?.id, ...retiring]) {
          await repo.delete(id);
        }
        _pad = null;
      } else {
        final now = DateTime.now();
        final next = Note(
          id: pad?.id ?? repo.newId(),
          sermonId: key,
          sermonTitle: title,
          body: text,
          createdAt: pad?.createdAt ?? now,
          updatedAt: now,
        );
        await repo.saveNotepad(next, replaces: retiring);
        _pad = next;
      }
      _savedText = text;
      _pending.removeWhere(retiring.contains);
      _setStatus(_SaveStatus.saved);
    } catch (error) {
      debugPrint('NotepadEditor: save failed — $error');
      _setStatus(_SaveStatus.failed);
    }
  }

  void _setStatus(_SaveStatus status) {
    if (mounted && status != _status) setState(() => _status = status);
  }

  void _insert(Duration position) {
    _controller.value = insertNoteTimestamp(_controller.value, position);
    _focus.requestFocus();
  }

  /// The stamp drawn under [global], if any — hit-tested against the
  /// laid-out glyphs, a little generously for a fingertip.
  Duration? _stampAt(Offset global) {
    final editable = _editableIn(_fieldKey.currentContext?.findRenderObject());
    if (editable == null || !editable.attached) return null;
    final local = editable.globalToLocal(global);
    for (final stamp in findNoteTimestamps(_controller.text)) {
      final boxes = editable.getBoxesForSelection(
        TextSelection(baseOffset: stamp.start, extentOffset: stamp.end),
      );
      for (final box in boxes) {
        if (box.toRect().inflate(6).contains(local)) return stamp.position;
      }
    }
    return null;
  }

  static RenderEditable? _editableIn(RenderObject? root) {
    if (root == null || root is RenderEditable) return root as RenderEditable?;
    RenderEditable? found;
    root.visitChildren((child) => found ??= _editableIn(child));
    return found;
  }

  @override
  Widget build(BuildContext context) {
    _repo = ref.watch(notesRepositoryProvider);
    final textStyle = AppTypography.ui(
      size: 16,
      color: context.kc.onBg,
      height: 1.6,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            // A tap on a stamp seeks; it is claimed before the field sees it,
            // so the cursor stays put and the keyboard stays down.
            child: RawGestureDetector(
              gestures: {
                _StampTapRecognizer:
                    GestureRecognizerFactoryWithHandlers<_StampTapRecognizer>(
                      () => _StampTapRecognizer(
                        stampAt: _stampAt,
                        onStamp: (position) => widget.onSeek(position),
                      ),
                      (_) {},
                    ),
              },
              child: KeyedSubtree(
                key: _fieldKey,
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  maxLines: null,
                  expands: true,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  textAlignVertical: TextAlignVertical.top,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(notepadMaxLength),
                  ],
                  style: textStyle,
                  cursorColor: context.kc.accentInk,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText:
                        'Write as you listen. Insert stamps the moment, so you '
                        'can tap back to it.',
                    hintMaxLines: 3,
                    hintStyle: AppTypography.ui(
                      size: 16,
                      height: 1.6,
                      color: context.kc.muted,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: context.kc.divider)),
          ),
          child: Row(
            children: [
              // Inside the field's tap region: tapping Insert must not
              // dismiss the keyboard mid-thought.
              TextFieldTapRegion(child: _insertButton(context)),
              const Spacer(),
              _statusLabel(context),
            ],
          ),
        ),
      ],
    );
  }

  /// Rebuilt on its own so the ticking position does not repaint the text.
  ///
  /// The position comes from the ACTIVE engine: the [NotepadEditor.timeline]
  /// binding when the opening screen passed one (video mode), otherwise the
  /// audio service — and only while it has this message loaded, so a stamp
  /// never carries another message's time.
  Widget _insertButton(BuildContext context) {
    final binding = widget.timeline;
    if (binding != null) {
      final position = binding.position;
      if (position == null) return _insertBody(context, null);
      return StreamBuilder<Duration>(
        stream: position,
        builder: (context, snapshot) => _insertBody(context, snapshot.data),
      );
    }
    return Consumer(
      builder: (context, ref, _) {
        final playing = ref.watch(currentSermonProvider);
        final live = playing != null && widget.isThisMessage(playing)
            ? ref.watch(positionProvider).valueOrNull
            : null;
        return _insertBody(context, live);
      },
    );
  }

  Widget _insertBody(BuildContext context, Duration? position) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: context.kc.accent,
        foregroundColor: context.kc.onAccent,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 12,
        ),
      ),
      onPressed: position == null ? null : () => _insert(position),
      icon: const Icon(Icons.more_time_rounded, size: 18),
      label: Text(
        position == null
            ? 'Insert time'
            : 'Insert ${formatPlaybackTimestamp(position)}',
        style: AppTypography.ui(
          size: 15,
          weight: FontWeight.w600,
        ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      ),
    );
  }

  Widget _statusLabel(BuildContext context) {
    final (label, color) = switch (_status) {
      _SaveStatus.idle => (null, context.kc.muted),
      _SaveStatus.saving => ('Saving\u2026', context.kc.muted),
      _SaveStatus.saved => ('Saved', context.kc.muted),
      _SaveStatus.failed => ('Couldn\u2019t save', context.kc.danger),
    };
    if (label == null) return const SizedBox.shrink();
    return Text(label, style: AppTypography.ui(size: 13, color: color));
  }
}

/// Claims a quick tap that lands on a stamp, ahead of the text field's own
/// tap handling, and reports the stamp's moment.
///
/// Joins the arena only for pointers that go down on a stamp, and wins it on
/// pointer-up — before the arena's sweep would hand the tap to the field.
/// A pointer that travels past the touch slop, or one the field's long-press
/// or drag recognizers win first, is let go: selecting and scrolling over a
/// stamp work as they always do.
class _StampTapRecognizer extends OneSequenceGestureRecognizer {
  _StampTapRecognizer({required this.stampAt, required this.onStamp});

  final Duration? Function(Offset globalPosition) stampAt;
  final ValueChanged<Duration> onStamp;

  Duration? _target;
  Offset? _downAt;

  @override
  bool isPointerAllowed(PointerDownEvent event) =>
      super.isPointerAllowed(event) && stampAt(event.position) != null;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    _target = stampAt(event.position);
    _downAt = event.position;
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      if ((event.position - _downAt!).distance > kTouchSlop) _giveUp(event);
    } else if (event is PointerUpEvent) {
      final target = _target;
      resolve(GestureDisposition.accepted);
      stopTrackingPointer(event.pointer);
      if (target != null) onStamp(target);
      _target = null;
    } else if (event is PointerCancelEvent) {
      _giveUp(event);
    }
  }

  void _giveUp(PointerEvent event) {
    _target = null;
    resolve(GestureDisposition.rejected);
    stopTrackingPointer(event.pointer);
  }

  @override
  void acceptGesture(int pointer) {}

  @override
  void rejectGesture(int pointer) {
    _target = null;
    stopTrackingPointer(pointer);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  String get debugDescription => 'notepad stamp tap';
}
