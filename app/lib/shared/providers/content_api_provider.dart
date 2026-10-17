import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/cache_service.dart';
import '../../core/services/content_api.dart';
import 'cache_provider.dart';

/// The Content Studio (Supabase) client, caching each table's last good
/// response in [CacheService]. Without a cache (tests that do not override
/// [cacheServiceProvider]) it simply reads the network.
final contentApiProvider = Provider<ContentApi>((ref) {
  CacheService? cache;
  try {
    cache = ref.watch(cacheServiceProvider);
  } catch (_) {
    cache = null;
  }
  return ContentApi(cache: cache);
});
