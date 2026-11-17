import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:kharis_app/shared/models/campus_config.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/campus_config_provider.dart';
import 'package:kharis_app/ui/components/components.dart';

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

/// Give (`/give`).
///
/// One column: the title, who the gift is for, 2 Corinthians 9:7, and one
/// primary button that opens the church giving page ([kGivingUrl]) in the
/// in-app browser. The church-wide bank-transfer details ([kBuiltInGiving])
/// sit below as a secondary card.
class GivingScreen extends ConsumerWidget {
  const GivingScreen({super.key});

  Future<void> _give(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final opened = await launchUrl(
      Uri.parse(kGivingUrl),
      // The giving page opens inside the app, never in another one.
      mode: LaunchMode.inAppBrowserView,
    ).catchError((Object _) => false);
    if (opened) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Could not open kharis.org. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = context.k;
    const giving = kBuiltInGiving;
    final rows = givingBankRows(giving);
    final note = giving.note;
    final recipient =
        ref.watch(currentBranchProvider).valueOrNull ?? kChurchWideRecipient;

    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: KSize.maxContentWidth),
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(
                top: KSpace.md,
                bottom: KSize.contentBottomPad,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const KScreenHeader(title: 'Give'),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      KSpace.gutter,
                      KSpace.xs,
                      KSpace.gutter,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'To $recipient. Thank you for giving.',
                          style: KharisText.body.copyWith(color: k.muted),
                        ),
                        const SizedBox(height: KSpace.x3),
                        const _ScriptureCard(),
                        const SizedBox(height: KSpace.x3),
                        KButton(
                          key: const Key('give-button'),
                          label: 'Give to $recipient',
                          size: KButtonSize.cta,
                          expand: true,
                          onPressed: () => _give(context),
                        ),
                        const SizedBox(height: KSpace.md),
                        const _SecureNote(),
                        if (rows.isNotEmpty) ...[
                          const SizedBox(height: KSpace.section),
                          _BankTransferCard(
                            rows: rows,
                            recipient: kChurchWideRecipient,
                          ),
                        ],
                        if (note != null) ...[
                          const SizedBox(height: KSpace.xl),
                          Text(
                            note,
                            key: const ValueKey('giving-note'),
                            style: KharisText.meta.copyWith(color: k.muted),
                          ),
                        ],
                      ],
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

/// The line under the Give button saying where the gift is made.
const String kGiveSecureNote =
    'You give securely on kharis.org, inside the app.';

/// Where the gift is made, under the Give button.
class _SecureNote extends StatelessWidget {
  const _SecureNote();

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return MergeSemantics(
      child: Row(
        key: const Key('give-secure-note'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          KIcon(KIcons.lock, size: KSize.iconXs, color: k.muted),
          const SizedBox(width: KSpace.xs),
          Flexible(
            child: Text(
              kGiveSecureNote,
              style: KharisText.meta.copyWith(color: k.muted),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Scripture card ────────────────────────────────────────────────────────────

/// 2 Corinthians 9:7 (KJV, public domain) on the highlight tint.
class _ScriptureCard extends StatelessWidget {
  const _ScriptureCard();

  static const String _verse =
      '\u201cEvery man according as he purposeth in his heart, so let him '
      'give; not grudgingly, or of necessity: for God loveth a cheerful '
      'giver.\u201d';
  static const String _reference = '2 Corinthians 9:7 \u00b7 KJV';

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return MergeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: k.highlightTint,
          borderRadius: const BorderRadius.all(Radius.circular(KRadius.card)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(KSpace.x3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_verse, style: KharisText.title.copyWith(color: k.text)),
              const SizedBox(height: KSpace.md),
              Text(
                _reference.toUpperCase(),
                semanticsLabel: _reference,
                style: KharisText.overline.copyWith(color: k.highlightText),
              ),
            ],
          ),
        ),
      ),
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
    final k = context.k;
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const KIconTile(KIcons.card),
              const SizedBox(width: KSpace.xl),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bank transfer',
                      style: KharisText.title.copyWith(color: k.text),
                    ),
                    Text(
                      'To $recipient',
                      style: KharisText.meta.copyWith(color: k.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: KSpace.xxl),
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: KSpace.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: KharisText.meta.copyWith(color: k.muted)),
                  const SizedBox(width: KSpace.xl),
                  // The value takes the rest and wraps: a 22-character IBAN
                  // at large text never pushes the row off a small phone.
                  Expanded(
                    child: SelectableText(
                      value,
                      textAlign: TextAlign.end,
                      style: KharisText.itemTitle.copyWith(color: k.text),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: KSpace.sm),
          KButton(
            label: 'Copy bank details',
            variant: KButtonVariant.outline,
            expand: true,
            onPressed: () => _copy(context),
          ),
        ],
      ),
    );
  }
}
