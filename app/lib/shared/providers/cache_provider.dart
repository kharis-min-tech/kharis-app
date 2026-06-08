import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/cache_service.dart';

/// Overridden in [ProviderScope] after [CacheService.init()] completes.
final cacheServiceProvider = Provider<CacheService>((ref) {
  throw UnimplementedError(
    'cacheServiceProvider must be overridden in ProviderScope',
  );
});
