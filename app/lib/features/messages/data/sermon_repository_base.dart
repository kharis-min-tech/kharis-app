import 'package:kharis_app/shared/models/sermon.dart';

/// One page of a paginated sermon listing.
class SermonPage {
  const SermonPage({
    required this.sermons,
    this.nextUrl,
    this.totalCount = 0,
  });

  /// Sermons on this page, in server order (newest first).
  final List<Sermon> sermons;

  /// Absolute URL of the next page, or `null` when this is the last page.
  final String? nextUrl;

  /// Total sermons available across all pages (0 when the source doesn't say).
  final int totalCount;

  bool get hasMore => nextUrl != null;
}

/// Contract shared by the RSS repository and the Firestore repository.
abstract class AbstractSermonRepository {
  /// Fetches the freshest sermon list available to this repository.
  Future<List<Sermon>> getSermons();

  /// Loads the guaranteed full catalogue (bundled asset; never empty).
  Future<List<Sermon>> loadCatalogue();

  /// Fetches one page of the library.
  ///
  /// [url] is the absolute `next` link from a previous page; `null` means the
  /// first page. [search] applies a server-side text search (first page only).
  ///
  /// Sources without real pagination serve everything as a single terminal
  /// page, so callers can treat every repository uniformly.
  Future<SermonPage> fetchPage({String? url, String? search}) async {
    final all = await getSermons();
    return SermonPage(sermons: all, totalCount: all.length);
  }
}
