import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kharis_app/core/theme/theme.dart';

// ── Toggle state providers (session-scoped) ───────────────────────────────────

final _serviceRemindersProvider = StateProvider<bool>((ref) => true);
final _eventsProvider = StateProvider<bool>((ref) => true);
final _dailyReadingProvider = StateProvider<bool>((ref) => true);
final _newSermonsProvider = StateProvider<bool>((ref) => true);

// ── Screen ────────────────────────────────────────────────────────────────────

class NotificationsSettingsScreen extends ConsumerWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  color: AppColors.textPrimary,
                  size: 20,
                ),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
              child: Text(
                'Notifications',
                style: GoogleFonts.mavenPro(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            // Toggle rows
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _ToggleRow(
                      label: 'Service Reminders',
                      subtitle: 'Reminders before services start',
                      provider: _serviceRemindersProvider,
                    ),
                    const SizedBox(height: 14),
                    _ToggleRow(
                      label: 'Events',
                      subtitle: 'Updates on upcoming events',
                      provider: _eventsProvider,
                    ),
                    const SizedBox(height: 14),
                    _ToggleRow(
                      label: 'Daily Reading',
                      subtitle: 'Your daily scripture notification',
                      provider: _dailyReadingProvider,
                    ),
                    const SizedBox(height: 14),
                    _ToggleRow(
                      label: 'New Sermons',
                      subtitle: 'Alert when new sermons are added',
                      provider: _newSermonsProvider,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Toggle row widget ─────────────────────────────────────────────────────────

class _ToggleRow extends ConsumerWidget {
  const _ToggleRow({
    required this.label,
    required this.subtitle,
    required this.provider,
  });

  final String label;
  final String subtitle;
  final StateProvider<bool> provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(provider);
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
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            onChanged: (v) => ref.read(provider.notifier).state = v,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.accent,
            inactiveThumbColor: AppColors.textMuted,
            inactiveTrackColor: AppColors.surfaceSubtle,
          ),
        ],
      ),
    );
  }
}
