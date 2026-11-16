import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:kharis_app/core/services/notification_service.dart'
    show NotificationPermission;
import 'package:kharis_app/features/connect/presentation/screens/new_here_screen.dart';
import 'package:kharis_app/features/connect/presentation/screens/testimony_screen.dart';
import 'package:kharis_app/features/feedback/data/app_feedback_repository.dart';
import 'package:kharis_app/features/feedback/presentation/feedback_sheet.dart';
import 'package:kharis_app/features/home/presentation/screens/dashboard_shell.dart';
import 'package:kharis_app/features/home/presentation/widgets/campus_card.dart';
import 'package:kharis_app/features/onboarding/data/branch_repository.dart'
    show weekdayIndex;
import 'package:kharis_app/features/playlists/providers/playlist_providers.dart';
import 'package:kharis_app/features/settings/presentation/widgets/delete_account_flow.dart';
import 'package:kharis_app/shared/models/campus_config.dart';
import 'package:kharis_app/shared/models/user.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/campus_config_provider.dart';
import 'package:kharis_app/shared/providers/clock_provider.dart';
import 'package:kharis_app/shared/providers/downloads_provider.dart';
import 'package:kharis_app/shared/providers/notes_provider.dart';
import 'package:kharis_app/shared/providers/notification_provider.dart';
import 'package:kharis_app/shared/providers/streaks_provider.dart';
import 'package:kharis_app/shared/providers/text_size_provider.dart';
import 'package:kharis_app/shared/providers/theme_provider.dart';
import 'package:kharis_app/shared/widgets/branch_picker_sheet.dart';
import 'package:kharis_app/ui/components/components.dart';

/// Church contact page (verified 200). The old `/help` path is a 404.
const String kHelpUrl = 'https://kharis.org/contact-us/';

/// Church privacy policy (verified 200). kharis.org publishes no terms of
/// service page, so none is linked.
const String kPrivacyPolicyUrl = 'https://kharis.org/privacy-policy/';

/// The installed build, e.g. `1.0.0 (1)`, read from the platform bundle so
/// More always reports what is actually running.
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version} (${info.buildNumber})';
});

/// Opens a web page inside the app (in-app browser), never in another app.
Future<void> _openWebPage(String url) =>
    launchUrl(Uri.parse(url), mode: LaunchMode.inAppBrowserView);

/// Pushes a full-screen page above the tab shell, keeping the shell's nav.
void _pushPage(BuildContext context, Widget page) {
  unawaited(
    Navigator.of(
      context,
      rootNavigator: true,
    ).push(MaterialPageRoute<void>(builder: (_) => WithTabNav(child: page))),
  );
}

/// Minutes after midnight a service starts, from "19:00", "19:00:00" or the
/// older "7:00 PM"; null when the Studio set no clock time.
int? _startMinutes(CampusService service) {
  final m = RegExp(
    r'^(\d{1,2}):(\d{2})(?::\d{2})?\s*([AaPp][Mm])?$',
  ).firstMatch(service.startTime?.trim() ?? '');
  if (m == null) return null;
  var hour = int.parse(m.group(1)!);
  final minute = int.parse(m.group(2)!);
  final half = m.group(3)?.toLowerCase();
  if (half != null) {
    if (hour < 1 || hour > 12) return null;
    hour = hour % 12 + (half == 'pm' ? 12 : 0);
  }
  if (hour > 23 || minute > 59) return null;
  return hour * 60 + minute;
}

const _dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

/// The next of [services] to start after [now], as the Events tile says it:
/// "Midweek · Wed 19:00". Today counts while a service has yet to start (one
/// with no time counts all day). Null when no service names a weekday.
@visibleForTesting
String? nextServiceLabel(List<CampusService> services, DateTime now) {
  const endOfDay = 24 * 60;
  final nowMinutes = now.hour * 60 + now.minute;
  for (var offset = 0; offset <= 7; offset++) {
    final weekday = DateTime(now.year, now.month, now.day + offset).weekday % 7;
    CampusService? next;
    for (final s in services) {
      if (weekdayIndex(s.day) != weekday) continue;
      final start = _startMinutes(s) ?? endOfDay;
      if (offset == 0 && start <= nowMinutes) continue;
      if (next == null || start < (_startMinutes(next) ?? endOfDay)) next = s;
    }
    if (next == null) continue;

    final name = next.name.trim().replaceFirst(
      RegExp(r'\s+service$', caseSensitive: false),
      '',
    );
    final start = _startMinutes(next);
    final when = [
      _dayNames[weekday],
      if (start != null)
        '${(start ~/ 60).toString().padLeft(2, '0')}:'
            '${(start % 60).toString().padLeft(2, '0')}',
    ].join(' ');
    return [if (name.isNotEmpty) name, when].join(' \u00b7 ');
  }
  return null;
}

