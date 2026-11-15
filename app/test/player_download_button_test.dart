// The player's Download action: its four states, and that it is hidden for a
// message with no audio recording.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kharis_app/features/messages/data/downloads_repository.dart';
import 'package:kharis_app/features/player/presentation/widgets/download_button.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/downloads_provider.dart';
import 'package:kharis_app/theme/kharis_theme.dart';
import 'package:kharis_app/ui/components/components.dart';

import 'support/design_harness.dart';
import 'support/fake_cache_service.dart';

const _sermon = Sermon(
  id: 's1',
  title: 'Grace upon grace',
  speaker: 'Pastor A',
  audioUrl: 'https://cdn.example/s1.mp3',
);

const _videoOnly = Sermon(
  id: 'v1',
  title: 'Sunday service',
  speaker: 'Pastor A',
  audioUrl: '',
  videoId: 'v1',
);

/// A downloads repository whose status the test sets by hand; it records what
/// the button asks of it and touches no files.
class _FakeDownloads extends DownloadsRepository {
  _FakeDownloads()
    : super(
        FakeCacheService(),
        directory: () async => throw const FileSystemException('no storage'),
      );

  DownloadStatus status = const NotDownloaded();
  final List<String> calls = [];

  void set(DownloadStatus next) {
    status = next;
    changes.value++;
  }

  @override
  DownloadStatus statusOf(String sermonId) => status;

  @override
  Future<DownloadStatus> download(Sermon sermon) async {
    calls.add('download ${sermon.id}');
    set(const Downloading(received: 0, total: 100));
    return status;
  }

  @override
  void cancel(String sermonId) {
    calls.add('cancel $sermonId');
    set(const NotDownloaded());
  }

  @override
  Future<void> delete(String sermonId) async {
    calls.add('delete $sermonId');
    set(const NotDownloaded());
  }

  @override
  void clearFailure(String sermonId) {
    calls.add('clearFailure $sermonId');
    if (status is DownloadFailed) set(const NotDownloaded());
  }
}

