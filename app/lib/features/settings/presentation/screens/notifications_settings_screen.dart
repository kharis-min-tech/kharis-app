import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kharis_app/core/services/notification_service.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/notification_provider.dart';
import 'package:kharis_app/shared/widgets/notification_permission_card.dart';
import 'package:kharis_app/ui/components/components.dart';

/// The notification choices, in display order: preference key, title and
/// what the member gets.
const List<(String, String, String)> _choices = [
  ('announcements', 'Announcements', 'News and notices from your branch'),
  (
    'serviceReminders',
    'Service reminders',
    'An hour before your branch\u2019s service, and if it changes',
  ),
  ('events', 'Events', 'Updates on upcoming events'),
  ('dailyReading', 'Daily reading', 'Today\u2019s Bible reading at 07:00 (UK)'),
];

// ── Screen ────────────────────────────────────────────────────────────────────

class NotificationsSettingsScreen extends ConsumerStatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  ConsumerState<NotificationsSettingsScreen> createState() =>
      _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState
    extends ConsumerState<NotificationsSettingsScreen> {
  // Local copy of prefs - initialized once from Firestore, then updated
  // optimistically on every toggle.
  Map<String, bool>? _prefs;

  void _onToggle(String key, bool value) {
    setState(() {
      _prefs = {...?_prefs, key: value};
    });
    // Make the toggle mean something: move this device on/off the topic.
    // Guests get no Firestore write, so this is their only enforcement.
    ref.read(notificationServiceProvider).applyPreference(key, value);
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user != null && user.role != 'guest') {
      ref
          .read(firebaseAuthRepositoryProvider)
          .updateNotificationPrefs(Map.unmodifiable(_prefs!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefsAsync = ref.watch(notificationPrefsProvider);
    final permission = ref.watch(notificationPermissionProvider).valueOrNull;

    // Hydrate local copy once from the first Firestore emission.
    if (_prefs == null) {
      prefsAsync.whenData((prefs) {
        _prefs = Map.of(prefs);
      });
    }

    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: KSize.maxContentWidth),
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(
                top: KSpace.md,
                bottom: KSpace.section,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const KScreenHeader(title: 'Notifications'),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      KSpace.gutter,
                      KSpace.x3,
                      KSpace.gutter,
                      0,
                    ),
                    child: prefsAsync.when(
                      loading: () => const _TogglesSkeleton(),
                      // The prefs stream falls back to defaults for guests; a
                      // read failure for a member still shows working
                      // switches (they apply to this device's topics) rather
                      // than a blank page.
                      error: (_, _) => _toggles(_prefs ?? const {}, permission),
                      data: (_) => _toggles(_prefs ?? const {}, permission),
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

  Widget _toggles(Map<String, bool> prefs, NotificationPermission? permission) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Toggles can't deliver anything while the OS blocks
        // us, so say so rather than lying with four switches.
        if (permission == NotificationPermission.askable ||
            permission == NotificationPermission.blocked) ...[
          NotificationPermissionCard(
            permission: permission!,
            message:
                'Your device is blocking Kharis notifications. Turn them on '
                'to get the alerts you pick below.',
          ),
          const SizedBox(height: KSpace.x3),
        ],
        KListGroup(
          children: [
            for (final (key, title, hint) in _choices)
              KListRow(
                key: Key('notification-pref-$key'),
                title: title,
                meta: hint,
                onTap: () => _onToggle(key, !(prefs[key] ?? true)),
                trailing: KSwitch(
                  value: prefs[key] ?? true,
                  onChanged: (v) => _onToggle(key, v),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Four row-sized blocks while the choices load.
class _TogglesSkeleton extends StatelessWidget {
  const _TogglesSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < _choices.length; i++) ...[
          if (i > 0) const SizedBox(height: KSpace.xxs),
          const KSkeleton(height: KSize.listRow),
        ],
      ],
    );
  }
}
