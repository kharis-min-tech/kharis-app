import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:kharis_app/core/theme/theme.dart';

class _ActionItem {
  final IconData icon;
  final String label;
  final String route;

  const _ActionItem({
    required this.icon,
    required this.label,
    required this.route,
  });
}

const _actions = [
  _ActionItem(icon: Icons.headphones_rounded, label: 'Listen', route: '/messages'),
  _ActionItem(icon: Icons.play_circle_rounded, label: 'Watch', route: '/messages'),
  _ActionItem(icon: Icons.volunteer_activism_rounded, label: 'Give', route: '/giving'),
  _ActionItem(icon: Icons.calendar_month_rounded, label: 'Events', route: '/calendar'),
];

class QuickActionsGrid extends StatelessWidget {
  const QuickActionsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: GoogleFonts.mavenPro(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: AppSpacing.md,
          mainAxisSpacing: AppSpacing.md,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.2,
          children: _actions
              .map((action) => _QuickActionTile(action: action))
              .toList(),
        ),
      ],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final _ActionItem action;

  const _QuickActionTile({required this.action});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go(action.route),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: AppRadius.cardBorder,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.magenta.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.sm),
                ),
                child: Icon(
                  action.icon,
                  size: 20,
                  color: AppColors.magenta,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                action.label,
                style: GoogleFonts.mavenPro(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
