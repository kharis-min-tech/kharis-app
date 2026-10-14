import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' show ProcessingState;

import 'package:kharis_app/core/constants/http_constants.dart';
import 'package:kharis_app/features/giving/presentation/screens/giving_screen.dart';
import 'package:kharis_app/features/notes/presentation/screens/note_editor_screen.dart';
import 'package:kharis_app/features/notes/presentation/widgets/sermon_notes_sheet.dart';
import 'package:kharis_app/features/player/presentation/media_mode.dart';
import 'package:kharis_app/features/player/presentation/widgets/mini_player.dart';
import 'package:kharis_app/features/player/presentation/widgets/seek_bar.dart';
import 'package:kharis_app/features/player/presentation/widgets/transcript_sheet.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/providers/notes_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

import '../support/actions.dart';
import '../support/channels.dart';
import '../support/harness.dart';
import '../support/live_data.dart';

/// (e) Player: play, seek, next / previous, audio <-> video keeps the
/// position, a note added then deleted, share text, minimise to the mini
/// player (hidden on Giving), dismiss; the transcript sheet for a message
/// the R2 catalogue says has one.
Future<void> playerJourney(Journey j) async {
  final t = j.tester;
  final r = seeded(effectiveSeed, 'player');
  await j.launch();
  await openMessagesReset(j);
  j.check(await waitArchiveHydrated(j), 'archive loaded');
  final audio = j.c.read(audioPlayerServiceProvider);
  final list = j.c.read(librarySermonsProvider);

  // ── Play ─────────────────────────────────────────────────────────────────
  final first = list.firstWhere((s) => s.hasAudio);
  final row = find.byKey(ValueKey(first.id));
  await scrollUntilFound(t, row, scrollable: messagesScroll);
  await t.tap(row, warnIfMissed: false);
  await pumpUntilFound(t, player, reason: 'player opens');
  j.check(
    modeToggleOf(t).activeMode == MediaMode.audio,
    'audio message opens in audio mode',
  );
  j.check(
    await pumpUntil(
      t,
      () =>
          audio.position > const Duration(seconds: 1) &&
          seekBarOf(t).duration > Duration.zero,
      timeout: const Duration(seconds: 60),
    ),
    '"${first.title}" plays with a known duration',
  );
  await j.shot('playing');

  // ── Seek ─────────────────────────────────────────────────────────────────
  final fraction = 0.3 + r.nextDouble() * 0.4;
  final bar = t.getRect(inPlayer(find.byType(SeekBar)).first);
  await t.tapAt(Offset(bar.left + bar.width * fraction, bar.top + 14));
  final duration = seekBarOf(t).duration;
  final want = duration * fraction;
  j.check(
    await pumpUntil(
      t,
      () => (audio.position - want).abs() < duration * 0.06,
      timeout: const Duration(seconds: 20),
    ),
    'seek to ${(fraction * 100).round()}% lands near ${fmt(want)} '
    '(at ${fmt(audio.position)})',
  );

  // ── Next / Previous ──────────────────────────────────────────────────────
  final queue = j.c.read(playbackQueueProvider).valueOrNull;
  j.check(queue != null && queue.hasNext, 'queue built from the list');
  final next = queue?.next;
  if (next != null) {
    await t.tap(inPlayer(find.byIcon(Icons.skip_next_rounded)), warnIfMissed: false);
    j.check(
      await pumpUntil(
        t,
        () => audio.currentSermon?.id == next.id,
        timeout: const Duration(seconds: 20),
      ),
      'Next moves to "${next.title}"',
    );
    await pumpFor(t, const Duration(seconds: 1));
    // Previous restarts a message past 3 s first, then steps back.
    for (var i = 0; i < 2 && audio.currentSermon?.id != first.id; i++) {
      await t.tap(inPlayer(find.byIcon(Icons.skip_previous_rounded)), warnIfMissed: false);
      await pumpUntil(
        t,
        () => audio.currentSermon?.id == first.id,
        timeout: const Duration(seconds: 6),
      );
    }
    j.check(audio.currentSermon?.id == first.id, 'Previous returns to "${first.title}"');
  }

  // ── Audio <-> video keeps the position ───────────────────────────────────
  var current = audio.currentSermon!;
  for (var i = 0; i < 8 && !current.hasVideo; i++) {
    await t.tap(inPlayer(find.byIcon(Icons.skip_next_rounded)), warnIfMissed: false);
    await pumpUntil(t, () => audio.currentSermon?.id != current.id, timeout: const Duration(seconds: 20));
    current = audio.currentSermon!;
  }
  if (!current.hasVideo) {
    j.note('DATA: none of the next 8 messages has a video; switch not exercised');
  } else {
    await _checkModeSwitch(j, current);
  }

  // ── Notes: add at the current time, then delete ──────────────────────────
  await _checkNotes(j);

  // ── Share (OS sheet answered by the harness) ─────────────────────────────
  final sharing = audio.currentSermon!;
  await tapPlayerAction(t, 'Share');
  await pumpUntil(t, () => shares.isNotEmpty, timeout: const Duration(seconds: 5));
  final payload = shares.isEmpty ? '' : shares.last;
  j.check(
    payload.contains('https://kharis-app-47c49.web.app/m/'),
    'share text links into the app (/m/<id>): "$payload"',
  );
  j.check(
    !RegExp(r'youtube\.com|youtu\.be|yetanothersermon\.host').hasMatch(payload),
    'share text carries no third-party links',
  );
  j.note('OS share sheet stubbed by the harness: a headless iOS simulator '
      'cannot dismiss it');
  await pumpFor(t, const Duration(seconds: 1));

  // ── Minimise, mini player, dismiss ───────────────────────────────────────
  await closePlayer(t);
  final mini = find.byType(MiniPlayer);
  j.check(
    await pumpUntil(t, () => mini.evaluate().isNotEmpty),
    'closing the player leaves the mini player',
  );
  j.check(
    find.descendant(of: mini, matching: find.text(sharing.title)).evaluate().isNotEmpty,
    'mini player shows "${sharing.title}"',
  );
  await j.shot('mini-player');
  await tapNav(t, 'Giving');
  await pumpUntilFound(t, find.byType(GivingScreen));
  j.check(mini.evaluate().isEmpty, 'mini player hidden on Giving');
  j.check(audio.currentSermon?.id == sharing.id, 'audio stays loaded on Giving');
  await tapNav(t, 'Home');
  j.check(
    await pumpUntil(t, () => mini.evaluate().isNotEmpty),
    'mini player back on Home',
  );
  await t.tap(find.descendant(of: mini, matching: find.text(sharing.title)), warnIfMissed: false);
  j.check(
    await pumpUntil(t, () => player.evaluate().isNotEmpty),
    'tapping the mini player reopens the player',
  );
  j.check(
    inPlayer(find.text(sharing.title)).evaluate().isNotEmpty,
    'reopened player shows "${sharing.title}"',
  );
  await closePlayer(t);
  await t.drag(mini, const Offset(0, 200), warnIfMissed: false);
  j.check(
    await pumpUntil(t, () => mini.evaluate().isEmpty, timeout: const Duration(seconds: 10)),
    'swiping the mini player down dismisses it',
  );
  j.check(audio.currentSermon == null, 'dismissing stops playback');

  // ── Transcript (message picked from the R2 catalogue) ───────────────────
  await _checkTranscript(j, r);
}

