import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/sermon.dart';
import '../../../../shared/providers/audio_provider.dart';

/// Floating action button that loads a mock sermon into the audio service so
/// the mini player can be tested without a real network call.
///
/// Uses a short public-domain MP3 so playback actually works offline.
class PlayDemoButton extends ConsumerWidget {
  const PlayDemoButton({super.key});

  // A real streamable MP3 so just_audio can actually play something.
  static const _demoSermon = Sermon(
    id: 'demo_1',
    title: 'Walking in Faith',
    speaker: 'Pastor Kharis',
    audioUrl:
        'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
    duration: Duration(seconds: 372),
    artworkColor: 0,
    category: 'Faith',
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSermon = ref.watch(currentSermonProvider);
    final service = ref.read(audioPlayerServiceProvider);

    if (currentSermon != null) {
      // Audio is loaded — show a stop button instead so we can dismiss.
      return FloatingActionButton.small(
        backgroundColor: AppColors.orange,
        tooltip: 'Stop playback',
        onPressed: () => service.stop(),
        child: const Icon(Icons.stop_rounded, color: Colors.white),
      );
    }

    return FloatingActionButton.extended(
      backgroundColor: AppColors.orange,
      label: const Text(
        'Play Demo',
        style: TextStyle(color: Colors.white),
      ),
      icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
      onPressed: () => service.play(_demoSermon),
    );
  }
}
