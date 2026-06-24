import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';

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

    // Hydrate local copy once from the first Firestore emission.
    if (_prefs == null) {
      prefsAsync.whenData((prefs) {
        _prefs = Map.of(prefs);
      });
    }

    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back button
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 8),
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: AppColors.onSurface,
                  size: 20,
                ),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
              child: Text(
                'Notifications',
                style: AppTypography.titleMd.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
            ),
            // Content area
            Expanded(
              child: prefsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.secondary,
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
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
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
                  style: AppTypography.bodyLg.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTypography.labelMd.copyWith(
                    fontWeight: FontWeight.w400,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.secondary,
            inactiveThumbColor: AppColors.textMuted,
            inactiveTrackColor: AppColors.surfaceSubtle,
          ),
        ],
      ),
    );
  }
}