Future<void> _checkModeSwitch(Journey j, Sermon s) async {
  final t = j.tester;
  final audio = j.c.read(audioPlayerServiceProvider);
  await pumpUntil(
    t,
    () => seekBarOf(t).duration > Duration.zero && audio.position > const Duration(seconds: 1),
    timeout: const Duration(seconds: 45),
  );
  final rect = t.getRect(inPlayer(find.byType(SeekBar)).first);
  await t.tapAt(Offset(rect.left + rect.width * 0.25, rect.top + 14));
  await pumpUntil(
    t,
    () => audio.position > seekBarOf(t).duration * 0.2,
    timeout: const Duration(seconds: 20),
  );
  await pumpFor(t, const Duration(seconds: 2));
  final beforeVideo = audio.position;
  final offset = s.videoStart ?? Duration.zero;
  await tapMode(t, 'Video');
  Duration? videoPos;
  final up = await pumpUntil(
    t,
    () {
      if (modeToggleOf(t).activeMode != MediaMode.video) return false;
      final b = seekBarOf(t);
      if (b.duration > Duration.zero && b.position > Duration.zero) {
        videoPos ??= b.position;
        return true;
      }
      return false;
    },
    timeout: const Duration(seconds: 45),
    step: const Duration(milliseconds: 100),
  );
  j.check(up, 'video starts for "${s.title}"');
  if (videoPos != null) {
    final drift = (videoPos! - offset - beforeVideo).abs();
    j.check(
      drift <= const Duration(seconds: 3),
      'audio ${fmt(beforeVideo)} -> video ${fmt(videoPos!)} keeps the '
      'message position (videoStart ${fmt(offset)}, drift ${drift.inMilliseconds} ms)',
    );
  }
  await pumpFor(t, const Duration(seconds: 3));
  await j.shot('video-mode');
  final beforeAudio = seekBarOf(t).position;
  await tapMode(t, 'Audio');
  Duration? audioPos;
  final back = await pumpUntil(
    t,
    () {
      if (modeToggleOf(t).activeMode != MediaMode.audio) return false;
      final st = j.c.read(playerStateProvider).valueOrNull;
      if (st != null && st.playing && st.processingState == ProcessingState.ready) {
        audioPos ??= audio.position;
        return true;
      }
      return false;
    },
    timeout: const Duration(seconds: 45),
    step: const Duration(milliseconds: 100),
  );
  j.check(back, 'back in audio mode and playing');
  if (audioPos != null && beforeAudio > Duration.zero) {
    final drift = (audioPos! - (beforeAudio - offset)).abs();
    j.check(
      drift <= const Duration(seconds: 3),
      'video ${fmt(beforeAudio)} -> audio ${fmt(audioPos!)} keeps the '
      'position (drift ${drift.inMilliseconds} ms)',
    );
  }
}

