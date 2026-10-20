import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kharis_app/features/feedback/presentation/feedback_sheet.dart';
import 'package:kharis_app/features/onboarding/presentation/screens/branch_selection_screen.dart';
import 'package:kharis_app/features/onboarding/presentation/widgets/branch_tile.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/onboarding_provider.dart';

import '../support/channels.dart';
import '../support/harness.dart';
import '../support/actions.dart';
import '../support/live_data.dart';

const _roles = {
  'Member': 'member',
  'New here': 'new_here',
  'Partner': 'partner',
};

/// (a) Fresh install: the role path and the guest path, and the branch
/// picker lists the Studio's branches in their Kharis / KP2 groups.
Future<void> onboardingJourney(Journey j) async {
  final t = j.tester;
  final branches = await studioBranches();
  j.check(branches.isNotEmpty, 'Studio lists active branches');
  final r = seeded(effectiveSeed, 'onboarding');

  // ── Role path: Welcome -> role -> branch -> Home ─────────────────────────
  await fb.FirebaseAuth.instance.signOut();
  await j.launch(onboarded: false, armPermissionGate: true);
  await pumpUntilFound(t, find.text('Get started'), reason: 'welcome screen');
  // A fresh install waits on the welcome screen and asks for nothing.
  await pumpFor(t, const Duration(seconds: 6));
  j.check(
    find.text('Get started').evaluate().isNotEmpty,
    'welcome screen waits for the member',
  );
  j.check(
    permissionRequests().isEmpty,
    'no notification permission request before onboarding',
  );
  j.check(
    find.byType(FeedbackSheet).evaluate().isEmpty,
    'no rating sheet on launch',
  );
  await j.shot('welcome');

  await t.tap(find.text('Get started'), warnIfMissed: false);
  await pumpUntilFound(t, find.text('How are you connected to Kharis?'));
  for (final title in _roles.keys) {
    j.check(find.text(title).evaluate().isNotEmpty, 'role "$title" offered');
  }
  final roleTitle = pick(r, _roles.keys.toList());
  j.note('role chosen this run: $roleTitle');
  await j.shot('roles');
  await t.tap(find.text(roleTitle), warnIfMissed: false);
  await pumpUntilFound(t, find.byType(BranchSelectionScreen));
  j.check(
    j.c.read(onboardingRepositoryProvider).selectedRole == _roles[roleTitle],
    'role saved as ${_roles[roleTitle]}',
  );

  await _checkBranchGroups(j, branches);

  final choice = pick(r, branches);
  j.note('branch chosen during onboarding: ${choice.name}');
  j.check(
    permissionRequests().isEmpty,
    'still no permission request while choosing a branch',
  );
  await _chooseBranch(j, choice, branches);
  await pumpUntilFound(t, find.text('Home'), reason: 'Home after onboarding');
  await pumpFor(t, const Duration(seconds: 2));

  final repo = j.c.read(onboardingRepositoryProvider);
  j.check(repo.isCompleted, 'onboarding marked complete');
  j.check(
    repo.selectedBranch == choice.name,
    'branch saved as "${choice.name}" (got ${repo.selectedBranch})',
  );
  j.check(
    await pumpUntil(
      t,
      () => permissionRequests().isNotEmpty,
      timeout: const Duration(seconds: 15),
    ),
    'notification permission requested once onboarding is complete',
  );
  j.check(
    find.byType(FeedbackSheet).evaluate().isEmpty,
    'no rating sheet on first Home',
  );
  await j.shot('home-after-role-path');

  // ── Guest path: Welcome -> sign in -> Continue as guest -> branch ────────
  await fb.FirebaseAuth.instance.signOut();
  await j.launch(onboarded: false);
  await pumpUntilFound(t, find.text('I already have an account'));
  await t.tap(find.text('I already have an account'), warnIfMissed: false);
  await pumpUntilFound(t, find.text('Continue as guest'));
  await j.shot('login');
  await t.tap(find.text('Continue as guest'), warnIfMissed: false);
  await pumpUntilFound(
    t,
    find.byType(BranchSelectionScreen),
    reason: 'guest goes on to choose a branch',
  );
  final guestChoice = pick(
    r,
    branches.where((b) => b.name != choice.name).toList(),
  );
  await _chooseBranch(j, guestChoice, branches);
  await pumpUntilFound(t, find.text('Home'));
  await pumpFor(t, const Duration(seconds: 2));
  final user = fb.FirebaseAuth.instance.currentUser;
  j.check(
    user != null && user.isAnonymous,
    'guest path signs in anonymously (uid ${user?.uid}, '
    'anonymous=${user?.isAnonymous})',
  );
  final guestRepo = j.c.read(onboardingRepositoryProvider);
  j.check(guestRepo.isCompleted, 'guest onboarding marked complete');
  j.check(
    j.c.read(currentBranchProvider).valueOrNull == guestChoice.name,
    'guest branch is "${guestChoice.name}" '
    '(got ${j.c.read(currentBranchProvider).valueOrNull})',
  );
  j.note(
    'role stored for a guest who skipped the role step: '
    '${guestRepo.selectedRole}',
  );
  await j.shot('home-after-guest-path');
}

