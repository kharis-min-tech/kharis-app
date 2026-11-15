import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/core/utils/playback_timestamp.dart';
import 'package:kharis_app/features/notes/data/note_timeline_key.dart';
import 'package:kharis_app/features/notes/presentation/widgets/sermon_notes_sheet.dart'
    show NoteTimelineBinding;
import 'package:kharis_app/features/player/domain/transcript.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/providers/transcript_provider.dart';
import 'package:kharis_app/ui/components/components.dart';
import 'package:kharis_app/ui/components/k_layout.dart' show kClear;

/// The transcript of one message, following playback the way Apple Podcasts
/// does: the stretch being spoken is highlighted and kept about a third of
/// the way down the view, tapping any stretch (or its timestamp) plays from
/// there, and a search field steps through every mention of a word.
///
/// Opened from the player; mirrors [SermonNotesSheet]'s chrome (grabber,
/// header, scrollable body) so the two sheets read as one feature family.
///
/// Text is fetched lazily by [transcriptProvider] the moment this sheet
/// opens, not any earlier — see that provider for why.
class TranscriptSheet extends ConsumerWidget {
  const TranscriptSheet({super.key, required this.sermon, this.timeline});

  final Sermon sermon;

  /// The engine that owns playback where this sheet was opened (the video
  /// mode of the unified player), its clock already mapped onto the audio
  /// timeline the transcript is stamped on. Null follows the audio service.
  final NoteTimelineBinding? timeline;

  /// How much of the screen's height the sheet's content may take.
  static const double _maxHeightFraction = 0.7;

  static Future<void> show(
    BuildContext context,
    Sermon sermon, {
    NoteTimelineBinding? timeline,
  }) {
    return showKBottomSheet<void>(
      context: context,
      title: 'Transcript',
      builder: (_) => TranscriptSheet(sermon: sermon, timeline: timeline),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      // Lift the sheet over the keyboard while the member searches.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * _maxHeightFraction,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(context),
            Flexible(child: _body(context, ref)),
          ],
        ),
      ),
    );
  }

  /// The message the transcript belongs to, and the close button.
  Widget _header(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          sermon.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: KharisText.meta.copyWith(color: context.k.muted),
        ),
      ),
      KIconButton(
        icon: KIcons.close,
        label: 'Close transcript',
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    ],
  );

  Widget _body(BuildContext context, WidgetRef ref) {
    final url = sermon.transcriptUrl;
    if (url == null) {
      return _message(context, 'No transcript is available for this message.');
    }

    return ref
        .watch(transcriptProvider(url))
        .when(
          loading: () => const _TranscriptSkeleton(),
          error: (_, _) => KErrorState(
            message:
                'Couldn’t load the transcript. Check your connection and try '
                'again.',
            onRetry: () => ref.invalidate(transcriptProvider(url)),
          ),
          data: (transcript) => transcript == null
              ? _message(
                  context,
                  'No transcript is available for this message.',
                )
              : _TranscriptReader(
                  sermon: sermon,
                  transcript: transcript,
                  timeline: timeline,
                ),
        );
  }

  Widget _message(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: KSpace.section),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: KharisText.body.copyWith(color: context.k.muted),
      ),
    );
  }
}

/// Lines of text standing in for the transcript while it loads.
class _TranscriptSkeleton extends StatelessWidget {
  const _TranscriptSkeleton();

  static const int _lines = 6;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading transcript',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: KSpace.x3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < _lines; i++) ...[
              if (i > 0) const SizedBox(height: KSpace.xl),
              const KSkeleton(height: KSpace.x3),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Reader ────────────────────────────────────────────────────────────────────

/// The loaded transcript: search bar over the follow-along text.
///
/// Follow-along only runs while THIS message is the one playing (another
/// message on the audio engine highlights nothing) and only for a transcript
/// that carries timestamps. It pauses the moment the member scrolls or steps
/// through search results, and a "Back to now" pill resumes it.
class _TranscriptReader extends ConsumerStatefulWidget {
  const _TranscriptReader({
    required this.sermon,
    required this.transcript,
    required this.timeline,
  });

