import 'dart:async';

import 'package:kharis_app/features/messages/data/sermon_repository_base.dart';
import 'package:kharis_app/shared/models/sermon.dart';

/// Serves a scripted archive: page N links to page N+1 until [pages] runs
/// out (the last page has `next == null`).
class FakePagedSermonRepository extends AbstractSermonRepository {
  FakePagedSermonRepository(
    this.pages, {
    this.failFirstLoad = false,
    this.catalogue = const [],
    this.searchPages = const {},
  });

  List<List<Sermon>> pages;
  bool failFirstLoad;
  final List<Sermon> catalogue;

  /// Server search hits per query, paged like [pages].
  final Map<String, List<List<Sermon>>> searchPages;

  /// URLs requested through [fetchPage] (null = page 1).
  final requested = <String?>[];

  /// Search queries requested.
  final searches = <String>[];

  /// When set, the next [fetchPage] call throws once.
  bool failNext = false;

  /// While set, page 1 waits on this before answering.
  Completer<void>? holdFirstPage;

  int get total => pages.fold(0, (n, p) => n + p.length);

  @override
  Future<List<Sermon>> loadCatalogue() async => catalogue;

  @override
  Future<SermonPage> fetchPage({String? url, String? search}) async {
    if (search != null && search.isNotEmpty) {
      searches.add(search);
      return _page(searchPages[search] ?? const [[]], null, 'search=$search');
    }
    if (url != null && url.contains('search=')) {
      final q = Uri.parse(url).queryParameters['search']!;
      return _page(searchPages[q] ?? const [[]], url, 'search=$q');
    }
    requested.add(url);
    if (url == null) await holdFirstPage?.future;
    if (failFirstLoad && url == null) throw StateError('offline');
    if (failNext) {
      failNext = false;
      throw StateError('flaky page');
    }
    return _page(pages, url, '');
  }

  SermonPage _page(List<List<Sermon>> source, String? url, String query) {
    final index = url == null
        ? 0
        : int.parse(Uri.parse(url).queryParameters['page']!) - 1;
    final isLast = index >= source.length - 1;
    final sep = query.isEmpty ? '' : '&$query';
    return SermonPage(
      sermons: source[index],
      nextUrl: isLast ? null : 'https://x.test/sermons/?page=${index + 2}$sep',
      totalCount: source.fold(0, (n, p) => n + p.length),
    );
  }
}

/// A minimal sermon; audio by default, pass `audioUrl: ''` for video-only.
Sermon testSermon(
  String id, {
  String? title,
  DateTime? publishedAt,
  String? audioUrl,
  String? videoId,
  String? series,
  String? description,
  String speaker = 'David Antwi',
  bool isFeatured = false,
  String? source,
}) => Sermon(
  id: id,
  title: title ?? 'Message $id',
  speaker: speaker,
  audioUrl: audioUrl ?? 'https://x.test/$id.mp3',
  publishedAt: publishedAt,
  videoId: videoId,
  series: series,
  description: description,
  isFeatured: isFeatured,
  source: source,
);
