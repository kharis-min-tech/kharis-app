import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/core/constants/app_assets.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/giving/presentation/screens/giving_webview_screen.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/widgets/branch_picker_sheet.dart';

/// The secure Kharis giving page (verified 200). It lists every campus and
/// fund, each opening its own Tithe.ly form, so it is org-wide: the branch
/// model carries no giving URL and there is nothing branch-specific to
/// substitute here.
const String kGivingUrl = 'https://kharis.org/giving/';

/// Bank transfer details exactly as published on kharis.org/giving. The card
/// renders these rows and "Copy bank details" copies the same rows, so what
/// the member sees is what lands on the clipboard.
const List<(String, String)> kBankTransferRows = [
  ('Account name', 'Kharis Ministries'),
  ('Account number', '80608335'),
  ('Sort code', '20-71-82'),
  ('SWIFT/BIC', 'BUKBGB22'),
  ('IBAN', 'GB88BUKB20718280608335'),
];

/// Clipboard text for [kBankTransferRows], one `Label: value` per line.
String get bankTransferClipboardText =>
    kBankTransferRows.map((r) => '${r.$1}: ${r.$2}').join('\n');

/// Giving tab.
///
/// A calm, single-column giving landing: a scripture card, the campus the
/// gift is directed to, a full-width gold **Give securely** call to action
/// that opens the secure giving page, and the bank-transfer details below.
class GivingScreen extends ConsumerWidget {
  const GivingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branch = ref.watch(currentBranchProvider).valueOrNull;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 140),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
                child: Text(
                  'Giving',
                  style: AppTypography.headlineLgMobile.copyWith(
                    color: context.kc.onBg,
                  ),
                ),
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
                      branch: branch ?? kAllCampusesLabel,
                      onTap: () => pickActiveBranch(context, ref),
                    ),
                    const SizedBox(height: 14),
                    _GiveSecurelyButton(
                      onTap: () => openGivingFlow(context, kGivingUrl),
                    ),
                    const SizedBox(height: 9),
                    const _SecureNote(),
                    const SizedBox(height: 22),
                    const _BankTransferCard(),
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
      borderRadius: AppRadius.cardBorder,
      child: DecoratedBox(
        // Brand ink card in both themes; text on it stays light.
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primaryDeep, AppColors.ink],
          ),
        ),
        child: Stack(
          children: [
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
                    'So let each one give as he purposes in his heart, not '
                    'grudgingly or of necessity; for God loves a cheerful '
                    'giver.',
                    style: AppTypography.serif(
                      size: 19,
                      italic: true,
                      height: 1.35,
                      color: AppColors.onPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '2 Corinthians 9:7 (NKJV)',
                    style: AppTypography.ui(
                      size: 12,
                      weight: FontWeight.w600,
                      color: AppColors.darkMuted2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
    final kc = context.kc;
    return Semantics(
      button: true,
      label: 'Giving to $branch. Change campus',
      excludeSemantics: true,
      child: GestureDetector(
        key: const ValueKey('giving-branch-selector'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: kc.surface,
            borderRadius: AppRadius.cardBorder,
            boxShadow: AppShadows.card,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: kc.chipBg,
                  borderRadius: AppRadius.tileBorder,
                ),
                child: Icon(
                  Icons.location_on_outlined,
                  size: 19,
                  color: kc.onChip,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  branch,
                  style: AppTypography.ui(
                    size: 15,
                    weight: FontWeight.w700,
                    color: kc.onBg,
                  ),
                ),
              ),
              Text(
                'Change',
                style: AppTypography.ui(
                  size: 13,
                  weight: FontWeight.w600,
                  color: kc.onChip,
                ),
              ),
            ],
          ),
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
    final kc = context.kc;
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: kc.accent,
          foregroundColor: kc.onAccent,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.buttonBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Give securely',
              style: AppTypography.ui(
                size: 16,
                weight: FontWeight.w700,
                color: kc.onAccent,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.north_east_rounded, size: 17, color: kc.onAccent),
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
        Icon(Icons.lock_outline_rounded, size: 13, color: context.kc.muted),
        const SizedBox(width: 6),
        Text(
          'Opens the secure Kharis giving page',
          style: AppTypography.ui(size: 12, color: context.kc.muted),
        ),
      ],
    );
  }
}

// ── Bank transfer card ──────────────────────────────────────────────────────

class _BankTransferCard extends StatelessWidget {
  const _BankTransferCard();

  Future<void> _copy(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: bankTransferClipboardText));
    messenger
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
    final kc = context.kc;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kc.surface,
        borderRadius: AppRadius.cardBorder,
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: kc.chipBg,
                  borderRadius: AppRadius.tileBorder,
                ),
                child: Icon(
                  Icons.account_balance_outlined,
                  size: 19,
                  color: kc.onChip,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bank transfer',
                      style: AppTypography.display(
                        size: 18,
                        weight: FontWeight.w700,
                        color: kc.onBg,
                      ),
                    ),
                    Text(
                      'UK bank account',
                      style: AppTypography.ui(size: 12.5, color: kc.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final (label, value) in kBankTransferRows)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: AppTypography.ui(size: 13.5, color: kc.muted),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SelectableText(
                    value,
                    style: AppTypography.ui(
                      size: 13.5,
                      weight: FontWeight.w600,
                      color: kc.onBg,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: () => _copy(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: kc.onBg,
              side: BorderSide(color: kc.outline),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: Text(
              'Copy bank details',
              style: AppTypography.ui(size: 13, weight: FontWeight.w700),
            ),
          ),
        ],
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
        color: context.kc.muted,
      ),
    );
  }
}
