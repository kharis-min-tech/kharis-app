import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/notification_provider.dart';

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

  Future<void> _requestPermission() async {
    await ref.read(notificationServiceProvider).requestPermission();
    ref.invalidate(notificationPermissionProvider);
  }

  @override
  Widget build(BuildContext context) {
    final prefsAsync = ref.watch(notificationPrefsProvider);
    final permitted = ref.watch(notificationPermissionProvider).valueOrNull;

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
                style: AppTypography.display(size: 26, weight: FontWeight.w700)
                    .copyWith(color: context.kc.onBg),
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
                error: (err, _) => const SizedBox.shrink(),
                data: (_) {
                  final prefs = _prefs ?? const {};
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        // Toggles can't deliver anything while the OS blocks
                        // us, so say so rather than lying with four switches.
                        if (permitted == false) ...[
                          _PermissionNotice(onEnable: _requestPermission),
                          const SizedBox(height: 14),
                        ],
                        _ToggleRow(
                          label: 'Service Reminders',
                          subtitle: 'Reminders before services start',
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
                          label: 'Daily Reading',
                          subtitle: 'Your daily scripture notification',
                          value: prefs['dailyReading'] ?? true,
                          onChanged: (v) => _onToggle('dailyReading', v),
                        ),
                        const SizedBox(height: 14),
                        _ToggleRow(
                          label: 'New Sermons',
                          subtitle: 'Alert when new sermons are added',
                          value: prefs['newSermons'] ?? true,
                          onChanged: (v) => _onToggle('newSermons', v),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── OS permission notice ──────────────────────────────────────────────────────

/// Shown when the OS is blocking notifications, so the toggles below can't
/// deliver anything regardless of their state.
class _PermissionNotice extends StatelessWidget {
  const _PermissionNotice({required this.onEnable});

  final Future<void> Function() onEnable;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.kc.surface,
        borderRadius: AppRadius.cardBorder,
        boxShadow: AppShadows.card,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Notifications are turned off',
            style: AppTypography.ui(size: 15, weight: FontWeight.w600)
                .copyWith(color: context.kc.onBg),
          ),
          const SizedBox(height: 2),
          Text(
            'Your device is blocking Kharis notifications. Allow them to start '
            'receiving the alerts you pick below.',
            style: AppTypography.ui(size: 12)
                .copyWith(color: context.kc.muted),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onEnable,
              child: Text(
                'Allow notifications',
                style: AppTypography.ui(size: 13, weight: FontWeight.w600)
                    .copyWith(color: context.kc.accentInk),
              ),
            ),
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
                  style: AppTypography.ui(size: 15, weight: FontWeight.w600)
                      .copyWith(color: context.kc.onBg),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTypography.ui(size: 12)
                      .copyWith(color: context.kc.muted),
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
