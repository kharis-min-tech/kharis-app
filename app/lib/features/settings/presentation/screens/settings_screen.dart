import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/providers/auth_provider.dart';
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _serviceReminders = true;
  bool _eventAnnouncements = true;
  bool _dailyReading = true;
  bool _newSermons = false;
  bool _darkMode = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProfileHeader(),
              const SizedBox(height: 28),
              _SectionLabel('ACCOUNT'),
              const SizedBox(height: 8),
              _SettingsGroup(
                children: [
                  _NavItem(icon: Icons.person_outline, label: 'Profile'),
                  _Divider(),
                  _NavItem(
                    icon: Icons.location_pin,
                    label: 'Branch',
                    value: 'London',
                  ),
                  _Divider(),
                  _NavItem(
                    icon: Icons.language,
                    label: 'Language',
                    value: 'English',
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _SectionLabel('NOTIFICATIONS'),
              const SizedBox(height: 8),
              _SettingsGroup(
                children: [
                  _ToggleItem(
                    icon: Icons.church_outlined,
                    label: 'Service Reminders',
                    value: _serviceReminders,
                    onChanged: (v) => setState(() => _serviceReminders = v),
                  ),
                  _Divider(),
                  _ToggleItem(
                    icon: Icons.calendar_month_outlined,
                    label: 'Event Announcements',
                    value: _eventAnnouncements,
                    onChanged: (v) => setState(() => _eventAnnouncements = v),
                  ),
                  _Divider(),
                  _ToggleItem(
                    icon: Icons.menu_book_outlined,
                    label: 'Daily Reading',
                    value: _dailyReading,
                    onChanged: (v) => setState(() => _dailyReading = v),
                  ),
                  _Divider(),
                  _ToggleItem(
                    icon: Icons.notifications_outlined,
                    label: 'New Sermons',
                    value: _newSermons,
                    onChanged: (v) => setState(() => _newSermons = v),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _SectionLabel('APPEARANCE'),
              const SizedBox(height: 8),
              _SettingsGroup(
                children: [
                  _ToggleItem(
                    icon: Icons.dark_mode_outlined,
                    label: 'Dark Mode',
                    value: _darkMode,
                    onChanged: (v) => setState(() => _darkMode = v),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _SectionLabel('ABOUT'),
              const SizedBox(height: 8),
              _SettingsGroup(
                children: [
                  _NavItem(icon: Icons.info_outline, label: 'About Kharis'),
                  _Divider(),
                  _NavItem(icon: Icons.lock_outline, label: 'Privacy Policy'),
                  _Divider(),
                  _NavItem(icon: Icons.mail_outline, label: 'Contact Us'),
                  _Divider(),
                  _NavItem(icon: Icons.star_outline, label: 'Rate the App'),
                ],
              ),
              const SizedBox(height: 24),
              // ── Log out ─────────────────────────────────────────────────────
              _SettingsGroup(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: AppColors.surfaceElevated,
                          title: Text(
                            'Log Out',
                            style: GoogleFonts.mavenPro(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          content: Text(
                            'Are you sure you want to log out?',
                            style: GoogleFonts.dmSans(
                              color: AppColors.textBody,
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.dmSans(
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: Text(
                                'Log Out',
                                style: GoogleFonts.dmSans(
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true && mounted) {
                        await ref
                            .read(authRepositoryProvider)
                            .logout();
                        if (context.mounted) context.go('/role-selection');
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Log Out',
                            style: GoogleFonts.dmSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Center(
                child: Text(
                  'Kharis Church v2.0.0',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.purple, AppColors.orange],
            ),
          ),
          child: Center(
            child: Text(
              'DA',
              style: GoogleFonts.mavenPro(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'David',
                style: GoogleFonts.mavenPro(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Member',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: AppColors.textBody,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.purple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'London Branch',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.purple,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.dmSans(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.textMuted,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: children,
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.only(left: 52),
      color: AppColors.surfaceSubtle,
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    this.value,
  });

  final IconData icon;
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textBody),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (value != null) ...[
            Text(
              value!,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Icon(
            Icons.chevron_right,
            size: 18,
            color: AppColors.textMuted,
          ),
        ],
      ),
    );
  }
}

class _ToggleItem extends StatelessWidget {
  const _ToggleItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textBody),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.purple,
            activeTrackColor: AppColors.purple.withValues(alpha: 0.35),
            inactiveThumbColor: AppColors.textMuted,
            inactiveTrackColor: AppColors.surfaceSubtle,
            trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
          ),
        ],
      ),
    );
  }
}
