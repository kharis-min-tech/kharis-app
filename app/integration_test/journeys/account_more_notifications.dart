import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kharis_app/core/services/notification_service.dart';
import 'package:kharis_app/features/calendar/presentation/screens/calendar_screen.dart';
import 'package:kharis_app/features/calendar/presentation/screens/event_detail_screen.dart';
import 'package:kharis_app/features/connect/presentation/screens/new_here_screen.dart';
import 'package:kharis_app/features/connect/presentation/screens/testimony_screen.dart';
import 'package:kharis_app/features/feedback/presentation/feedback_sheet.dart';
import 'package:kharis_app/features/giving/presentation/screens/giving_screen.dart';
import 'package:kharis_app/features/home/presentation/screens/branch_screen.dart';
import 'package:kharis_app/features/home/presentation/screens/home_screen.dart';
import 'package:kharis_app/features/home/presentation/screens/notifications_screen.dart';
import 'package:kharis_app/features/messages/presentation/screens/downloads_screen.dart';
import 'package:kharis_app/features/notes/presentation/screens/notes_screen.dart';
import 'package:kharis_app/features/onboarding/data/auth_repository.dart';
import 'package:kharis_app/features/onboarding/presentation/screens/login_screen.dart';
import 'package:kharis_app/features/playlists/presentation/screens/favorites_screen.dart';
import 'package:kharis_app/features/playlists/presentation/screens/playlists_screen.dart';
import 'package:kharis_app/features/settings/data/account_deletion.dart';
import 'package:kharis_app/features/settings/presentation/screens/notifications_settings_screen.dart';
import 'package:kharis_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:kharis_app/shared/models/user.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/campus_config_provider.dart'
    show kDefaultHomeBranch;
import 'package:kharis_app/shared/widgets/branch_picker_sheet.dart';
import 'package:kharis_app/ui/components/components.dart';

import '../support/actions.dart';
import '../support/channels.dart';
import '../support/harness.dart';
import '../support/live_data.dart';

bool _moreShows(String label) => find
    .descendant(
      of: find.byType(SettingsScreen),
      matching: find.text(label, skipOffstage: false),
    )
    .evaluate()
    .isNotEmpty;

Finder get _dialog => find.byType(Dialog);

// ── (l) Account ──────────────────────────────────────────────────────────────

/// A signed-in member that exists only in this process.
class _FakeMemberAuth implements AuthRepository {
  _FakeMemberAuth(this.user);

  final User user;

  @override
  User? get currentUser => user;
  @override
  bool get isAuthenticated => true;
  @override
  Stream<User?> get authStateChanges => Stream.value(user);
  @override
  bool get usesPasswordSignIn => true;
  @override
  Future<void> reauthenticate(String password) async {}
  @override
  Future<void> deleteAccount() =>
      throw StateError('e2e: the fake member is never deleted');
  @override
  Future<User> login(String email, String password) async => user;
  @override
  Future<User> loginAsGuest() async => user;
  @override
  Future<User> register({
    required String email,
    required String password,
    required String displayName,
    required String role,
  }) async => user;
  @override
  Future<void> logout() async {}
  @override
  Future<void> sendPasswordResetEmail(String email) async {}
}

/// Records the deletion request instead of performing it.
class _RecordingDeletion extends AccountDeletionService {
  _RecordingDeletion(Ref ref)
    : super(
        auth: ref.watch(authRepositoryProvider),
        data: ref.watch(accountDataRepositoryProvider),
        local: ref.watch(localAccountDataProvider),
      );

  final List<({String uid, String? password})> calls = [];

  @override
  Future<void> deleteAccount({required String uid, String? password}) async {
    calls.add((uid: uid, password: password));
  }
}

