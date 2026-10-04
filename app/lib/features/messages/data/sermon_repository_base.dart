import 'package:kharis_app/shared/models/sermon.dart';

/// One page of a paginated sermon listing.
class SermonPage {
  const SermonPage({required this.sermons, this.nextUrl, this.totalCount = 0});

  /// Sermons on this page, in server order (newest first).
  final List<Sermon> sermons;

  /// Absolute URL of the next page, or `null` when this is the last page.
  final String? nextUrl;

  /// Total sermons available across all pages (0 when the source doesn't say).
  final int totalCount;

  bool get hasMore => nextUrl != null;
}

/// Contract for the member sermon library source.
abstract class AbstractSermonRepository {
  /// Loads the guaranteed offline catalogue (bundled asset; never empty).
  Future<List<Sermon>> loadCatalogue();

  /// Fetches one page of the library.
  ///
  /// [url] is the absolute `next` link from a previous page; `null` means the
  /// first page. [search] applies a server-side text search to the first page;
  /// follow the returned `next` link for more hits.
  ///
  /// Errors propagate: a paging caller must tell "archive ended" from
  /// "request failed".
  Future<SermonPage> fetchPage({String? url, String? search});
}
