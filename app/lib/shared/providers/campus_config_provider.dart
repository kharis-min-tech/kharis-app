import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/firebase_service.dart';
import '../../features/home/data/church_config_repository.dart';
import '../../features/onboarding/data/branch_repository.dart';
import '../models/campus_config.dart';
import 'admin_provider.dart';
import 'branch_provider.dart';
import 'notification_feed_provider.dart';

// ── Church-wide defaults (`config/giving`, `config/home`) ─────────────────────

/// The secure Kharis giving page (verified 200). It lists every campus and
/// fund, each opening its own Tithe.ly form.
const String kGivingUrl = 'https://kharis.org/giving/';

/// Built-in church-wide giving, exactly as published on kharis.org/giving.
/// Used when neither the member's campus nor `config/giving` sets anything.
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

final churchConfigRepositoryProvider = Provider<ChurchConfigRepository>(
  (ref) => ChurchConfigRepository(firestore: ref.watch(firestoreProvider)),
);

/// `config/giving`, or null when unset or unreadable.
final churchGivingProvider = StreamProvider<GivingDetails?>((ref) {
  if (!kUseFirebase) return Stream.value(null);
  try {
    return ref.watch(churchConfigRepositoryProvider).watchGiving();
  } catch (_) {
    return Stream.value(null);
  }
});

/// `config/home`, or null when unset or unreadable.
final churchHomeLayoutProvider = StreamProvider<HomeLayout?>((ref) {
  if (!kUseFirebase) return Stream.value(null);
  try {
    return ref.watch(churchConfigRepositoryProvider).watchHomeLayout();
  } catch (_) {
    return Stream.value(null);
  }
});

// ── The member's campus ───────────────────────────────────────────────────────

/// The [Branch] the member picked, matched by name (what
/// [currentBranchProvider] holds). Null for "All campuses", while either
/// side is loading, or when no branch carries that name.
final currentCampusProvider = Provider<Branch?>((ref) {
  final name = ref.watch(currentBranchProvider).valueOrNull;
  if (name == null) return null;
  final branches = ref.watch(branchesProvider).valueOrNull;
  if (branches == null) return null;
  for (final b in branches) {
    if (b.name == name) return b;
  }
  return null;
});

// ── Effective settings ────────────────────────────────────────────────────────

/// Home blocks to render: the campus layout, else `config/home`, else
/// [HomeLayout.fallback].
final effectiveHomeLayoutProvider = Provider<HomeLayout>((ref) {
  return ref.watch(currentCampusProvider)?.home ??
      ref.watch(churchHomeLayoutProvider).valueOrNull ??
      HomeLayout.fallback;
});

/// Where a gift goes: the campus account, else `config/giving`, else
/// [kBuiltInGiving].
final effectiveGivingProvider = Provider<GivingDetails>((ref) {
  return ref.watch(currentCampusProvider)?.giving ??
      ref.watch(churchGivingProvider).valueOrNull ??
      kBuiltInGiving;
});

/// Name of whoever [effectiveGivingProvider] pays: the campus when it has
/// its own account, otherwise [kChurchWideRecipient].
final givingRecipientProvider = Provider<String>((ref) {
  final campus = ref.watch(currentCampusProvider);
  return campus?.giving != null ? campus!.name : kChurchWideRecipient;
});

/// Pull-to-refresh for the per-campus settings: branches and the
/// church-wide defaults. Settles once each has answered (or timed out).
Future<void> refreshCampusConfig(WidgetRef ref) => Future.wait<void>([
  settleRefresh(ref.refresh(branchesProvider.future)),
  settleRefresh(ref.refresh(churchGivingProvider.future)),
  settleRefresh(ref.refresh(churchHomeLayoutProvider.future)),
]);