/// (l) Signed out (guest): no Delete account. A signed-in member: the
/// Delete account dialog cancels cleanly and, confirmed with the password,
/// asks the deletion service to delete that member. The member and the
/// deletion service are fakes in this process: no real account is touched
/// (Firebase has no emulator in this setup).
Future<void> accountJourney(Journey j) async {
  final t = j.tester;
  await j.launch();
  await openMoreRow(t, 'Sign in');
  j.check(
    await pumpUntil(t, () => find.byType(LoginScreen).evaluate().isNotEmpty),
    'guest More offers Sign in',
  );
  await goBack(t);
  await pumpUntilFound(t, find.byType(SettingsScreen));
  j.check(!_moreShows('Delete account'), 'guest More has no Delete account');
  j.check(!_moreShows('Sign out'), 'guest More has no Sign out');
  await j.shot('guest-more');

  final member = User(
    id: 'e2e-fake-${DateTime.now().millisecondsSinceEpoch}',
    email: 'e2e-member@example.invalid',
    displayName: 'E2E Member',
    role: 'member',
    createdAt: DateTime(2024),
  );
  _RecordingDeletion? deletion;
  await j.launch(
    overrides: [
      authRepositoryProvider.overrideWithValue(_FakeMemberAuth(member)),
      accountDeletionServiceProvider.overrideWith(
        (ref) => deletion = _RecordingDeletion(ref),
      ),
    ],
  );
  await openMoreRow(t, 'Delete account');
  await pumpUntilFound(
    t,
    find.text('Delete account?'),
    reason: 'delete dialog',
  );
  j.check(_moreShows('E2E Member'), 'member profile card on More');
  j.check(_moreShows('Sign out'), 'member More has Sign out');
  await j.shot('delete-dialog');
  await t.tap(
    find.descendant(
      of: _dialog,
      matching: find.text('Cancel'),
    ),
    warnIfMissed: false,
  );
  await pumpFor(t, const Duration(seconds: 1));
  j.check(
    find.text('Delete account?').evaluate().isEmpty,
    'Cancel closes the dialog',
  );
  j.check(deletion?.calls.isEmpty ?? true, 'Cancel deletes nothing');

  await openMoreRow(t, 'Delete account');
  await pumpUntilFound(t, find.text('Delete account?'));
  final confirm = find.descendant(
    of: _dialog,
    matching: find.text('Delete account'),
  );
  await tapVisible(t, confirm);
  await pumpFor(t, const Duration(milliseconds: 600));
  j.check(
    find.text('Delete account?').evaluate().isNotEmpty &&
        (deletion?.calls.isEmpty ?? true),
    'confirm is disabled until the password is typed',
  );
  await t.enterText(
    find.descendant(
      of: _dialog,
      matching: find.byType(EditableText),
    ),
    'e2e-password',
  );
  await pumpFor(t, const Duration(milliseconds: 400));
  FocusManager.instance.primaryFocus?.unfocus();
  await pumpFor(t, const Duration(milliseconds: 600));
  await tapVisible(t, confirm);
  j.check(
    await pumpUntil(
      t,
      () => deletion?.calls.isNotEmpty ?? false,
      timeout: const Duration(seconds: 10),
    ),
    'confirming asks the deletion service to delete the member',
  );
  final call = deletion?.calls.firstOrNull;
  j.check(
    call?.uid == member.id && call?.password == 'e2e-password',
    'deletion targets ${member.id} with the typed password (got $call)',
  );
  j.check(
    await pumpUntil(
      t,
      () => find.text('Your account has been deleted.').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 10),
    ),
    'member told the account was deleted',
  );
  await j.shot('deleted-message');
}

// ── (m) More menu ────────────────────────────────────────────────────────────

