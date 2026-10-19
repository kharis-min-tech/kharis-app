import 'dart:math';

import 'package:flutter/material.dart';
import 'package:kharis_app/features/player/presentation/widgets/player_controls.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' show ProcessingState;

import 'package:kharis_app/core/constants/http_constants.dart';
import 'package:kharis_app/features/giving/presentation/screens/giving_screen.dart';
import 'package:kharis_app/features/notes/presentation/widgets/sermon_notes_sheet.dart';
import 'package:kharis_app/features/player/domain/transcript.dart';
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
/// position, the notepad (stamp the time, save, reopen, seek back, restore),
/// share text, minimise to the mini player (hidden on Giving), dismiss; the
/// transcript sheet for a message the R2 catalogue says has one.
/// The transport row's buttons only: the Up next card below it reuses the
/// skip-next glyph.
Finder _transport(Finder f) =>
    find.descendant(of: find.byType(PlayerControls), matching: f).first;

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
    await t.tap(
      _transport(find.byIcon(Icons.skip_next_rounded)),
      warnIfMissed: false,
    );
    j.check(
      await pumpUntil(
        t,
        () => audio.currentSermon?.id == next.id,
        timeout: const Duration(seconds: 20),
      ),
      'Next moves to "${next.title}"',
    );
    await pumpFor(t, const Duration(seconds: 1));
    // Previous restarts a message past 3 s first, then steps back. After a
    // restart the second tap must come at once: waiting lets playback pass
    // 3 s again, and the tap would only restart it a second time.
    for (var i = 0; i < 2 && audio.currentSermon?.id != first.id; i++) {
      await t.tap(
        _transport(find.byIcon(Icons.skip_previous_rounded)),
        warnIfMissed: false,
      );
      await pumpUntil(
        t,
        () =>
            audio.currentSermon?.id == first.id ||
            audio.position < const Duration(seconds: 2),
        timeout: const Duration(seconds: 6),
      );
    }
    j.check(
      audio.currentSermon?.id == first.id,
      'Previous returns to "${first.title}"',
    );
  }

  // ── Audio <-> video keeps the position ───────────────────────────────────
  var current = audio.currentSermon!;
  for (var i = 0; i < 8 && !current.hasVideo; i++) {
    await t.tap(
      _transport(find.byIcon(Icons.skip_next_rounded)),
      warnIfMissed: false,
    );
    await pumpUntil(
      t,
      () => audio.currentSermon?.id != current.id,
      timeout: const Duration(seconds: 20),
    );
    current = audio.currentSermon!;
  }
  if (!current.hasVideo) {
    j.note(
      'DATA: none of the next 8 messages has a video; switch not exercised',
    );
  } else {
    await _checkModeSwitch(j, current);
  }

  // ── Notes: stamp the time in the notepad, seek back to it, restore ───────
  await _checkNotes(j);

  // ── Share (OS sheet answered by the harness) ─────────────────────────────
  final sharing = audio.currentSermon!;
  await tapPlayerAction(t, 'Share');
  await pumpUntil(
    t,
    () => shares.isNotEmpty,
    timeout: const Duration(seconds: 5),
  );
  final payload = shares.isEmpty ? '' : shares.last;
  j.check(
    payload.contains('https://kharis-app-47c49.web.app/m/'),
    'share text links into the app (/m/<id>): "$payload"',
  );
  j.check(
    !RegExp(r'youtube\.com|youtu\.be|yetanothersermon\.host').hasMatch(payload),
    'share text carries no third-party links',
  );
  j.note(
    'OS share sheet stubbed by the harness: a headless iOS simulator '
    'cannot dismiss it',
  );
  await pumpFor(t, const Duration(seconds: 1));

  // ── Minimise, mini player, dismiss ───────────────────────────────────────
  await closePlayer(t);
  final mini = find.byType(MiniPlayer);
  j.check(
    await pumpUntil(t, () => mini.evaluate().isNotEmpty),
    'closing the player leaves the mini player',
  );
  j.check(
    find
        .descendant(of: mini, matching: find.text(sharing.title))
        .evaluate()
        .isNotEmpty,
    'mini player shows "${sharing.title}"',
  );
  await j.shot('mini-player');
  await tapNav(t, 'Giving');
  await pumpUntilFound(t, find.byType(GivingScreen));
  j.check(mini.evaluate().isEmpty, 'mini player hidden on Giving');
  j.check(
    audio.currentSermon?.id == sharing.id,
    'audio stays loaded on Giving',
  );
  await tapNav(t, 'Home');
  j.check(
    await pumpUntil(t, () => mini.evaluate().isNotEmpty),
    'mini player back on Home',
  );
  await t.tap(
    find.descendant(of: mini, matching: find.text(sharing.title)),
    warnIfMissed: false,
  );
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
    await pumpUntil(
      t,
      () => mini.evaluate().isEmpty,
      timeout: const Duration(seconds: 10),
    ),
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
    () =>
        seekBarOf(t).duration > Duration.zero &&
        audio.position > const Duration(seconds: 1),
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
      if (st != null &&
          st.playing &&
          st.processingState == ProcessingState.ready) {
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
  final sheet = find.byType(SermonNotesSheet);
  Finder inSheet(Finder f) => find.descendant(of: sheet, matching: f);
  final field = inSheet(find.byType(TextField));
  TextEditingController pad() => t.widget<TextField>(field).controller!;

  Future<void> closeSheet() async {
    await t.tap(inSheet(find.text('Done')), warnIfMissed: false);
    await pumpUntil(t, () => sheet.evaluate().isEmpty);
  }

  await tapPlayerAction(t, 'Notes');
  await pumpUntilFound(t, field);
  // Restored at the end: the notepad may hold the account's own notes.
  final before = pad().text;
  final insert = inSheet(find.textContaining(RegExp(r'^Insert \d')));
  j.check(
    await pumpUntil(
      t,
      () => insert.evaluate().isNotEmpty,
      timeout: const Duration(seconds: 5),
    ),
    'notepad offers "Insert m:ss"',
  );
  if (insert.evaluate().isEmpty) return closeSheet();
  final stamp = (t.widget<Text>(insert.first).data ?? '').replaceFirst(
    'Insert ',
    '',
  );
  final atTap = audio.position;
  // Stamp at the very top, so the stamp's spot on screen is known.
  pad().selection = const TextSelection.collapsed(offset: 0);
  await t.tap(insert.first, warnIfMissed: false);
  await pumpFor(t, const Duration(milliseconds: 300));
  j.check(
    pad().text.startsWith('[$stamp] '),
    'Insert writes [$stamp] at the cursor',
  );
  final m = RegExp(r'^(?:(\d+):)?(\d+):(\d\d)$').firstMatch(stamp);
  final secs = m == null
      ? null
      : int.parse(m.group(1) ?? '0') * 3600 +
            int.parse(m.group(2)!) * 60 +
            int.parse(m.group(3)!);
  j.check(
    secs != null && (secs - atTap.inSeconds).abs() <= 2,
    'stamp is the playback time ($stamp vs ${fmt(atTap)})',
  );

  final body = 'E2E note ${DateTime.now().millisecondsSinceEpoch}';
  await t.enterText(
    field,
    '[$stamp] $body${before.isEmpty ? '' : '\n$before'}',
  );
  await pumpFor(t, const Duration(milliseconds: 400));
  await j.shot('notepad-written');
  await closeSheet();
  j.check(
    await pumpUntil(
      t,
      () => (j.c.read(notesProvider).valueOrNull ?? const []).any(
        (n) => n.body.contains(body),
      ),
      timeout: const Duration(seconds: 15),
    ),
    'closing the notepad saves it',
  );

  await tapPlayerAction(t, 'Notes');
  await pumpUntilFound(t, field);
  j.check(
    pad().text.contains(body),
    'the notepad reopens with what was written',
  );

  // Tapping the stamp seeks back to it.
  if (secs != null) {
    await audio.seek(Duration(seconds: secs + 45));
    await pumpFor(t, const Duration(milliseconds: 800));
    await t.tapAt(
      t.getTopLeft(inSheet(find.byType(EditableText))) + const Offset(8, 8),
    );
    j.check(
      await pumpUntil(
        t,
        () => (audio.position.inSeconds - secs).abs() <= 3,
        timeout: const Duration(seconds: 10),
      ),
      'tapping [$stamp] seeks there (now ${fmt(audio.position)})',
    );
  }

  // Put the notepad back as it was (an empty one is deleted on close).
  await t.enterText(field, before);
  await pumpFor(t, const Duration(milliseconds: 400));
  await closeSheet();
  j.check(
    await pumpUntil(
      t,
      () => !(j.c.read(notesProvider).valueOrNull ?? const []).any(
        (n) => n.body.contains(body),
      ),
      timeout: const Duration(seconds: 15),
    ),
    'the test text is gone from the notepad',
  );
  // Leave nothing behind from earlier aborted runs either.
  final leftover = RegExp(r'^(\[[\d:]+\] )?(E2E|Walkthrough) note ');
  final repo = j.c.read(notesRepositoryProvider);
  for (final n in (j.c.read(notesProvider).valueOrNull ?? const []).where(
    (n) => leftover.hasMatch(n.body),
  )) {
    await repo.delete(n.id);
  }
}

