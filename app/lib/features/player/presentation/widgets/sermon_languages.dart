import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/features/player/data/sermon_localization.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/providers/sermon_localization_provider.dart';

/// Audio and subtitles are independent, as in a multilingual streaming player.
class SermonLanguages extends ConsumerStatefulWidget {
  const SermonLanguages({super.key, required this.sermon});
  final Sermon sermon;

  @override
  ConsumerState<SermonLanguages> createState() => _SermonLanguagesState();
}

class _SermonLanguagesState extends ConsumerState<SermonLanguages> {
  bool _busy = false;
  bool _expanded = false;
  String? _captions;

  @override
  void didUpdateWidget(SermonLanguages oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sermon.id != widget.sermon.id) _captions = null;
  }

  Future<void> _select(SermonLanguageTrack? track) async {
    setState(() => _busy = true);
    var ok = false;
    try {
      ok = await ref
          .read(audioPlayerServiceProvider)
          .selectLanguageTrack(widget.sermon, track);
    } catch (_) {
      // Native audio-session failures must not leave this control disabled.
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not change the audio language. Please try again.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(playbackQueueProvider);
    final service = ref.read(audioPlayerServiceProvider);
    final selected = service.languageTrackFor(widget.sermon);
    if (!_expanded) {
      return TextButton.icon(
        key: const Key('sermon-language-settings'),
        onPressed: () => setState(() => _expanded = true),
        icon: const Icon(Icons.language),
        label: Text(
          selected == null
              ? 'Audio & subtitles'
              : 'Audio: ${selected.label} · Subtitles',
        ),
      );
    }
    final tracks = ref.watch(sermonLanguageTracksProvider(widget.sermon));
    return tracks.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(top: 16),
        child: Text('Loading audio languages…'),
      ),
      error: (_, _) => TextButton.icon(
        onPressed: () =>
            ref.invalidate(sermonLanguageTracksProvider(widget.sermon)),
        icon: const Icon(Icons.refresh),
        label: const Text('Audio languages unavailable · Retry'),
      ),
      data: (items) {
        final choices = [
          ...items,
          // Keep a playing track selectable if its manifest changes meanwhile.
          if (selected != null &&
              !items.any((t) => t.language == selected.language))
            selected,
        ];
        final captionTrack = choices
            .where((t) => t.language == _captions)
            .firstOrNull;
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  DropdownButton<String>(
                    key: const Key('sermon-audio-language'),
                    value: selected?.language ?? 'en',
                    icon: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.language),
                    items: [
                      const DropdownMenuItem(
                        value: 'en',
                        child: Text('Audio: English (original)'),
                      ),
                      for (final t in choices)
                        DropdownMenuItem(
                          value: t.language,
                          child: Text('Audio: ${t.label}'),
                        ),
                    ],
                    onChanged: _busy
                        ? null
                        : (value) => _select(
                            choices
                                .where((t) => t.language == value)
                                .firstOrNull,
                          ),
                  ),
                  DropdownButton<String>(
                    key: const Key('sermon-subtitle-language'),
                    value: captionTrack?.language ?? 'off',
                    items: [
                      const DropdownMenuItem(
                        value: 'off',
                        child: Text('Subtitles: Off'),
                      ),
                      for (final t in choices)
                        DropdownMenuItem(
                          value: t.language,
                          child: Text('Subtitles: ${t.label}'),
                        ),
                    ],
                    onChanged: (value) => setState(
                      () => _captions = value == 'off' ? null : value,
                    ),
                  ),
                ],
              ),
              if (choices.isEmpty)
                const Text(
                  'French audio and subtitles are not available for this message yet.',
                ),
              if (selected != null)
                const Text('AI-translated audio · reviewed by Kharis'),
              if (captionTrack != null)
                _CaptionText(url: captionTrack.subtitlesUrl),
            ],
          ),
        );
      },
    );
  }
}

class _CaptionText extends ConsumerWidget {
  const _CaptionText({required this.url});
  final String url;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(positionProvider).valueOrNull ?? Duration.zero;
    return ref
        .watch(sermonCaptionsProvider(url))
        .when(
          loading: () => const Text('Loading subtitles…'),
          error: (_, _) => TextButton(
            onPressed: () => ref.invalidate(sermonCaptionsProvider(url)),
            child: const Text('Subtitles unavailable · Retry'),
          ),
          data: (cues) {
            final lines = cues
                .where((c) => c.contains(position))
                .map((c) => c.text)
                .join('\n');
            return Container(
              key: const Key('sermon-caption'),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                lines.isEmpty ? '…' : lines,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  height: 1.4,
                ),
              ),
            );
          },
        );
  }
}