/// (m) Every More tile and row opens its destination and comes back with
/// the swipe back; the two choice rows open their sheets; web rows open
/// their page in the in-app browser; the version is pubspec's.
Future<void> moreMenuJourney(Journey j) async {
  final t = j.tester;
  await j.launch();
  await tapNav(t, 'More');
  await pumpUntilFound(t, find.byType(SettingsScreen));
  j.check(!_moreShows('Admin console'), 'More has no in-app Studio entry');

  Future<void> backToMore(String label, Finder destination) async {
    await goBack(t);
    j.check(
      await pumpUntil(
        t,
        () =>
            destination.evaluate().isEmpty &&
            find.byType(SettingsScreen).hitTestable().evaluate().isNotEmpty,
      ),
      '"$label" returns to More',
    );
  }

  Future<void> opens(String label, Finder destination) async {
    await openMoreRow(t, label);
    final opened = await pumpUntil(
      t,
      () => destination.evaluate().isNotEmpty,
      timeout: const Duration(seconds: 20),
    );
    j.check(opened, '"$label" opens its screen');
    if (!opened) return;
    await pumpFor(t, const Duration(seconds: 1));
    await j.shot(label);
    await backToMore(label, destination);
  }

  // The tiles.
  await opens('My notes', find.byType(NotesScreen));
  await opens('Downloads', find.byType(DownloadsScreen));
  await opens('Collections', find.byType(PlaylistsScreen));
  await opens('Favourites', find.byType(FavoritesScreen));
  await opens('Give', find.byType(GivingScreen));
  await opens('Events', find.byType(CalendarScreen));

  // Your branch: the card opens the branch page; Change branch the picker.
  final campus = find.byKey(const Key('campus-card'));
  await scrollUntilFound(t, campus, scrollable: moreScroll);
  j.check(
    find
        .descendant(of: campus, matching: find.text(kDefaultHomeBranch))
        .evaluate()
        .isNotEmpty,
    'Your branch shows $kDefaultHomeBranch',
  );
  await tapVisible(t, campus);
  j.check(
    await pumpUntil(t, () => find.byType(BranchScreen).evaluate().isNotEmpty),
    'the branch card opens the branch page',
  );
  await j.shot('branch-page');
  await backToMore('Your branch', find.byType(BranchScreen));
  await tapVisible(t, find.byKey(const Key('campus-change')));
  j.check(
    await pumpUntil(
      t,
      () => find.byType(BranchPickerSheet).evaluate().isNotEmpty,
    ),
    '"Change branch" opens the branch picker',
  );
  await j.shot('Change branch');
  await goBack(t);
  j.check(
    await pumpUntil(
      t,
      () => find.byType(BranchPickerSheet).evaluate().isEmpty,
    ),
    'the branch picker closes without a change',
  );
  j.check(
    prefs.getString('onboarding_branch') == kDefaultHomeBranch,
    'closing the picker keeps $kDefaultHomeBranch',
  );

  // The rows.
  await opens('Notifications', find.byType(NotificationsSettingsScreen));
  for (final label in const ['Appearance', 'Text size']) {
    await openMoreRow(t, label);
    final sheet = find.byWidgetPredicate((w) => w is KSortSheet);
    j.check(
      await pumpUntil(t, () => sheet.evaluate().isNotEmpty),
      '"$label" opens its choices',
    );
    await j.shot(label);
    await goBack(t);
    j.check(
      await pumpUntil(t, () => sheet.evaluate().isEmpty),
      '"$label" choices close back to More',
    );
  }
  await opens("I'm new here", find.byType(NewHereScreen));
  await opens('Share a testimony', find.byType(TestimonyScreen));
  await opens('Sign in', find.byType(LoginScreen));

  await openMoreRow(t, 'Help & feedback');
  j.check(
    await pumpUntil(
      t,
      () => find.byType(FeedbackSheet).evaluate().isNotEmpty,
      timeout: const Duration(seconds: 10),
    ),
    '"Help & feedback" opens the feedback sheet',
  );
  await j.shot('feedback');
  await goBack(t);
  j.check(
    await pumpUntil(t, () => find.byType(FeedbackSheet).evaluate().isEmpty),
    'feedback sheet closes',
  );

  for (final (label, url) in [
    ('Contact us', kHelpUrl),
    ('Privacy policy', kPrivacyPolicyUrl),
  ]) {
    launches.clear();
    await openMoreRow(t, label);
    await pumpUntil(
      t,
      () => launches.isNotEmpty,
      timeout: const Duration(seconds: 5),
    );
    j.check(
      launches.length == 1 &&
          launches.single.url == url &&
          !launches.single.external,
      '"$label" opens $url inside the app (got $launches)',
    );
    j.check(
      find.byType(SettingsScreen).evaluate().isNotEmpty,
      'still on More after "$label"',
    );
  }

  final version = find.byKey(const ValueKey('app-version'));
  await scrollUntilFound(t, version, scrollable: moreScroll);
  await pumpUntil(
    t,
    () => (t.widget<Text>(version).data ?? '') != 'Kharis Church',
  );
  final shown = t.widget<Text>(version).data ?? '';
  final parts = pubspecVersion.split('+');
  final want = parts.length == 2
      ? 'Kharis Church ${parts[0]} (${parts[1]})'
      : 'Kharis Church $pubspecVersion';
  j.check(
    pubspecVersion.isNotEmpty && shown == want,
    'version "$shown" matches pubspec "$pubspecVersion"',
  );
  await j.shot('version');
}

