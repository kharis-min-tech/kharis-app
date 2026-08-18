import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'onboarding_provider.dart';

const _kDismissedKey = 'notifications_dismissed_ids';

/// How many dismissed ids are remembered. Announcements and events are never
/// deleted server-side, so without a bound this list would grow for the life
/// of the install. The oldest dismissals fall off first; by the time an id is
/// evicted the content behind it is years old and long past expiry.
const int _kMaxRemembered = 500;

/// Ids of notification-feed rows the member has swiped away, oldest first.
///
/// Dismissal is a local, per-device preference: the underlying announcement or
/// event is untouched and still appears everywhere else in the app. Ids are
/// namespaced by source (`news:<id>` / `event:<id>`) by the feed that writes
/// them, so a news item and an event can never dismiss each other.
class DismissedNotificationsController extends StateNotifier<Set<String>> {
  DismissedNotificationsController(this._ref) : super(_readStored(_ref));

  final Ref _ref;

  static Set<String> _readStored(Ref ref) {
    final stored =
        ref.read(sharedPreferencesProvider).getStringList(_kDismissedKey);
    return Set.unmodifiable(stored ?? const <String>[]);
  }

  /// Hides a single row.
  Future<void> dismiss(String id) => _write({...state, id});

  /// Hides every currently visible row in one go ("Clear all").
  Future<void> dismissAll(Iterable<String> ids) => _write({...state, ...ids});

  /// Un-hides [ids] — powers the undo affordance after a dismissal.
  Future<void> restore(Iterable<String> ids) {
    final removing = ids.toSet();
    return _write({
      for (final id in state)
        if (!removing.contains(id)) id,
    });
  }

  /// Un-hides everything the member has ever dismissed.
  Future<void> restoreAll() => _write(const <String>{});

  Future<void> _write(Set<String> next) async {
    final trimmed = next.length <= _kMaxRemembered
        ? next
        : next.skip(next.length - _kMaxRemembered).toSet();
    state = Set.unmodifiable(trimmed);
    await _ref.read(sharedPreferencesProvider).setStringList(
          _kDismissedKey,
          trimmed.toList(growable: false),
        );
  }
}

final dismissedNotificationsProvider =
    StateNotifierProvider<DismissedNotificationsController, Set<String>>(
  DismissedNotificationsController.new,
);
