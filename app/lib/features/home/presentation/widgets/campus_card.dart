import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/core/utils/service_time.dart';
import 'package:kharis_app/features/onboarding/data/branch_repository.dart';
import 'package:kharis_app/shared/providers/admin_provider.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';

/// "Your campus" card: where the member's branch meets and when.
///
/// [Branch.address], [Branch.meetingDays] and [Branch.meetingTime] are
/// admin-editable and seeded, but had no member-facing reader — this is it.
/// Tapping the address opens the platform maps app.
///
/// Renders nothing when no branch is selected (all-campus view) or when the
/// selected branch carries no venue details, rather than showing an empty card.
class CampusCard extends ConsumerWidget {
  const CampusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchName = ref.watch(currentBranchProvider).valueOrNull;
    if (branchName == null) return const SizedBox.shrink();

    final branches = ref.watch(branchesProvider).valueOrNull;
    if (branches == null) return const SizedBox.shrink();

    final matches = branches.where((b) => b.name == branchName);
    if (matches.isEmpty) return const SizedBox.shrink();
    final branch = matches.first;

    final schedule =
        formatServiceSchedule(branch.meetingDays, branch.meetingTime);
    final address = branch.address?.trim();
    final hasAddress = address != null && address.isNotEmpty;
    if (schedule == null && !hasAddress) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'YOUR CAMPUS',
                  style: AppTypography.ui(
                    size: 10.5,
                    weight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ).copyWith(color: AppColors.textMutedLight, height: 1),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => context.push('/profile/edit'),
                  child: Text(
                    'Change',
                    style: AppTypography.ui(
                      size: 12,
                      weight: FontWeight.w600,
                    ).copyWith(color: AppColors.primary, height: 1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              branch.name,
              style: AppTypography.display(size: 20, weight: FontWeight.w700)
                  .copyWith(color: AppColors.textPrimary, height: 1.1),
            ),
            if (schedule != null) ...[
              const SizedBox(height: 10),
              _VenueRow(icon: Icons.schedule_rounded, text: schedule),
            ],
            if (hasAddress) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _openMaps(address),
                child: _VenueRow(
                  icon: Icons.location_on_outlined,
                  text: address,
                  emphasised: true,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Opens the address in the platform's default maps handler. A failure to
  /// launch is not surfaced — there is nothing the member can act on, and the
  /// address stays readable on the card either way.
  Future<void> _openMaps(String address) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query='
      '${Uri.encodeComponent(address)}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _VenueRow extends StatelessWidget {
  const _VenueRow({
    required this.icon,
    required this.text,
    this.emphasised = false,
  });

  final IconData icon;
  final String text;

  /// Tappable rows are tinted so the affordance is visible.
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final color = emphasised ? AppColors.primary : AppColors.textMutedLight;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: AppTypography.ui(
              size: 13.5,
              weight: emphasised ? FontWeight.w600 : FontWeight.w500,
            ).copyWith(color: color, height: 1.35),
          ),
        ),
      ],
    );
  }
}