// ── (n) Notifications ────────────────────────────────────────────────────────

/// (n) The bell opens the inbox; it lists the live feed (upcoming Content
/// Studio events and announcements) or its empty state; an event row opens
/// the event. Push taps route by `data.type` to the matching screen.
Future<void> notificationsJourney(Journey j) async {
  final t = j.tester;
  final events = await studioEvents();
  final news = await studioNews();
  final now = DateTime.now();
  final upcoming = events.where((e) => !e.isPast(now)).toList();
  j.note(
    'live Studio upcoming events: ${upcoming.length}, announcements: ${news.length}',
  );
  await j.launch();
  await pumpUntilFound(t, find.byType(HomeScreen));
  await _openInbox(j);

  final inbox = find.byType(NotificationsScreen);
  if (news.isEmpty && upcoming.isEmpty) {
    j.check(
      find
          .descendant(of: inbox, matching: find.text('No notifications yet'))
          .evaluate()
          .isNotEmpty,
      'empty inbox says "No notifications yet"',
    );
  }
  for (final e in upcoming) {
    j.check(
      find
          .descendant(
            of: inbox,
            matching: find.text(e.title, skipOffstage: false),
          )
          .evaluate()
          .isNotEmpty,
      'inbox lists upcoming event "${e.title}"',
    );
  }
  await j.shot('inbox');

  for (final (data, want) in [
    (const {'type': 'reading'}, '/bible/reading'),
    (const {'type': 'service_reminder'}, '/home'),
    (const {'type': 'event', 'eventId': 'abc'}, '/events/abc'),
    (const {'type': 'announcement', 'newsId': 'n1'}, '/announcements?id=n1'),
  ]) {
    final got = notificationTargetFor(data).location;
    j.check(got == want, 'push ${data['type']} routes to $want (got $got)');
  }

  if (upcoming.isEmpty) {
    j.note('DATA: no upcoming Studio event to open from the inbox');
    return;
  }
  final first = upcoming.first;
  final row = find.descendant(of: inbox, matching: find.text(first.title));
  await scrollUntilFound(t, row, scrollable: verticalScrollableIn(inbox));
  await tapVisible(t, row);
  final detail = find.byType(EventDetailScreen);
  j.check(
    await pumpUntil(
      t,
      () => detail.evaluate().isNotEmpty,
      timeout: const Duration(seconds: 30),
    ),
    'event row opens the event',
  );
  j.check(
    await pumpUntil(
      t,
      () => find
          .descendant(of: detail, matching: find.text(first.title))
          .evaluate()
          .isNotEmpty,
    ),
    'event "${first.title}" shown',
  );
  await j.shot('routed');
}

Future<void> _openInbox(Journey j) async {
  final t = j.tester;
  final bell = find.byKey(const Key('home-bell'));
  await pumpUntilFound(t, bell);
  await t.tap(bell, warnIfMissed: false);
  await pumpUntilFound(
    t,
    find.byType(NotificationsScreen),
    reason: 'bell opens the inbox',
  );
  await pumpUntil(
    t,
    () => find.byKey(const Key('notifications-skeleton')).evaluate().isEmpty,
    timeout: const Duration(seconds: 30),
  );
  await pumpFor(t, const Duration(seconds: 1));
}