Future<void> _checkTranscript(Journey j, Random r) async {
  final t = j.tester;
  final r2 = await r2Messages();
  final candidates = r2
      .where(
        (m) =>
            '${m['transcript_url'] ?? ''}'.trim().isNotEmpty &&
            '${m['audio_url'] ?? ''}'.trim().isNotEmpty,
      )
      .toList();
  if (candidates.isEmpty) {
    j.note('DATA: no R2 message has a transcript; transcript not exercised');
    return;
  }
  final library = {
    for (final s in j.c.read(sermonLibraryProvider).sermons) s.id: s,
  };
  final inApp =
      candidates.where((m) => library.containsKey('${m['id']}')).toList()
        ..shuffle(r);
  j.check(inApp.isNotEmpty, 'R2 transcript messages are in the app library');
  if (inApp.isEmpty) return;

  // The R2 catalogue lists transcript links whose files are missing (404),
  // so find one message of each kind and check the app handles both.
  ({Sermon sermon, String text})? present;
  Sermon? missing;
  for (final m in inApp.take(40)) {
    if (present != null && missing != null) break;
    final path = '${m['transcript_url']}'.trim();
    final url = path.startsWith('http') ? path : '$kR2BucketBaseUrl/$path';
    final text = await fetchTextOrNull(url);
    final sermon = library['${m['id']}']!;
    if (text == null || text.isEmpty) {
      missing ??= sermon;
    } else {
      present ??= (sermon: sermon, text: text);
    }
  }

  if (present == null) {
    j.note('DATA: none of 40 sampled R2 transcript links resolved');
  } else {
    final sermon = present.sermon;
    j.note('transcript message: "${sermon.title}" (${sermon.id})');
    j.check(
      sermon.hasTranscript,
      'app knows "${sermon.title}" has a transcript',
    );
    // The sheet shows each stretch's words beside its timestamp, markers
    // lifted out of the text: look for the opening words of the first one.
    final opening = Transcript.parse(
      present.text,
    ).segments.first.text.split(' ').take(6).join(' ');
    await _openTranscript(j, sermon);
    final body = find.descendant(
      of: find.byType(TranscriptSheet),
      matching: find.textContaining(opening),
    );
    final loaded = await pumpUntil(
      t,
      () => body.evaluate().isNotEmpty,
      timeout: const Duration(seconds: 30),
    );
    j.check(
      loaded,
      'transcript sheet shows the R2 transcript (starts "$opening")',
    );
    await j.shot('transcript');
    await _closeTranscript(j);
  }

  if (missing == null) {
    j.note('DATA: every sampled R2 transcript link resolved');
  } else {
    j.note('missing transcript file: "${missing.title}" (${missing.id})');
    await _openTranscript(j, missing);
    final none = find.descendant(
      of: find.byType(TranscriptSheet),
      matching: find.text('No transcript is available for this message.'),
    );
    j.check(
      await pumpUntil(
        t,
        () => none.evaluate().isNotEmpty,
        timeout: const Duration(seconds: 30),
      ),
      'a missing transcript file says "No transcript", not a connection error',
    );
    await j.shot('transcript-missing');
    await _closeTranscript(j);
  }
}

Future<void> _openTranscript(Journey j, Sermon sermon) async {
  final t = j.tester;
  await openMessagesReset(j);
  final field = find.byType(TextField).first;
  await t.tap(field, warnIfMissed: false);
  await t.enterText(field, sermon.title);
  final row = find.byKey(ValueKey(sermon.id));
  await pumpUntilFound(
    t,
    row,
    timeout: const Duration(seconds: 30),
    reason: 'search row',
  );
  FocusManager.instance.primaryFocus?.unfocus();
  await pumpFor(t, const Duration(milliseconds: 500));
  await tapVisible(t, row);
  await pumpUntilFound(t, player);
  await tapPlayerAction(t, 'Transcript');
  await pumpUntilFound(t, find.byType(TranscriptSheet));
}

Future<void> _closeTranscript(Journey j) async {
  final t = j.tester;
  Navigator.of(t.element(find.byType(TranscriptSheet))).pop();
  await pumpFor(t, const Duration(milliseconds: 600));
  await closePlayer(t);
  await clearMessagesSearch(t);
}
