import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/onboarding/data/branch_repository.dart';
import '../models/campus_config.dart';
import 'admin_provider.dart';
import 'branch_provider.dart';
import 'location_provider.dart';
import 'notification_feed_provider.dart';
import 'sermon_provider.dart' show liveStatusProvider;

// ── Church-wide giving ────────────────────────────────────────────────────────

/// The secure Kharis giving page (verified 200). It lists every campus and
/// fund, each opening its own Tithe.ly form.
const String kGivingUrl = 'https://kharis.org/giving/';

/// Built-in church-wide giving, exactly as published on kharis.org/giving:
/// the details the Giving tab shows.
const GivingDetails kBuiltInGiving = GivingDetails(
  url: kGivingUrl,
  accountName: 'Kharis Ministries',
  accountNumber: '80608335',
  sortCode: '20-71-82',
  swiftBic: 'BUKBGB22',
  iban: 'GB88BUKB20718280608335',
);

/// Who receives a gift that no campus account claims.
const String kChurchWideRecipient = 'Kharis Church';

// ── The member's campus ───────────────────────────────────────────────────────

/// The branch in [branches] called [name], if any.
Branch? _branchNamed(List<Branch>? branches, String? name) {
  if (name == null || branches == null) return null;
  for (final b in branches) {
    if (b.name == name) return b;
  }
  return null;
}

/// The [Branch] the member chose, matched by name (what
/// [currentBranchProvider] holds). Null while no branch is chosen, while
/// either side is loading, or when no branch carries that name.
final currentCampusProvider = Provider<Branch?>((ref) {
  final name = ref.watch(currentBranchProvider).valueOrNull;
  if (name == null) return null;
  return _branchNamed(ref.watch(branchesProvider).valueOrNull, name);
});

/// The branch Home shows while the member has not chosen one.
const String kDefaultHomeBranch = 'London';

/// Name of the branch whose content Home (and the bell) shows: the chosen
/// branch; while none is chosen, the nearest branch when location is
/// already allowed (never prompts), else [kDefaultHomeBranch]. Loading
/// until each input it needs has answered.
final homeBranchProvider = Provider<AsyncValue<String>>((ref) {
  bool pending(AsyncValue<Object?> v) => !v.hasValue && !v.hasError;

  final chosen = ref.watch(currentBranchProvider);
  if (pending(chosen)) return const AsyncLoading();
  if (chosen.valueOrNull case final name?) return AsyncData(name);

  final here = ref.watch(grantedPositionProvider);
  if (pending(here)) return const AsyncLoading();
  if (here.valueOrNull case final point?) {
    final branches = ref.watch(branchesProvider);
    if (pending(branches)) return const AsyncLoading();
    final nearest = nearestBranch(branches.valueOrNull ?? const [], point);
    if (nearest != null) return AsyncData(nearest.branch.name);
  }
  return const AsyncData(kDefaultHomeBranch);
});

/// The [Branch] named by [homeBranchProvider]; null while loading or when no
/// branch carries that name.
final homeCampusProvider = Provider<Branch?>((ref) {
  final name = ref.watch(homeBranchProvider).valueOrNull;
  if (name == null) return null;
  return _branchNamed(ref.watch(branchesProvider).valueOrNull, name);
});

// ── Effective settings ────────────────────────────────────────────────────────

/// Home blocks to render: the branch layout, else [HomeLayout.fallback].
final effectiveHomeLayoutProvider = Provider<HomeLayout>((ref) {
  return ref.watch(currentCampusProvider)?.home ?? HomeLayout.fallback;
});

/// Pull-to-refresh for the per-branch settings: branches (with services,
/// venues and giving) and the live-stream switch. Settles once each has
/// answered (or timed out).
Future<void> refreshCampusConfig(WidgetRef ref) => Future.wait<void>([
  settleRefresh(ref.refresh(branchesProvider.future)),
  settleRefresh(ref.refresh(liveStatusProvider.future)),
]);