Future<void> _checkNotes(Journey j) async {
  final t = j.tester;
  final audio = j.c.read(audioPlayerServiceProvider);
  await tapPlayerAction(t, 'Notes');
  await pumpUntilFound(t, find.byType(SermonNotesSheet));
  final add = find.textContaining('Add a note at ');
  j.check(
    await pumpUntil(t, () => add.evaluate().isNotEmpty, timeout: const Duration(seconds: 5)),
    'notes sheet offers "Add a note at mm:ss"',
  );
  if (add.evaluate().isEmpty) return;
  final label = t.widget<Text>(add.first).data ?? '';
  final atTap = audio.position;
  await t.tap(add.first, warnIfMissed: false);
  await pumpUntilFound(t, find.byType(NoteEditorScreen));
  final body = 'E2E note ${DateTime.now().millisecondsSinceEpoch}';
  await t.enterText(
    find.descendant(of: find.byType(NoteEditorScreen), matching: find.byType(TextField)),
    body,
  );
  await pumpFor(t, const Duration(milliseconds: 400));
  await t.tap(find.text('Save'), warnIfMissed: false);
  await pumpUntil(t, () => find.byType(NoteEditorScreen).evaluate().isEmpty);
  await tapPlayerAction(t, 'Notes');
  await pumpUntilFound(t, find.byType(SermonNotesSheet));
  final noteText = find.descendant(of: find.byType(SermonNotesSheet), matching: find.text(body));
  j.check(
    await pumpUntil(t, () => noteText.evaluate().isNotEmpty, timeout: const Duration(seconds: 15)),
    'saved note listed on the message',
  );
  final stamp = label.replaceFirst('Add a note at ', '');
  final m = RegExp(r'^(?:(\d+):)?(\d+):(\d\d)$').firstMatch(stamp);
  final secs = m == null
      ? null
      : int.parse(m.group(1) ?? '0') * 3600 + int.parse(m.group(2)!) * 60 + int.parse(m.group(3)!);
  j.check(
    secs != null && (secs - atTap.inSeconds).abs() <= 2,
    'note stamped at the playback time ($stamp vs ${fmt(atTap)})',
  );
  await j.shot('note-added');
  // Swipe to delete (no confirm dialog).
  if (noteText.evaluate().isNotEmpty) {
    await t.drag(noteText.first, const Offset(-500, 0), warnIfMissed: false);
  }
  j.check(
    await pumpUntil(
      t,
      () => !(j.c.read(notesProvider).valueOrNull ?? const []).any((n) => n.body == body),
      timeout: const Duration(seconds: 15),
    ),
    'swiping the note away deletes it',
  );
  // Leave nothing behind from earlier aborted runs either.
  final repo = j.c.read(notesRepositoryProvider);
  for (final n in (j.c.read(notesProvider).valueOrNull ?? const [])
      .where((n) => n.body.startsWith('E2E note ') || n.body.startsWith('Walkthrough note '))) {
    await repo.delete(n.id);
  }
  if (find.byType(SermonNotesSheet).evaluate().isNotEmpty) {
    Navigator.of(t.element(find.byType(SermonNotesSheet))).pop();
    await pumpFor(t, const Duration(milliseconds: 800));
  }
}

