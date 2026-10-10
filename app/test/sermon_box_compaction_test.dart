import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:kharis_app/core/services/cache_service.dart';

/// The sermon archive is one large value rewritten on every archive walk.
/// Its box file must stay about one archive in size, not keep every copy.
void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('kharis_hive');
    Hive.init(dir.path);
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test('rewriting the archive does not accumulate dead copies', () async {
    final box = await Hive.openBox<dynamic>(
      'sermons',
      compactionStrategy: CacheService.sermonsCompaction,
    );
    final archive = 'x' * 200000;
    for (var i = 0; i < 20; i++) {
      await box.put('sermon_archive_v2', '$archive$i');
    }
    await box.close();

    // One live copy plus at most a frame or two awaiting compaction; the
    // default strategy leaves all 20 (about 4 MB) on disk.
    expect(
      File('${dir.path}/sermons.hive').lengthSync(),
      lessThan(3 * 200000),
    );
  });
}
