import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:kharis_app/core/constants/app_assets.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/giving/presentation/screens/giving_webview_screen.dart';

/// The secure Kharis giving portal (opened via the web-view / payment flow).
const String _kGivingUrl = 'https://kharis.org/giving';

/// Home branch shown in the "Giving to" selector.
const String _kBranch = 'London (HQ)';

/// Giving tab (design-handoff v3, light).
///
/// A calm, single-column giving landing: a scripture card, the branch the gift
/// is directed to, a full-width **Give securely** call-to-action that opens the
/// secure portal, and offline bank-transfer + campaign cards below.
class GivingScreen extends StatelessWidget {
  const GivingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 140),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
                child: Text('Giving', style: AppTypography.headlineLgMobile),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _ScriptureCard(),
                    const SizedBox(height: 18),
                    const _SectionLabel('GIVING TO'),
                    const SizedBox(height: 9),
                    _BranchSelector(
                      branch: _kBranch,
                      onTap: () => openGivingFlow(context, _kGivingUrl),
                    ),
                    const SizedBox(height: 14),
                    _GiveSecurelyButton(
                      onTap: () => openGivingFlow(context, _kGivingUrl),
                    ),
                    const SizedBox(height: 9),
                    const _SecureNote(),
                    const SizedBox(height: 22),
                    const _BankTransferCard(),
                    const SizedBox(height: 14),
                    _CampaignCard(
                      onTap: () => openGivingFlow(context, _kGivingUrl),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Scripture card ────────────────────────────────────────────────────────────

class _ScriptureCard extends StatelessWidget {
  const _ScriptureCard();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        children: [
          // Base + accent wash approximating the prototype's layered gradient.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF2A1A6B), Color(0xFF0B0A12)],
                ),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.75, -0.85),
                    radius: 1.1,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.85),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.55],
                  ),
                ),
              ),
            ),
          ),
          // Dove watermark.
          Positioned(
            right: -14,
            top: -10,
            child: Opacity(
              opacity: 0.12,
              child: Image.asset(AppAssets.doveWhite, width: 96),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Giving is a response to the generosity of a good God.',
                  style: AppTypography.serif(
                    size: 20,
                    italic: true,
                    height: 1.3,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '2 Corinthians 9:7',
                  style: AppTypography.ui(
                    size: 12,
                    color: AppColors.darkMuted2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Branch selector ─────────────────────────────────────────────────────────

class _BranchSelector extends StatelessWidget {
  const _BranchSelector({required this.branch, required this.onTap});

  final String branch;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: AppRadius.cardBorder,
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.chipLight,
                borderRadius: AppRadius.tileBorder,
              ),
              child: const Icon(
                Icons.location_on_outlined,
                size: 19,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                branch,
                style: AppTypography.ui(
                  size: 15,
                  weight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 20,
              color: AppColors.textMutedLight,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Give securely CTA ─────────────────────────────────────────────────────────

class _GiveSecurelyButton extends StatelessWidget {
  const _GiveSecurelyButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 17),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, AppColors.primaryDeep],
          ),
          borderRadius: AppRadius.buttonBorder,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Give securely',
              style: AppTypography.ui(
                size: 16,
                weight: FontWeight.w700,
                color: AppColors.onPrimary,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.north_east_rounded,
              size: 17,
              color: AppColors.onPrimary,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Secure note ───────────────────────────────────────────────────────────────

class _SecureNote extends StatelessWidget {
  const _SecureNote();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.lock_outline_rounded,
          size: 13,
          color: AppColors.textMutedLight,
        ),
        const SizedBox(width: 6),
        Text(
          'Opens the secure Kharis giving page',
          style: AppTypography.ui(
            size: 11.5,
            color: AppColors.textMutedLight,
          ),
        ),
      ],
    );
  }
}

// ── Bank transfer card ──────────────────────────────────────────────────────

class _BankTransferCard extends StatelessWidget {
  const _BankTransferCard();

  static const List<(String, String)> _rows = [
    ('Account', '80608335'),
    ('Sort code', '20-71-82'),
    ('SWIFT/BIC', 'BUKBGB22'),
    ('IBAN', 'GB88BUKB20718280608335'),
  ];

  void _copy(BuildContext context) {
    const details =
        'Kharis Ministries\nAccount: 80608335\nSort code: 20-71-82\n'
        'SWIFT/BIC: BUKBGB22\nIBAN: GB88BUKB20718280608335';
    Clipboard.setData(const ClipboardData(text: details));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Bank details copied'),
          duration: Duration(milliseconds: 1700),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF137A6D),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bank Transfer',
            style: AppTypography.ui(
              size: 13,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Kharis Ministries',
            style: AppTypography.display(size: 22, color: Colors.white),
          ),
          const SizedBox(height: 14),
          for (final (label, value) in _rows) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: AppTypography.ui(
                      size: 13.5,
                      weight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  Text(
                    value,
                    style: AppTypography.ui(
                      size: label == 'IBAN' ? 11.5 : 13.5,
                      weight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 7),
          GestureDetector(
            onTap: () => _copy(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.copy_rounded, size: 14, color: Colors.white),
                  const SizedBox(width: 7),
                  Text(
                    'Copy details',
                    style: AppTypography.ui(
                      size: 12.5,
                      weight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Campaign card ─────────────────────────────────────────────────────────────

class _CampaignCard extends StatelessWidget {
  const _CampaignCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 150,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A1205), Color(0xFF3A1240)],
            ),
          ),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0xB3000000), Colors.transparent],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Build God a House',
                    style: AppTypography.display(size: 22, color: Colors.white),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    "We're believing for a permanent home "
                    '\u2014 \u00A31.4M of \u00A33M raised',
                    style: AppTypography.ui(
                      size: 12,
                      color: AppColors.darkMuted3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: 0.47,
                      minHeight: 6,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.secondary,
                      ),
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
}

// ── Shared section label ──────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.ui(
        size: 11,
        weight: FontWeight.w700,
        letterSpacing: 1.1,
        color: AppColors.textMutedLight,
      ),
    );
  }
}
