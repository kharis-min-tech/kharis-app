import 'package:flutter/foundation.dart';
import 'package:kharis_app/core/services/content_api.dart';
import 'package:kharis_app/core/utils/media_url.dart';

/// A single announcement: a message from the church.
///
/// Deliberately NOT an event. An event is a dated, located, RSVP-able
/// occurrence and lives in the Studio `events` table behind `Event`; an
/// announcement is a headline plus optional body and image that may expire.
/// Nothing here carries a start time, a venue, or an RSVP.
@immutable
class NewsItem {
  const NewsItem({
    required this.id,
    required this.title,
    required this.type,
    required this.publishedAt,
    this.body,
    this.imageUrl,
    this.branch,
    this.expiresAt,
    this.eventId,
    this.linkUrl,
    this.ctaLabel,
  });

  /// The announcement categories. `Event` is absent by design: anything
  /// with a date and a venue belongs in `events`.
  static const List<String> types = [
    'Announcement',
    'Ministry',
    'Notice',
    'Update',
  ];

  /// Coerces a stored `type` onto [types], so no announcement can present
  /// itself as an event.
  static String normaliseType(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return types.first;
    return types.contains(value) ? value : types.first;
  }

  final String id;
  final String title;
  final String type;
  final DateTime publishedAt;
  final String? body;
  final String? imageUrl;

  /// Campus this announcement is scoped to; `null` means all-campus.
  final String? branch;

  /// When the announcement stops being relevant: end of the chosen day,
  /// Europe/London. `null` means it never expires.
  final DateTime? expiresAt;

  /// The event this announcement promotes; tapping it opens that event.
  /// `null` for a plain message.
  final String? eventId;

  /// Optional call-to-action link (http/https) with its button [ctaLabel].
  final String? linkUrl;

  /// Button text for [linkUrl].
  final String? ctaLabel;

  /// True once [expiresAt] has passed. Expired items must not be shown.
  bool get isExpired {
    final until = expiresAt;
    return until != null && !until.isAfter(DateTime.now());
  }

  /// True while [publishedAt] is still in the future: the Studio scheduled it
  /// and members must not see it yet.
  bool get isScheduled => publishedAt.isAfter(DateTime.now());

  /// What a member may see right now: published and not expired.
  bool get isLive => !isScheduled && !isExpired;

  /// True when this announcement is visible to a member at [memberBranch].
  /// A blank branch is for all branches.
  bool isVisibleTo(String? memberBranch) {
    final scope = branch?.trim() ?? '';
    return scope.isEmpty || memberBranch == null || scope == memberBranch;
  }
}

/// Reads announcements from the Content Studio `news` table.
///
/// The table's columns are not settled yet (it has never held a row), so the
/// mapping accepts every name the Studio is known to use and drops rows it
/// cannot read. An empty table is an empty list.
class NewsRepository {
  NewsRepository({required this._api});

  final ContentApi _api;

  static const _table = 'news';

  /// Live announcements visible to [branch] (that branch's plus those for
  /// all branches; every one when [branch] is null), newest first. Falls
  /// back to the copy saved on this device when the network fails.
  Future<List<NewsItem>> getAnnouncements({String? branch}) async {
    final rows = await _api.load(_table);
    return liveFor(rows, branch: branch);
  }

  /// Published, unexpired, in-scope items of [rows], newest first.
  static List<NewsItem> liveFor(
    List<Map<String, dynamic>> rows, {
    required String? branch,
  }) {
    final items = rows
        .map(fromRow)
        .whereType<NewsItem>()
        .where((n) => n.isLive && n.isVisibleTo(branch))
        .toList();
    return items..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
  }

  /// Studio workspaces whose announcements the app shows: "Mobile App" and
  /// the shared General workspace. Website workspaces (`kharis`, `kp2`) are
  /// for kharis.org.
  static const appWorkspaces = {'app', 'general'};

  /// One row as a [NewsItem]; null without an id or title, when the row is
  /// not published, or when it belongs to a website workspace.
  static NewsItem? fromRow(Map<String, dynamic> row) {
    if (!appWorkspaces.contains(row['workspace'])) return null;
    final id = _text(row['id']);
    final title = _text(row['title']);
    if (id == null || title == null) return null;
    final status = _text(row['status'])?.toLowerCase();
    if (status != null && status != 'published' && status != 'live') {
      return null;
    }
    if (row['is_published'] == false || row['published'] == false) {
      return null;
    }
    final link = _https(
      _first(row, const ['link_url', 'cta_url', 'url', 'link']),
    );
    return NewsItem(
      id: id,
      title: title,
      type: NewsItem.normaliseType(_first(row, const ['type', 'category'])),
      publishedAt:
          _instant(
            _first(row, const [
              'published_at',
              'publish_at',
              'date',
              'created_at',
            ]),
          ) ??
          DateTime.now(),
      body: _first(row, const ['body', 'content', 'description', 'summary']),
      imageUrl: usableMediaUrl(_first(row, const ['image_url', 'image'])),
      branch: _first(row, const ['branch_name', 'branch']),
      expiresAt: _instant(_first(row, const ['expires_at', 'expiry_date'])),
      eventId: _first(row, const ['event_id']),
      linkUrl: link,
      ctaLabel: link == null ? null : _first(row, const ['cta_label']),
    );
  }

  static String? _first(Map<String, dynamic> row, List<String> keys) {
    for (final k in keys) {
      final v = _text(row[k]);
      if (v != null) return v;
    }
    return null;
  }

  static String? _https(String? url) {
    final uri = url == null ? null : Uri.tryParse(url);
    return uri != null &&
            (uri.scheme == 'https' || uri.scheme == 'http') &&
            uri.host.isNotEmpty
        ? url
        : null;
  }

  static DateTime? _instant(String? raw) =>
      raw == null ? null : DateTime.tryParse(raw)?.toLocal();

  static String? _text(Object? v) {
    if (v is! String) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }
}