  final Sermon sermon;
  final Transcript transcript;
  final NoteTimelineBinding? timeline;

  @override
  ConsumerState<_TranscriptReader> createState() => _TranscriptReaderState();
}

class _TranscriptReaderState extends ConsumerState<_TranscriptReader> {
  /// Where the spoken segment sits in the view: about a third of the way
  /// down, leaving what comes next in sight.
  static const double _followAlignment = 1 / 3;
  static const Duration _scrollDuration = Duration(milliseconds: 350);

  final _scroll = ScrollController();
  final _query = TextEditingController();
  late final List<GlobalKey> _segmentKeys = List.generate(
    widget.transcript.segments.length,
    (_) => GlobalKey(),
  );

  StreamSubscription<Duration>? _enginePositions;

  /// The segment being spoken, as last reported by the engine.
  int? _current;

  /// Whether the view keeps the spoken segment in sight.
  bool _following = true;

  /// Whether the view has been brought to "now" once; that first move is a
  /// jump, so the sheet opens where the message is rather than gliding there.
  bool _revealed = false;

  List<TranscriptMatch> _matches = const [];
  int _matchIndex = 0;

  Transcript get _transcript => widget.transcript;

  @override
  void initState() {
    super.initState();
    if (!_transcript.isTimed) return;
    final binding = widget.timeline;
    if (binding != null) {
      _enginePositions = binding.position?.listen(_onPosition);
    } else {
      _current = _transcript.segmentAt(
        ref.read(audioPlayerServiceProvider).position,
      );
    }
    _afterFrame(() {
      if (_live) _follow();
    });
  }

  @override
  void dispose() {
    _enginePositions?.cancel();
    _scroll.dispose();
    _query.dispose();
    super.dispose();
  }

  // ── Playback ───────────────────────────────────────────────────────────────

  /// Whether the transcript follows live playback of this message: timed,
  /// and either bound to the opening screen's engine or the audio service is
  /// playing this very message (any variant of it).
  bool _isLive(Sermon? playing) {
    if (!_transcript.isTimed) return false;
    final binding = widget.timeline;
    if (binding != null) return binding.position != null;
    return playing != null && _sameMessage(playing, widget.sermon);
  }

  bool get _live =>
      _isLive(widget.timeline == null ? ref.read(currentSermonProvider) : null);

  static bool _sameMessage(Sermon a, Sermon b) =>
      NoteTimelineKey.of(a).canonical == NoteTimelineKey.of(b).canonical;

  void _onPosition(Duration position) {
    final index = _transcript.segmentAt(position);
    if (index == _current || !mounted) return;
    if (!_live) {
      // Another message is on air: nothing to show or follow.
      _current = index;
      return;
    }
    setState(() => _current = index);
    if (_following) _afterFrame(_follow);
  }

  /// Whether tapping a segment can move playback: through the opening
  /// screen's engine, else the audio service when this message has audio.
  bool get _canSeek {
    if (!_transcript.isTimed) return false;
    final binding = widget.timeline;
    if (binding != null) return binding.seek != null;
    final playing = ref.read(audioPlayerServiceProvider).currentSermon;
    return widget.sermon.hasAudio ||
        (playing != null &&
            playing.hasAudio &&
            _sameMessage(playing, widget.sermon));
  }

  Future<void> _seekTo(int index) async {
    final start = _transcript.segments[index].start;
    if (start == null) return;
    setState(() {
      _following = true;
      _current = index;
    });
    _reveal(index);

    final engineSeek = widget.timeline?.seek;
    if (engineSeek != null) {
      await engineSeek(start);
      return;
    }

    // Same path as a note anchor: play() attaches to the loaded message and
    // seeks in place, or loads this one when something else is on air.
    final audio = ref.read(audioPlayerServiceProvider);
    final playing = audio.currentSermon;
    final target =
        playing != null &&
            playing.hasAudio &&
            _sameMessage(playing, widget.sermon)
        ? playing
        : widget.sermon;
    final started = await audio.play(
      target,
      startAt: start,
      queue: audio.queue?.items,
    );
    if (started || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Couldn’t play that message. Please try again.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Scrolling ──────────────────────────────────────────────────────────────

  void _afterFrame(VoidCallback action) =>
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) action();
      });