/// The picker's list, in order, against the Studio: main branches under
/// BRANCHES, Phase 2 ones (KP2 prefix dropped) under KHARIS PHASE TWO.
Future<void> _checkBranchGroups(Journey j, List<StudioBranch> branches) async {
  final t = j.tester;
  final screen = find.byType(BranchSelectionScreen);
  await pumpUntilFound(
    t,
    find.descendant(of: screen, matching: find.byType(BranchTile)),
    reason: 'branch tiles',
  );
  await pumpFor(t, const Duration(seconds: 2));
  final list = t.widget<ListView>(
    find.descendant(of: screen, matching: find.byType(ListView)),
  );
  final children = (list.childrenDelegate as SliverChildListDelegate).children;
  final groups = <String, List<String>>{};
  String? header;
  for (final child in children) {
    final inner = child is Padding ? child.child : child;
    if (inner is Text) header = inner.data;
    if (inner is BranchTile) (groups[header ?? '?'] ??= []).add(inner.name);
  }
  List<String> sorted(Iterable<String> names) => names.toList()..sort();
  final wantMain = sorted(
    branches.where((b) => !b.isPhaseTwo).map((b) => b.tileName),
  );
  final wantKp2 = sorted(
    branches.where((b) => b.isPhaseTwo).map((b) => b.tileName),
  );
  j.check(
    listEquals(sorted(groups['BRANCHES'] ?? const []), wantMain),
    'BRANCHES group = Studio "Kharis" branches '
    '(app ${groups['BRANCHES']}, Studio $wantMain)',
  );
  if (wantKp2.isEmpty) {
    j.check(
      !groups.containsKey('KHARIS PHASE TWO'),
      'no KHARIS PHASE TWO header when the Studio has no Phase 2 branch',
    );
  } else {
    j.check(
      listEquals(sorted(groups['KHARIS PHASE TWO'] ?? const []), wantKp2),
      'KHARIS PHASE TWO group = Studio Phase 2 branches '
      '(app ${groups['KHARIS PHASE TWO']}, Studio $wantKp2)',
    );
    j.check(
      groups.keys.toList().indexOf('BRANCHES') <
          groups.keys.toList().indexOf('KHARIS PHASE TWO'),
      'main branches listed before Phase 2',
    );
  }
  await j.shot('branch-picker-top');
  if (wantKp2.isNotEmpty) {
    await scrollUntilFound(
      t,
      find.text('KHARIS PHASE TWO'),
      scrollable: verticalScrollableIn(
        find.descendant(of: screen, matching: find.byType(ListView)),
      ),
    );
    await j.shot('branch-picker-kp2');
  }
}

/// Searches the picker for [b], checks the search narrowed the list to the
/// Studio branches whose name or subtitle matches, and taps [b].
Future<void> _chooseBranch(
  Journey j,
  StudioBranch b,
  List<StudioBranch> all,
) async {
  final q = b.name.toLowerCase();
  final expected = all.where(
    (x) =>
        x.name.toLowerCase().contains(q) ||
        '${x.row['subtitle'] ?? x.row['short_description'] ?? ''}'
            .toLowerCase()
            .contains(q),
  );
  final shown = await chooseBranchInPicker(j, b);
  j.check(
    shown.length == expected.length,
    'search "${b.name}" narrows the list to ${expected.toList()} '
    '(got $shown)',
  );
}
