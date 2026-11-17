import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Verse text of a bundled version: USFM book id -> chapters -> verses, with
/// verse n of chapter c at `[c - 1][n - 1]`.
typedef BundledText = Map<String, List<List<String>>>;

/// A public-domain Bible version shipped inside the app, so it reads offline
/// and needs no YouVersion licence.
///
/// The asset is gzipped JSON built by `tool/build_kjv_asset.py`. It is read
/// and decoded once, off the UI isolate, then held in memory.
class BundledBible {
  BundledBible({
    required this.id,
    required this.abbreviation,
    required this.title,
    required this.copyright,
    required this.asset,
  });

  /// King James Version (1769 text), from seven1m/open-bibles. Keeps its
  /// YouVersion id so a member's choice survives if YouVersion licenses it.
  static final kjv = BundledBible(
    id: 1,
    abbreviation: 'KJV',
    title: 'King James Version',
    copyright: 'Public domain',
    asset: 'assets/bible/kjv.json.gz',
  );

  final int id;
  final String abbreviation;
  final String title;
  final String copyright;
  final String asset;

  Future<BundledText>? _loading;

  /// The whole text, loaded on first use. A failed load is not kept, so the
  /// reader's Retry tries again.
  Future<BundledText> load() async {
    final pending = _loading ??= _read();
    try {
      return await pending;
    } on Object {
      if (identical(_loading, pending)) _loading = null;
      rethrow;
    }
  }

  Future<BundledText> _read() async {
    final data = await rootBundle.load(asset);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    return compute(decodeBundledBible, bytes, debugLabel: 'decodeBundledBible');
  }
}

/// Gunzips and parses a bundled Bible asset. Top level so [compute] can run
/// it on a background isolate.
BundledText decodeBundledBible(Uint8List gzipped) {
  final json = utf8.decode(const GZipDecoder().decodeBytes(gzipped));
  return {
    for (final MapEntry(:key, :value)
        in (jsonDecode(json) as Map<String, dynamic>).entries)
      key: [
        for (final chapter in value as List)
          List<String>.unmodifiable(chapter as List),
      ],
  };
}