  /// Brings [index] to the follow line: animated, or a jump under reduced
  /// motion.
  void _reveal(int? index, {bool instant = false}) {
    if (index == null) return;
    final target = _segmentKeys[index].currentContext;
    if (target == null) return;
    _revealed = true;
    final jump = instant || MediaQuery.disableAnimationsOf(context);
    unawaited(
      Scrollable.ensureVisible(
        target,
        alignment: _followAlignment,
        duration: jump ? Duration.zero : _scrollDuration,
        curve: Curves.easeInOutCubic,
      ),
    );
  }

  void _follow() => _reveal(_current, instant: !_revealed);

  void _resumeFollowing() {
    setState(() => _following = true);
    _reveal(_current);
  }

  bool _onUserScroll(UserScrollNotification n) {
    if (n.direction != ScrollDirection.idle && _following) {
      setState(() => _following = false);
    }
    return false;
  }

  // ── Search ─────────────────────────────────────────────────────────────────

  void _search(String query) {
    final matches = _transcript.search(query);
    setState(() {
      _matches = matches;
      _matchIndex = 0;
      if (matches.isNotEmpty) _following = false;
    });
    if (matches.isNotEmpty) _afterFrame(() => _reveal(matches.first.segment));
  }

  void _step(int delta) {
    if (_matches.isEmpty) return;
    final next = (_matchIndex + delta) % _matches.length;
    setState(() {
      _matchIndex = next;
      _following = false;
    });
    _afterFrame(() => _reveal(_matches[next].segment));
  }

