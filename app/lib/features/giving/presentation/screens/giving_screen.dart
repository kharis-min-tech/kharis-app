import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/core/constants/app_assets.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/giving/presentation/screens/giving_webview_screen.dart';
import 'package:kharis_app/shared/models/campus_config.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/campus_config_provider.dart';
import 'package:kharis_app/shared/widgets/branch_picker_sheet.dart';

/// The bank-transfer rows of [giving], in display order. The card renders
/// these rows and "Copy bank details" copies the same rows, so what the
/// member sees is what lands on the clipboard.
List<(String, String)> givingBankRows(GivingDetails giving) => [
  if (giving.bankName case final v?) ('Bank', v),
  if (giving.accountName case final v?) ('Account name', v),
  if (giving.accountNumber case final v?) ('Account number', v),
  if (giving.sortCode case final v?) ('Sort code', v),
  if (giving.swiftBic case final v?) ('SWIFT/BIC', v),
  if (giving.iban case final v?) ('IBAN', v),
  if (giving.reference case final v?) ('Reference', v),
];

/// Clipboard text for [givingBankRows], one `Label: value` per line.
String givingClipboardText(GivingDetails giving) =>
    _rowsText(givingBankRows(giving));

String _rowsText(List<(String, String)> rows) =>
    rows.map((r) => '${r.$1}: ${r.$2}').join('\n');

/// Giving tab.
///
/// A calm, single-column giving landing: a scripture card, the campus the
/// gift is directed to, a full-width gold **Give securely** call to action
/// that opens the secure giving page, and the bank-transfer details below.
///
/// The details are [effectiveGivingProvider]: the campus account when the
/// campus has one, else the church-wide account. "Give securely" only shows
/// when there is a giving page to open.
class GivingScreen extends ConsumerWidget {
  const GivingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branch = ref.watch(currentBranchProvider).valueOrNull;
    final giving = ref.watch(effectiveGivingProvider);
    final recipient = ref.watch(givingRecipientProvider);
    final url = giving.url;
    final rows = givingBankRows(giving);
    final note = giving.note;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 140),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
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
                      recipient: recipient,
                      onTap: () => pickActiveBranch(context, ref),
                    ),
                    if (url != null) ...[
                      const SizedBox(height: 14),
                      _GiveSecurelyButton(
                        onTap: () => openGivingFlow(context, url),
                      ),
                      const SizedBox(height: 9),
                      _SecureNote(recipient: recipient),
                    ],
                    if (rows.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      _BankTransferCard(rows: rows, recipient: recipient),
                    ],
                    if (note != null) ...[
                      const SizedBox(height: 14),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          note,
                          key: const ValueKey('giving-note'),
                          style: AppTypography.ui(
                            size: 13.5,
                            height: 1.45,
                            color: context.kc.muted,
                          ),
                        ),
                      ),
                    ],
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
      child: ColoredBox(
        // Solid brand card in both themes; text on it stays light.
        color: AppColors.primaryDeep,
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
  const _BranchSelector({
    required this.branch,
    required this.recipient,
    required this.onTap,
  });

  /// The member's campus choice (or "All campuses").
  final String branch;

  /// Whose account receives the gift: the campus, or the church.
  final String recipient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    return Semantics(
      button: true,
      label: 'Giving to $recipient from $branch. Change branch',
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      branch,
                      style: AppTypography.ui(
                        size: 15,
                        weight: FontWeight.w700,
                        color: kc.onBg,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$recipient account',
                      key: const ValueKey('giving-recipient'),
                      style: AppTypography.ui(size: 12.5, color: kc.muted),
                    ),
                  ],
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
  const _SecureNote({required this.recipient});

  final String recipient;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock_outline_rounded, size: 13, color: context.kc.muted),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            'Opens the secure $recipient giving page',
            style: AppTypography.ui(size: 12, color: context.kc.muted),
          ),
        ),
      ],
    );
  }
}

// ── Bank transfer card ──────────────────────────────────────────────────────

class _BankTransferCard extends StatelessWidget {
  const _BankTransferCard({required this.rows, required this.recipient});

  final List<(String, String)> rows;
  final String recipient;

  Future<void> _copy(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: _rowsText(rows)));
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
                      'To $recipient',
                      style: AppTypography.ui(size: 12.5, color: kc.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.ui(size: 13.5, color: kc.muted),
                  ),
                  const SizedBox(width: 12),
                  // The value takes the rest and wraps: a 22-character IBAN
                  // at 1.3x text no longer pushes the row off a small phone.
                  Expanded(
                    child: SelectableText(
                      value,
                      textAlign: TextAlign.end,
                      style: AppTypography.ui(
                        size: 13.5,
                        weight: FontWeight.w600,
                        color: kc.onBg,
                      ),
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