void main() {
  setUpAll(loadDesignAssets);

  late _FakeDownloads downloads;

  setUp(() {
    downloads = _FakeDownloads();
    addTearDown(downloads.dispose);
  });

  Future<void> pump(
    WidgetTester tester, {
    Sermon sermon = _sermon,
    bool dark = false,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = const Size(KSize.designWidth, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [downloadsRepositoryProvider.overrideWithValue(downloads)],
        child: MaterialApp(
          theme: KharisTheme.light(),
          darkTheme: KharisTheme.dark(),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(
            body: Center(child: DownloadButton(sermon: sermon)),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  final button = find.byKey(const Key('player-download'));

  testWidgets('not downloaded: "Download message" starts the download', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pump(tester);

    expect(find.bySemanticsLabel('Download message'), findsOneWidget);
    expect(tester.getSize(button).shortestSide, greaterThanOrEqualTo(44));

    await tester.tap(button);
    await tester.pump();

    expect(downloads.calls, ['download s1']);
    semantics.dispose();
  });

  testWidgets('downloading: shows progress; a tap cancels', (tester) async {
    final semantics = tester.ensureSemantics();
    downloads.status = const Downloading(received: 40, total: 100);
    await pump(tester);

    final ring = tester.widget<CircularProgressIndicator>(
      find.byKey(const Key('player-download-progress')),
    );
    expect(ring.value, closeTo(0.4, 0.001));
    expect(find.bySemanticsLabel('Cancel download'), findsOneWidget);
    expect(find.bySemanticsLabel('Download message'), findsNothing);

    // Progress moves with the download.
    downloads.set(const Downloading(received: 80, total: 100));
    await tester.pump();
    await tester.pump();
    expect(
      tester
          .widget<CircularProgressIndicator>(
            find.byKey(const Key('player-download-progress')),
          )
          .value,
      closeTo(0.8, 0.001),
    );

    await tester.tap(button);
    await tester.pump();

    expect(downloads.calls, ['cancel s1']);
    expect(find.bySemanticsLabel('Download message'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('downloading with no known size: a ring with no fraction', (
    tester,
  ) async {
    downloads.status = const Downloading(received: 40);
    await pump(tester);

    expect(
      tester
          .widget<CircularProgressIndicator>(
            find.byKey(const Key('player-download-progress')),
          )
          .value,
      isNull,
    );
  });

  testWidgets('downloaded: "Downloaded"; a tap offers Remove download', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    downloads.status = Downloaded(
      DownloadedMessage(
        sermon: _sermon,
        fileName: 's1.mp3',
        bytes: 1024,
        savedAt: DateTime(2026, 11, 11),
      ),
    );
    await pump(tester);

    expect(find.bySemanticsLabel('Downloaded'), findsOneWidget);

    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(find.byType(KBottomSheet), findsOneWidget);
    expect(find.text('Remove download'), findsOneWidget);
    expect(downloads.calls, isEmpty, reason: 'nothing removed before asking');

    await tester.tap(find.text('Remove download'));
    await tester.pumpAndSettle();

    expect(downloads.calls, ['delete s1']);
    expect(find.byType(KBottomSheet), findsNothing);
    expect(find.bySemanticsLabel('Download message'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('downloaded: "Keep download" closes the sheet, removes nothing', (
    tester,
  ) async {
    downloads.status = Downloaded(
      DownloadedMessage(
        sermon: _sermon,
        fileName: 's1.mp3',
        bytes: 1024,
        savedAt: DateTime(2026, 11, 11),
      ),
    );
    await pump(tester);

    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep download'));
    await tester.pumpAndSettle();

    expect(downloads.calls, isEmpty);
    expect(find.byType(KBottomSheet), findsNothing);
  });

  testWidgets('failed: one line saying why, then back to not downloaded', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pump(tester);

    downloads.set(const DownloadFailed(DownloadFailureReason.connection));
    await tester.pump();
    await tester.pump();

    expect(
      find.text(
        DownloadButton.failureMessage(DownloadFailureReason.connection),
      ),
      findsOneWidget,
    );
    expect(downloads.calls, ['clearFailure s1']);
    expect(downloads.status, isA<NotDownloaded>());
    expect(find.bySemanticsLabel('Download message'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('a failure left from earlier is reported once on opening', (
    tester,
  ) async {
    downloads.status = const DownloadFailed(DownloadFailureReason.noSpace);
    await pump(tester);
    await tester.pump();

    expect(
      find.text(DownloadButton.failureMessage(DownloadFailureReason.noSpace)),
      findsOneWidget,
    );
    expect(downloads.calls, ['clearFailure s1']);
  });

  test('every failure reason has its own one-line message', () {
    final messages = DownloadFailureReason.values
        .map(DownloadButton.failureMessage)
        .toSet();
    expect(messages.length, DownloadFailureReason.values.length);
    for (final message in messages) {
      expect(message, isNot(contains('\n')));
    }
  });

  testWidgets('hidden for a message with no audio', (tester) async {
    await pump(tester, sermon: _videoOnly);

    expect(button, findsNothing);
    expect(find.byType(KIconButton), findsNothing);
  });

  for (final dark in const [false, true]) {
    for (final scale in const [1.0, KRatio.largeTextScale]) {
      testWidgets('every state lays out at 390 wide '
          '(${dark ? 'dark' : 'light'}, ${(scale * 100).round()}%)', (
        tester,
      ) async {
        for (final status in <DownloadStatus>[
          const NotDownloaded(),
          const Downloading(received: 1, total: 4),
          Downloaded(
            DownloadedMessage(
              sermon: _sermon,
              fileName: 's1.mp3',
              bytes: 1024,
              savedAt: DateTime(2026, 11, 11),
            ),
          ),
        ]) {
          downloads.status = status;
          await pump(tester, dark: dark, textScale: scale);
          expect(tester.takeException(), isNull, reason: '$status');
          expect(tester.getSize(button).shortestSide, greaterThanOrEqualTo(44));
          await tester.pumpWidget(const SizedBox());
        }
      });
    }
  }
}