  void _clearSearch() {
    _query.clear();
    setState(() {
      _matches = const [];
      _matchIndex = 0;
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final audioMode = widget.timeline == null;
    final live = _isLive(audioMode ? ref.watch(currentSermonProvider) : null);
    if (audioMode && _transcript.isTimed) {
      ref.listen<AsyncValue<Duration>>(positionProvider, (_, next) {
        final position = next.valueOrNull;
        if (position != null) _onPosition(position);
      });
    }
    final current = live ? _current : null;
    final canSeek = _canSeek;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SearchBar(
          controller: _query,
          onChanged: _search,
          onSubmitted: (_) => _step(1),
          onCleared: _clearSearch,
        ),
        if (_query.text.trim().isNotEmpty)
          _SearchStatus(
            count: _matches.length,
            index: _matchIndex,
            onPrevious: () => _step(-1),
            onNext: () => _step(1),
          ),
        Flexible(
          child: Stack(
            children: [
              NotificationListener<UserScrollNotification>(
                onNotification: _onUserScroll,
                child: SingleChildScrollView(
                  controller: _scroll,
                  padding: const EdgeInsets.only(
                    top: KSpace.xs,
                    bottom: KSpace.x3,
                  ),
                  child: _segments(context, current, canSeek),
                ),
              ),
              if (live && current != null && !_following)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: KSpace.md,
                  child: Center(
                    child: KButton(
                      label: 'Back to now',
                      variant: KButtonVariant.inverse,
                      onPressed: _resumeFollowing,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _segments(BuildContext context, int? current, bool canSeek) {
    final segments = _transcript.segments;
    final hitsBySegment = <int, List<int>>{};
    for (var i = 0; i < _matches.length; i++) {
      (hitsBySegment[_matches[i].segment] ??= []).add(i);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < segments.length; i++)
          KeyedSubtree(
            key: _segmentKeys[i],
            child: _SegmentTile(
              segment: segments[i],
              showGutter: _transcript.isTimed,
              isCurrent: i == current,
              hits: [
                for (final h in hitsBySegment[i] ?? const <int>[]) _matches[h],
              ],
              activeHit: _matches.isEmpty ? null : _matches[_matchIndex],
              onTap: canSeek && segments[i].start != null
                  ? () => unawaited(_seekTo(i))
                  : null,
            ),
          ),
      ],
    );
  }
}

// ── Pieces ────────────────────────────────────────────────────────────────────

/// One timed stretch of text: its timestamp in a narrow gutter, the words
/// beside it. The spoken stretch sits on a flat surface2 plate in a heavier
/// weight; search hits are marked inline, the one being stepped to in solid
/// primary.
class _SegmentTile extends StatelessWidget {
  const _SegmentTile({
    required this.segment,
    required this.showGutter,
    required this.isCurrent,
    required this.hits,
    required this.activeHit,
    required this.onTap,
  });

  final TranscriptSegment segment;
  final bool showGutter;
  final bool isCurrent;
  final List<TranscriptMatch> hits;
  final TranscriptMatch? activeHit;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final start = segment.start;
    final body = KharisText.body.copyWith(
      fontWeight: isCurrent ? FontWeight.w600 : null,
      color: k.text,
    );
    const radius = BorderRadius.all(Radius.circular(KRadius.tile));

    return MergeSemantics(
      child: Semantics(
        // Only the spoken stretch carries a selected state; the rest stay
        // plain text rather than reading out as "not selected".
        selected: isCurrent ? true : null,
        child: Material(
          color: isCurrent ? k.surface2 : kClear(k.surface2),
          borderRadius: radius,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: KSpace.md,
                vertical: KSpace.sm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showGutter)
                    SizedBox(
                      width: KSize.dateBlockWidth,
                      child: start == null
                          ? null
                          : Padding(
                              padding: const EdgeInsets.only(top: KSpace.xxs),
                              child: Text(
                                formatPlaybackTimestamp(start),
                                maxLines: 1,
                                softWrap: false,
                                style: KharisText.caption.copyWith(
                                  color: isCurrent ? k.primaryText : k.muted,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ),
                    ),
                  Expanded(
                    child: Text.rich(
                      TextSpan(style: body, children: _spans(k)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<TextSpan> _spans(KharisColors k) {
    final text = segment.text;
    if (hits.isEmpty) return [TextSpan(text: text)];
    final spans = <TextSpan>[];
    var at = 0;
    for (final hit in hits) {
      if (hit.start > at) {
        spans.add(TextSpan(text: text.substring(at, hit.start)));
      }
      final active = hit == activeHit;
      spans.add(
        TextSpan(
          text: text.substring(hit.start, hit.end),
          style: TextStyle(
            backgroundColor: active ? k.primary : k.primaryTint,
            color: active ? k.onPrimary : null,
          ),
        ),
      );
      at = hit.end;
    }
    if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
    return spans;
  }
}

/// The search field, with a clear button once something is typed.
class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
    required this.onCleared,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onCleared;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: KSpace.xs),
      child: KSearchField(
        hint: 'Search the transcript',
        controller: controller,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        trailing: controller.text.isEmpty
            ? null
            : KIconButton(
                icon: KIcons.close,
                label: 'Clear search',
                onPressed: onCleared,
              ),
      ),
    );
  }
}

/// "3 of 12" with previous / next, or the empty-result line.
class _SearchStatus extends StatelessWidget {
  const _SearchStatus({
    required this.count,
    required this.index,
    required this.onPrevious,
    required this.onNext,
  });

  final int count;
  final int index;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final style = KharisText.meta.copyWith(color: context.k.muted);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: KSize.touchMin),
      child: count == 0
          ? Align(
              alignment: Alignment.centerLeft,
              child: Text('No matches in this transcript', style: style),
            )
          : Row(
              children: [
                Expanded(
                  child: Text(
                    '${index + 1} of $count',
                    style: style.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                KIconButton(
                  icon: KIcons.chevronUp,
                  label: 'Previous match',
                  onPressed: onPrevious,
                ),
                KIconButton(
                  icon: KIcons.chevronDown,
                  label: 'Next match',
                  onPressed: onNext,
                ),
              ],
            ),
    );
  }
}
