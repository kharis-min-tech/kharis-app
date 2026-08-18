import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';

import 'media_player_screen.dart';

/// Full-screen Now Playing, reached from the mini player at `/player`.
///
/// A thin shell over [MediaPlayerScreen]: it captures the currently loaded
/// sermon once and hands it to the unified player in audio mode, so the mini
/// player and every list tap land on the same screen, same toggle, same
/// transport controls.
class FullPlayerScreen extends ConsumerStatefulWidget {
  const FullPlayerScreen({super.key});

  @override
  ConsumerState<FullPlayerScreen> createState() => _FullPlayerScreenState();
}

class _FullPlayerScreenState extends ConsumerState<FullPlayerScreen> {
  /// Captured once: this screen presents the message that was loaded when it
  /// opened. Watching the provider instead would tear the player down the
  /// moment a switch to video stops the audio source and clears the current
  /// sermon.
  Sermon? _sermon;

  @override
  void initState() {
    super.initState();
    _sermon = ref.read(currentSermonProvider);
  }

  @override
  Widget build(BuildContext context) {
    final sermon = _sermon;
    if (sermon == null) return const _NothingPlaying();
    return MediaPlayerScreen(
      key: ValueKey('full-player-${sermon.id}'),
      sermon: sermon,
      mode: MediaMode.audio,
    );
  }
}

/// Reached only when `/player` opens with nothing loaded (e.g. a deep link):
/// the mini player never navigates here without a sermon.
class _NothingPlaying extends StatelessWidget {
  const _NothingPlaying();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: playerAmbientColors(context),
            stops: const [0.0, 0.44, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: context.kc.onBg,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    'Nothing playing yet',
                    style: AppTypography.ui(
                      size: 14,
                      color: context.kc.muted,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
