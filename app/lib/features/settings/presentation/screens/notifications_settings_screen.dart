import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kharis_app/core/services/notification_service.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/notification_provider.dart';
import 'package:kharis_app/shared/widgets/notification_permission_card.dart';

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back button
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 8),
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(
                  Icons.arrow_back_ios_new,
                  color: context.kc.onBg,
                  size: 20,
                ),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
              child: Text(
                'Notifications',
                style: AppTypography.display(
                  size: 26,
                  weight: FontWeight.w700,
                ).copyWith(color: context.kc.onBg),
              ),
            ),
            // Content area
            Expanded(
              child: prefsAsync.when(
                loading: () => Center(
                  child: CircularProgressIndicator(
                    color: context.kc.accentInk,
                    strokeWidth: 2,
                  ),
                ),
                // The prefs stream falls back to defaults for guests; a read
                // failure for a member still shows working switches (they
                // apply to this device's topics) rather than a blank page.
                error: (_, _) => _toggles(_prefs ?? const {}, permission),
                data: (_) => _toggles(_prefs ?? const {}, permission),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toggles(Map<String, bool> prefs, NotificationPermission? permission) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
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
            const SizedBox(height: 14),
          ],
          _ToggleRow(
            label: 'Announcements',
            subtitle: 'News and notices from your branch',
            value: prefs['announcements'] ?? true,
            onChanged: (v) => _onToggle('announcements', v),
          ),
          const SizedBox(height: 14),
          _ToggleRow(
            label: 'Service reminders',
            subtitle:
                'An hour before your branch\u2019s service, and when its '
                'time or place changes',
            value: prefs['serviceReminders'] ?? true,
            onChanged: (v) => _onToggle('serviceReminders', v),
          ),
          const SizedBox(height: 14),
          _ToggleRow(
            label: 'Events',
            subtitle: 'Updates on upcoming events',
            value: prefs['events'] ?? true,
            onChanged: (v) => _onToggle('events', v),
          ),
          const SizedBox(height: 14),
          _ToggleRow(
            label: 'Daily reading',
            subtitle: 'Today\u2019s Bible reading at 7am (UK time)',
            value: prefs['dailyReading'] ?? true,
            onChanged: (v) => _onToggle('dailyReading', v),
          ),
        ],
      ),
    );
  }
}

// ── Toggle row widget ─────────────────────────────────────────────────────────

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.kc.surface,
        borderRadius: AppRadius.cardBorder,
        boxShadow: AppShadows.card,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.ui(
                    size: 15,
                    weight: FontWeight.w600,
                  ).copyWith(color: context.kc.onBg),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTypography.ui(
                    size: 12,
                  ).copyWith(color: context.kc.muted),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: context.kc.accent,
            inactiveThumbColor: context.kc.surface,
            inactiveTrackColor: context.kc.surfaceMuted,
          ),
        ],
      ),
    );
  }
}
