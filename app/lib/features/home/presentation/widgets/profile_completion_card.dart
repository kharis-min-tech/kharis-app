import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';

/// Nudges signed-in members whose profile is missing a birthday or phone.
///
/// Signup deliberately asks for the minimum (name, email, password) so new
/// members aren't scared off by a long form; this card is the follow-up.
/// It collapses to nothing for guests, for complete profiles, and for the
/// rest of the session once dismissed — it must never nag.
class ProfileCompletionCard extends ConsumerStatefulWidget {
  const ProfileCompletionCard({super.key});

  @override
  ConsumerState<ProfileCompletionCard> createState() =>
      _ProfileCompletionCardState();
}

class _ProfileCompletionCardState extends ConsumerState<ProfileCompletionCard> {
  /// Session-local dismiss: reappears on next launch until completed.
  static bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    if (_dismissed || user == null || user.role == 'guest') {
      return const SizedBox.shrink();
    }
    final missingDob = user.dob == null;
    final missingPhone = user.phone == null || user.phone!.isEmpty;
    if (!missingDob && !missingPhone) return const SizedBox.shrink();

    final ask = missingDob && missingPhone
        ? 'Add your birthday and phone'
        : missingDob
            ? 'Add your birthday'
            : 'Add your phone number';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 6, 14),
        decoration: BoxDecoration(
          color: context.kc.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: context.kc.accent.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.cake_outlined, size: 22, color: context.kc.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Complete your profile',
                    style: AppTypography.ui(size: 14, weight: FontWeight.w700)
                        .copyWith(color: context.kc.onBg),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$ask so your church family can celebrate you.',
                    style: AppTypography.ui(size: 12)
                        .copyWith(color: context.kc.muted, height: 1.35),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => context.push('/profile/edit'),
              child: Text(
                'Add',
                style: AppTypography.ui(size: 13, weight: FontWeight.w700)
                    .copyWith(color: context.kc.accent),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() => _dismissed = true),
              icon: Icon(Icons.close, size: 18, color: context.kc.muted),
            ),
          ],
        ),
      ),
    );
  }
}
