import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/messages/data/sermon_repository.dart';
import '../models/sermon.dart';

// ── Repository ────────────────────────────────────────────────────────────────

final sermonRepositoryProvider = Provider<SermonRepository>((ref) {
  return SermonRepository();
});

// ── Sermons (live fetch) ──────────────────────────────────────────────────────

/// Fetches sermons from the SoundCloud RSS feed.
///
/// Falls back to mock data during development when the feed is unavailable.
final sermonsProvider = FutureProvider<List<Sermon>>((ref) async {
  final repo = ref.watch(sermonRepositoryProvider);
  try {
    return await repo.getSermons();
  } catch (_) {
    // Offline / CI fallback — never leaves the user with an empty screen.
    return repo.getMockSermons();
  }
});

// ── Category filter ───────────────────────────────────────────────────────────

/// The index of the currently selected category chip.
/// 0 = "All" (no filter applied).
final selectedCategoryIndexProvider = StateProvider<int>((ref) => 0);

/// All unique categories derived from the loaded sermons, prefixed with "All".
final categoryLabelsProvider = Provider<List<String>>((ref) {
  final sermonsAsync = ref.watch(sermonsProvider);
  return sermonsAsync.when(
    data: (sermons) {
      final categories = <String>{'All'};
      for (final s in sermons) {
        if (s.category != null) categories.add(s.category!);
      }
      return categories.toList();
    },
    loading: () => const ['All'],
    error: (_, _) => const ['All'],
  );
});

/// Sermons filtered by the selected category chip.
///
/// When "All" (index 0) is selected every sermon is returned.
final filteredSermonsProvider = Provider<List<Sermon>>((ref) {
  final sermonsAsync = ref.watch(sermonsProvider);
  final selectedIndex = ref.watch(selectedCategoryIndexProvider);
  final labels = ref.watch(categoryLabelsProvider);

  return sermonsAsync.when(
    data: (sermons) {
      if (selectedIndex == 0 || selectedIndex >= labels.length) return sermons;
      final category = labels[selectedIndex];
      return sermons.where((s) => s.category == category).toList();
    },
    loading: () => const [],
    error: (_, _) => const [],
  );
});

// ── Currently playing sermon ──────────────────────────────────────────────────

final currentSermonProvider = StateProvider<Sermon?>((ref) => null);
