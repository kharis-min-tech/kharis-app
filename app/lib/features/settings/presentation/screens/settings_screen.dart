import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kharis_app/features/journey/presentation/screens/journey_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';

import 'notifications_settings_screen.dart';
import 'package:kharis_app/features/connect/presentation/screens/new_here_screen.dart';
import 'package:kharis_app/features/connect/presentation/screens/testimony_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final displayName = userAsync.maybeWhen(
      data: (u) => u?.displayName ?? 'Test User',
      orElse: () => 'Test User',
    );
    final email = userAsync.maybeWhen(
      data: (u) => u?.email ?? 'testuser@kharis.org',
      orElse: () => 'testuser@kharis.org',
    );

    final parts = displayName.trim().split(' ');
    final initials = parts.length >= 2
        ? '${parts.first[0]}${parts.last[0]}'.toUpperCase()
        : displayName.substring(0, displayName.length < 2 ? 1 : 2).toUpperCase();

    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),

              // 1. KHARIS wordmark
              Center(
                child: Image.asset(
                  'assets/figma/kharis_wordmark.png',
                  height: 22,
                ),
              ),

              const SizedBox(height: 28),

              // 2. Profile row
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.primary, AppColors.primary],
                      ),
                    ),
                    child: Center(
                      child: Text(
                        initials,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // 3. Menu rows — surfaceElevated cards, 12px radius, 14px gap
              _MenuCard(
                label: 'New Here? Connect',
                onTap: () => Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const NewHereScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _MenuCard(
                label: 'Share a Testimony',
                onTap: () => Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const TestimonyScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _MenuCard(
                label: 'Begin Your Journey',
                onTap: () => Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const JourneyScreen(),
                  ),
                ),
              ),
              _MenuCard(
                label: 'My Notes',
                onTap: () => context.push('/notes'),
              ),
              _MenuCard(
                label: 'Notifications',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const NotificationsSettingsScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _MenuCard(
                label: 'Help Centre',
                onTap: () => unawaited(
                  launchUrl(
                    Uri.parse('https://kharis.org/help'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _MenuCard(
                label: 'Contact Us',
                onTap: () => unawaited(
                  launchUrl(
                    Uri.parse('https://kharis.org/contact'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _MenuCard(
                label: 'Terms & Conditions',
                onTap: () => unawaited(
                  launchUrl(
                    Uri.parse('https://kharis.org/terms'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ),

              // 4. SIGN OUT — 32px below menu
              const SizedBox(height: 32),
              GestureDetector(
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppColors.surfaceElevated,
                      title: Text(
                        'Sign Out',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      content: Text(
                        'Are you sure you want to sign out?',
                        style: GoogleFonts.plusJakartaSans(color: AppColors.onSurfaceVariant),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.plusJakartaSans(color: AppColors.textMuted),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: Text(
                            'Sign Out',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppColors.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true && context.mounted) {
                    await ref.read(authRepositoryProvider).logout();
                    if (context.mounted) context.go('/role-selection');
                  }
                },
                child: Center(
                  child: Text(
                    'SIGN OUT',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.error,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // 5. Version footer
              Center(
                child: Text(
                  'Kharis Church v2.0.0',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Menu card ─────────────────────────────────────────────────────────────────

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceElevated,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    color: AppColors.onSurface,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
