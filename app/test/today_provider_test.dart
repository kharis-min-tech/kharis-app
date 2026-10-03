import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kharis_app/shared/providers/sermon_provider.dart';

/// `todayProvider` keys the Message of the Day (schedule doc and automatic
/// pick); it must follow the local date for as long as the app is alive.
///
/// `testWidgets` runs on a fake clock for timers; the wall clock the provider
/// reads is injected through `clockProvider`.
void main() {
  (ProviderContainer, List<DateTime>) harness(DateTime Function() clock) {
    final container = ProviderContainer(
      overrides: [clockProvider.overrideWithValue(clock)],
    );
    final seen = <DateTime>[];
    container.listen(
      todayProvider,
      (_, day) => seen.add(day),
      fireImmediately: true,
    );
    return (container, seen);
  }

  testWidgets('rolls over at local midnight while the app stays open', (
    tester,
  ) async {
    var now = DateTime(2026, 10, 3, 23, 59, 50);
    final (container, seen) = harness(() => now);
    expect(seen, [DateTime(2026, 10, 3)]);

    now = DateTime(2026, 10, 3, 23, 59, 59);
    await tester.pump(const Duration(seconds: 9));
    expect(seen, [DateTime(2026, 10, 3)], reason: 'not before midnight');

    now = DateTime(2026, 10, 4, 0, 0, 1);
    await tester.pump(const Duration(seconds: 2));
    expect(seen, [DateTime(2026, 10, 3), DateTime(2026, 10, 4)]);
    expect(container.read(todayProvider), DateTime(2026, 10, 4));

    // The next midnight is armed as well.
    now = DateTime(2026, 10, 5, 0, 0, 1);
    await tester.pump(const Duration(days: 1));
    expect(seen.last, DateTime(2026, 10, 5));

    // Disposing cancels the pending midnight timer (testWidgets fails on a
    // timer left pending).
    container.dispose();
  });

  testWidgets('is re-evaluated on resume when the date changed while the app '
      'was suspended', (tester) async {
    var now = DateTime(2026, 10, 3, 22);
    final (container, seen) = harness(() => now);

    // Suspended overnight: the OS held the midnight timer back.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = DateTime(2026, 10, 4, 7, 30);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(Duration.zero);
    expect(seen, [DateTime(2026, 10, 3), DateTime(2026, 10, 4)]);

    // A resume on the same date does not notify dependents again.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = DateTime(2026, 10, 4, 9);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(Duration.zero);
    expect(seen, hasLength(2));

    container.dispose();
  });
}