Future<void> _checkTranscript(Journey j, Random r) async {
  final t = j.tester;
  final r2 = await r2Messages();
  final candidates = r2
      .where((m) =>
          '${m['transcript_url'] ?? ''}'.trim().isNotEmpty &&
          '${m['audio_url'] ?? ''}'.trim().isNotEmpty)
      .toList();
  if (candidates.isEmpty) {
    j.note('DATA: no R2 message has a transcript; transcript not exercised');
    return;
  }
  final library = {for (final s in j.c.read(sermonLibraryProvider).sermons) s.id: s};
  final inApp = candidates.where((m) => library.containsKey('${m['id']}')).toList();
  j.check(inApp.isNotEmpty, 'R2 transcript messages are in the app library');
  if (inApp.isEmpty) return;
  final m = pick(r, inApp);
  final sermon = library['${m['id']}']!;
  j.note('transcript message: "${sermon.title}" (${sermon.id})');
  j.check(sermon.hasTranscript, 'app knows "${sermon.title}" has a transcript');
  final path = '${m['transcript_url']}'.trim();
  final url = path.startsWith('http') ? path : '$kR2BucketBaseUrl/$path';
  final text = (await fetchText(url)).trim();
  final opening = text.split(RegExp(r'\s+')).take(6).join(' ');

  await openMessagesReset(j);
  final field = find.byType(TextField).first;
  await t.tap(field, warnIfMissed: false);
  await t.enterText(field, sermon.title);
  final row = find.byKey(ValueKey(sermon.id));
  await pumpUntilFound(t, row, timeout: const Duration(seconds: 30), reason: 'search row');
  FocusManager.instance.primaryFocus?.unfocus();
  await pumpFor(t, const Duration(milliseconds: 500));
  await tapVisible(t, row);
  await pumpUntilFound(t, player);
  await tapPlayerAction(t, 'Transcript');
  await pumpUntilFound(t, find.byType(TranscriptSheet));
  final body = find.descendant(of: find.byType(TranscriptSheet), matching: find.byType(SelectableText));
  final loaded = await pumpUntil(
    t,
    () => body.evaluate().isNotEmpty,
    timeout: const Duration(seconds: 30),
  );
  final shown = loaded ? (t.widget<SelectableText>(body.first).data ?? '') : '';
  String norm(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();
  j.check(
    loaded && norm(shown).contains(norm(opening)),
    'transcript sheet shows the R2 transcript (starts "$opening")',
  );
  await j.shot('transcript');
  Navigator.of(t.element(find.byType(TranscriptSheet))).pop();
  await pumpFor(t, const Duration(milliseconds: 600));
  await closePlayer(t);
  await clearMessagesSearch(t);
}
