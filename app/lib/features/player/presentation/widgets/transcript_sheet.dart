import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/core/utils/playback_timestamp.dart';
import 'package:kharis_app/features/notes/data/note_timeline_key.dart';
import 'package:kharis_app/features/notes/presentation/widgets/sermon_notes_sheet.dart'
    show NoteTimelineBinding;
import 'package:kharis_app/features/player/domain/transcript.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/providers/transcript_provider.dart';

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

  static Future<void> show(
    BuildContext context,
    Sermon sermon, {
    NoteTimelineBinding? timeline,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TranscriptSheet(sermon: sermon, timeline: timeline),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      // Lift the sheet over the keyboard while the member searches.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
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
              Flexible(child: _body(context, ref)),
            ],
          ),
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
      AppSpacing.sm,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Transcript',
          style: AppTypography.ui(
            size: 18,
            weight: FontWeight.w700,
            color: context.kc.onBg,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          sermon.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.ui(size: 13, color: context.kc.muted),
        ),
      ],
    ),
  );

  Widget _body(BuildContext context, WidgetRef ref) {
    final url = sermon.transcriptUrl;
    if (url == null) {
      return _message(context, 'No transcript is available for this message.');
    }

    return ref
        .watch(transcriptProvider(url))
        .when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => _message(
            context,
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
            style: AppTypography.ui(
              size: 14,
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
      SnackBar(
        content: const Text('Couldn’t play that message. Please try again.'),
        backgroundColor: AppColors.errorContainer,
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
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.gutter,
                    AppSpacing.xs,
                    AppSpacing.gutter,
                    AppSpacing.lg,
                  ),
                  child: _segments(context, current, canSeek),
                ),
              ),
              if (live && current != null && !_following)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: AppSpacing.sm,
                  child: Center(child: _BackToNowPill(onTap: _resumeFollowing)),
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
/// beside it. The spoken stretch sits on a flat tint; search hits are marked
/// inline, the one being stepped to in solid accent.
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

  static const double _gutterWidth = 56;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    final start = segment.start;
    final body = AppTypography.ui(
      size: 15,
      height: 1.6,
      weight: isCurrent ? FontWeight.w600 : FontWeight.w400,
      color: kc.onBg,
    );

    return MergeSemantics(
      child: Semantics(
        // Only the spoken stretch carries a selected state; the rest stay
        // plain text rather than reading out as "not selected".
        selected: isCurrent ? true : null,
        child: Material(
          color: isCurrent ? kc.chipBg : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 6,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showGutter)
                    SizedBox(
                      width: _gutterWidth,
                      child: start == null
                          ? null
                          : Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(
                                formatPlaybackTimestamp(start),
                                maxLines: 1,
                                softWrap: false,
                                style:
                                    AppTypography.ui(
                                      size: 12,
                                      weight: FontWeight.w600,
                                      color: isCurrent
                                          ? kc.accentInk
                                          : kc.muted,
                                    ).copyWith(
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                              ),
                            ),
                    ),
                  Expanded(
                    child: Text.rich(
                      TextSpan(style: body, children: _spans(kc)),
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

  List<TextSpan> _spans(KharisColors kc) {
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
            backgroundColor: active
                ? kc.accent
                : kc.accent.withValues(alpha: 0.3),
            color: active ? kc.onAccent : null,
          ),
        ),
      );
      at = hit.end;
    }
    if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
    return spans;
  }
}

/// The search field, styled like the Messages search (pill, clear button).
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
    final kc = context.kc;
    OutlineInputBorder pill(BorderSide side) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      borderSide: side,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        0,
        AppSpacing.gutter,
        AppSpacing.xs,
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textInputAction: TextInputAction.search,
        style: AppTypography.ui(size: 15, color: kc.onBg),
        cursorColor: kc.accentInk,
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search the transcript',
          hintStyle: AppTypography.ui(size: 14, color: kc.muted),
          prefixIcon: Icon(Icons.search_rounded, size: 20, color: kc.muted),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: onCleared,
                  icon: Icon(Icons.close_rounded, size: 18, color: kc.muted),
                ),
          border: pill(BorderSide.none),
          enabledBorder: pill(BorderSide.none),
          focusedBorder: pill(BorderSide(color: kc.accentInk, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          filled: true,
          fillColor: kc.surfaceAlt,
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
    final kc = context.kc;
    final style = AppTypography.ui(size: 13, color: kc.muted);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      child: SizedBox(
        height: 40,
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
                  IconButton(
                    tooltip: 'Previous match',
                    onPressed: onPrevious,
                    icon: Icon(Icons.keyboard_arrow_up_rounded, color: kc.onBg),
                  ),
                  IconButton(
                    tooltip: 'Next match',
                    onPressed: onNext,
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: kc.onBg,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Shown while follow-along is paused; brings the spoken segment back.
class _BackToNowPill extends StatelessWidget {
  const _BackToNowPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    return Material(
      color: kc.onBg,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.gutter,
            vertical: 10,
          ),
          child: Text(
            'Back to now',
            style: AppTypography.ui(
              size: 13,
              weight: FontWeight.w600,
              color: kc.surface,
            ),
          ),
        ),
      ),
    );
  }
}