/// "None yet", "1 note", "62 notes"; null while [count] is not known.
String? _countLabel(
  int? count, {
  required String one,
  required String many,
  required String none,
}) => switch (count) {
  null => null,
  0 => none,
  1 => '1 $one',
  _ => '$count $many',
};

/// The More tab: the member's card, shortcuts to their own things, their
/// branch, settings, and the installed version.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final version = ref.watch(appVersionProvider).valueOrNull;
    final signedIn =
        user != null && user.role != 'guest' && user.email.isNotEmpty;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: KSize.maxContentWidth),
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(
                top: KSpace.md,
                bottom: KSize.contentBottomPad,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const KScreenHeader(title: 'More'),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      KSpace.gutter,
                      KSpace.x3,
                      KSpace.gutter,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (signedIn)
                          _ProfileCard(user: user)
                        else
                          const _SignInCard(),
                        const SizedBox(height: KSpace.xxl),
                        const _Tiles(),
                        const SizedBox(height: KSpace.xxl),
                        const _BranchBlock(),
                        const SizedBox(height: KSpace.xxl),
                        _SettingsRows(signedIn: signedIn),
                        const SizedBox(height: KSpace.xxl),
                        _AboutRows(member: signedIn ? user : null),
                        const SizedBox(height: KSpace.gutter),
                        Text(
                          version == null
                              ? 'Kharis Church'
                              : 'Kharis Church $version',
                          key: const ValueKey('app-version'),
                          textAlign: TextAlign.center,
                          style: KharisText.caption.copyWith(
                            color: context.k.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Profile ─────────────────────────────────────────────────────────────────

/// The signed-in member: who they are, their branch, the year they joined
/// and their streaks. Opens Edit profile.
class _ProfileCard extends ConsumerWidget {
  const _ProfileCard({required this.user});

  final User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branch = ref.watch(currentBranchProvider).valueOrNull;
    final streaks = ref.watch(streaksProvider);
    final photoUrl = user.photoUrl;

    return KMoreProfileCard(
      key: const Key('more-profile-card'),
      name: user.displayName,
      photo: photoUrl == null || photoUrl.isEmpty
          ? null
          : NetworkImage(photoUrl),
      subtitle: [
        ?branch,
        'member since ${user.createdAt.year}',
      ].join(' \u00b7 '),
      streaks: [
        if (streaks.readingStreak > 0)
          KMoreStreakBadge(
            '${streaks.readingStreak}-day reading',
            tone: KMoreStreakTone.highlight,
            icon: KIcons.flame,
          ),
        if (streaks.messagesStreak > 0)
          KMoreStreakBadge('${streaks.messagesStreak}-day messages'),
      ],
      onTap: () => context.push('/profile/edit'),
    );
  }
}

/// What a guest sees in place of the profile card.
class _SignInCard extends StatelessWidget {
  const _SignInCard();

  @override
  Widget build(BuildContext context) {
    return KCard(
      key: const Key('more-sign-in-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Sign in to keep your notes, collections and branch on every '
            'device.',
            style: KharisText.body.copyWith(color: context.k.text),
          ),
          const SizedBox(height: KSpace.x3),
          KButton(
            key: const Key('more-sign-in'),
            label: 'Sign in',
            expand: true,
            onPressed: () => context.push('/login'),
          ),
          const SizedBox(height: KSpace.xs),
          Center(
            child: KTextLink(
              key: const Key('more-create-account'),
              label: 'Create an account',
              onTap: () => context.push('/register'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shortcuts ───────────────────────────────────────────────────────────────

/// The member's own things, each with what is in it right now.
class _Tiles extends ConsumerWidget {
  const _Tiles();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(notebookProvider).valueOrNull?.length;
    final downloads = ref.watch(downloadsProvider).length;
    final collections = ref.watch(playlistsProvider).valueOrNull?.length;
    final favourites = ref
        .watch(favoritesProvider)
        .whenOrNull(data: (playlist) => playlist?.sermonIds.length ?? 0);
    final services =
        ref.watch(currentCampusProvider)?.services ?? const <CampusService>[];
    final nextService = nextServiceLabel(services, ref.watch(clockProvider)());

    return KMoreTileGrid(
      children: [
        KMoreTile(
          key: const Key('more-tile-notes'),
          icon: KIcons.pen,
          title: 'My notes',
          meta: _countLabel(
            notes,
            one: 'note',
            many: 'notes',
            none: 'No notes yet',
          ),
          onTap: () => context.push('/notes'),
        ),
        KMoreTile(
          key: const Key('more-tile-downloads'),
          icon: KIcons.download,
          title: 'Downloads',
          meta: downloads == 0 ? 'None saved' : '$downloads saved',
          onTap: () => context.push('/downloads'),
        ),
        KMoreTile(
          key: const Key('more-tile-collections'),
          icon: KIcons.collection,
          title: 'Collections',
          meta: _countLabel(
            collections,
            one: 'collection',
            many: 'collections',
            none: 'None yet',
          ),
          onTap: () => context.push('/playlists'),
        ),
        KMoreTile(
          key: const Key('more-tile-favourites'),
          icon: KIcons.heart,
          title: 'Favourites',
          meta: _countLabel(
            favourites,
            one: 'message',
            many: 'messages',
            none: 'None yet',
          ),
          onTap: () => context.push('/favorites'),
        ),
        KMoreTile(
          key: const Key('more-tile-give'),
          icon: KIcons.gift,
          title: 'Give',
          meta: 'Tithes and offerings',
          onTap: () => context.push('/give'),
        ),
        KMoreTile(
          key: const Key('more-tile-events'),
          icon: KIcons.calendar,
          title: 'Events',
          meta: nextService ?? 'Services and events',
          onTap: () => context.push('/calendar'),
        ),
      ],
    );
  }
}

// ── Your branch ─────────────────────────────────────────────────────────────

/// The member's branch: where and when it meets, directions and a way to
/// change it. Opens the branch page. Until a branch is chosen (or while its
/// details load) it offers the choice alone.
class _BranchBlock extends ConsumerWidget {
  const _BranchBlock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(currentCampusProvider) != null) {
      return CampusCard(summary: true, onTap: () => context.push('/branch'));
    }

    final branch = ref.watch(currentBranchProvider).valueOrNull;
    return KCard(
      key: const Key('more-choose-branch-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const KOverline('Your branch'),
          const SizedBox(height: KSpace.sm),
          Text(
            branch ?? kChooseBranchLabel,
            style: KharisText.title.copyWith(color: context.k.text),
          ),
          const SizedBox(height: KSpace.xl),
          KButton(
            key: const Key('more-choose-branch'),
            label: branch == null ? 'Choose branch' : 'Change branch',
            variant: KButtonVariant.outline,
            expand: true,
            onPressed: () => pickActiveBranch(context, ref),
          ),
        ],
      ),
    );
  }
}

// ── Rows ────────────────────────────────────────────────────────────────────

/// A settings row's current value, at the end of the row.
class _RowValue extends StatelessWidget {
  const _RowValue(this.value);

  final String value;

  @override
  Widget build(BuildContext context) =>
      Text(value, style: KharisText.meta.copyWith(color: context.k.muted));
}

String _themeLabel(ThemeMode mode) => switch (mode) {
  ThemeMode.system => 'System',
  ThemeMode.light => 'Light',
  ThemeMode.dark => 'Dark',
};

/// "On" while the phone allows notifications and at least one kind is
/// switched on; "Off" otherwise; null while it is not known.
String? _notificationsLabel(
  NotificationPermission? permission,
  Map<String, bool>? prefs,
) => switch (permission) {
  null || NotificationPermission.unavailable => null,
  NotificationPermission.granted =>
    prefs != null && prefs.isNotEmpty && !prefs.containsValue(true)
        ? 'Off'
        : 'On',
  NotificationPermission.askable || NotificationPermission.blocked => 'Off',
};

/// Notifications, appearance, text size, the two forms, feedback and, for a
/// member, Sign out.
class _SettingsRows extends ConsumerWidget {
  const _SettingsRows({required this.signedIn});

  final bool signedIn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeModeProvider);
    final textSize = ref.watch(textSizeProvider);
    final notifications = _notificationsLabel(
      ref.watch(notificationPermissionProvider).valueOrNull,
      ref.watch(notificationPrefsProvider).valueOrNull,
    );

    return KListGroup(
      children: [
        KListRow(
          key: const Key('more-row-notifications'),
          leading: const KIcon(KIcons.bell),
          title: 'Notifications',
          trailing: notifications == null ? null : _RowValue(notifications),
          onTap: () => context.push('/settings/notifications'),
        ),
        KListRow(
          key: const Key('more-row-appearance'),
          leading: const KIcon(KIcons.moon),
          title: 'Appearance',
          trailing: _RowValue(_themeLabel(theme)),
          onTap: () => _chooseAppearance(context, ref),
        ),
        KListRow(
          key: const Key('more-row-text-size'),
          leading: const KIcon(KIcons.textSize),
          title: 'Text size',
          trailing: _RowValue(textSize.label),
          onTap: () => _chooseTextSize(context, ref),
        ),
        KListRow(
          key: const Key('more-row-new-here'),
          leading: const KIcon(KIcons.users),
          title: "I'm new here",
          onTap: () => _pushPage(context, const NewHereScreen()),
        ),
        KListRow(
          key: const Key('more-row-testimony'),
          leading: const KIcon(KIcons.mic),
          title: 'Share a testimony',
          onTap: () => _pushPage(context, const TestimonyScreen()),
        ),
        KListRow(
          key: const Key('more-row-feedback'),
          leading: const KIcon(KIcons.help),
          title: 'Help & feedback',
          onTap: () => unawaited(
            showFeedbackSheet(context, ref, source: FeedbackSource.settings),
          ),
        ),
        if (signedIn)
          KListRow(
            key: const Key('more-row-sign-out'),
            leading: const KIcon(KIcons.signOut),
            title: 'Sign out',
            onTap: () => _confirmSignOut(context, ref),
          ),
      ],
    );
  }

  Future<void> _chooseAppearance(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(themeModeProvider.notifier);
    final mode = await showKSortSheet<ThemeMode>(
      context: context,
      title: 'Appearance',
      options: [
        for (final mode in const [
          ThemeMode.system,
          ThemeMode.light,
          ThemeMode.dark,
        ])
          KSortOption(value: mode, label: _themeLabel(mode)),
      ],
      selected: ref.read(themeModeProvider),
    );
    if (mode != null) await controller.set(mode);
  }

  Future<void> _chooseTextSize(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(textSizeProvider.notifier);
    final choice = await showKSortSheet<TextSizeChoice>(
      context: context,
      title: 'Text size',
      options: [
        for (final choice in TextSizeChoice.values)
          KSortOption(value: choice, label: choice.label),
      ],
      selected: ref.read(textSizeProvider),
    );
    if (choice != null) await controller.set(choice);
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final auth = ref.read(authRepositoryProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const _SignOutDialog(),
    );
    // currentUserProvider then emits null and More rebuilds to its guest
    // state; browsing stays open, so there is nowhere to navigate to.
    if (confirmed == true) await auth.logout();
  }
}

/// Asks before signing out: 'Sign out' above a plain 'Cancel'.
class _SignOutDialog extends StatelessWidget {
  const _SignOutDialog();

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Dialog(
      backgroundColor: k.surface,
      insetPadding: const EdgeInsets.all(KSpace.gutter),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(KRadius.card)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: KSize.maxContentWidth),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(KSpace.gutter),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'Sign out?',
                  style: KharisText.section.copyWith(color: k.text),
                ),
              ),
              const SizedBox(height: KSpace.xl),
              Text(
                'Are you sure you want to sign out?',
                style: KharisText.body.copyWith(color: k.muted),
              ),
              const SizedBox(height: KSpace.gutter),
              KButton(
                key: const Key('sign-out-confirm'),
                label: 'Sign out',
                variant: KButtonVariant.inverse,
                expand: true,
                onPressed: () => Navigator.of(context).pop(true),
              ),
              const SizedBox(height: KSpace.md),
              KButton(
                label: 'Cancel',
                variant: KButtonVariant.text,
                expand: true,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The church's contact and privacy pages and, for a [member], deleting
/// their account.
class _AboutRows extends StatelessWidget {
  const _AboutRows({required this.member});

  /// The signed-in member; null for a guest.
  final User? member;

  @override
  Widget build(BuildContext context) {
    return KListGroup(
      children: [
        KListRow(
          key: const Key('more-row-contact'),
          leading: const KIcon(KIcons.send),
          title: 'Contact us',
          onTap: () => unawaited(_openWebPage(kHelpUrl)),
        ),
        KListRow(
          key: const Key('more-row-privacy'),
          leading: const KIcon(KIcons.lock),
          title: 'Privacy policy',
          onTap: () => unawaited(_openWebPage(kPrivacyPolicyUrl)),
        ),
        if (member case final member?)
          KListRow(
            key: const Key('more-row-delete-account'),
            leading: const KIcon(KIcons.close),
            title: 'Delete account',
            onTap: () => unawaited(confirmDeleteAccount(context, member)),
          ),
      ],
    );
  }
}
