import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:kharis_app/core/theme/theme.dart';

// Displayed URL in the chrome bar (visual only, no actual webview).
const String _kSecurePortal = 'giving.kharischurch.org/secure-portal';

const List<int> _kPresets = [10, 50, 100];

const List<String> _kFunds = [
  'General Tithes & Offering',
  'Building Fund',
  'Missions',
  'Youth Ministry',
];

class GivingScreen extends StatefulWidget {
  const GivingScreen({super.key});

  @override
  State<GivingScreen> createState() => _GivingScreenState();
}

class _GivingScreenState extends State<GivingScreen> {
  int _selectedAmount = 50;
  final TextEditingController _customController = TextEditingController();
  String _fund = _kFunds[0];
  bool _done = false;

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  // Resolved display amount for the CTA and success copy.
  String get _displayAmount {
    final custom = _customController.text.trim();
    if (custom.isNotEmpty) return '\$$custom';
    return '\$$_selectedAmount';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 150),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TopBar(onClose: () => context.go('/home')),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _ChromeBar(url: _kSecurePortal),
                    _Panel(
                      done: _done,
                      selectedAmount: _selectedAmount,
                      customController: _customController,
                      fund: _fund,
                      displayAmount: _displayAmount,
                      onAmountSelected: (v) => setState(() {
                        _selectedAmount = v;
                        _customController.clear();
                      }),
                      onCustomChanged: (_) => setState(() {}),
                      onFundChanged: (v) => setState(() => _fund = v),
                      onGive: () => setState(() => _done = true),
                      onGiveAgain: () => setState(() {
                        _done = false;
                        _customController.clear();
                        _selectedAmount = 50;
                      }),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: _FooterPill(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Top Bar ─────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: onClose,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.surfaceSubtle,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                color: AppColors.secondary,
                size: 20,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Kharis Giving',
              textAlign: TextAlign.center,
              style: AppTypography.bodySm.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.secondary,
              ),
            ),
          ),
          // Right spacer mirrors the close button width.
          const SizedBox(width: 38),
        ],
      ),
    );
  }
}

// ── Chrome Bar ───────────────────────────────────────────────────────────────

class _ChromeBar extends StatelessWidget {
  const _ChromeBar({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(14),
          topRight: Radius.circular(14),
        ),
        border: Border(
          top: BorderSide(color: AppColors.outlineVariant),
          left: BorderSide(color: AppColors.outlineVariant),
          right: BorderSide(color: AppColors.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_rounded, size: 14, color: AppColors.secondary),
          const SizedBox(width: 8),
          Text(
            url,
            style: AppTypography.labelMd.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: AppColors.textMuted,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Panel ────────────────────────────────────────────────────────────────────

class _Panel extends StatelessWidget {
  const _Panel({
    required this.done,
    required this.selectedAmount,
    required this.customController,
    required this.fund,
    required this.displayAmount,
    required this.onAmountSelected,
    required this.onCustomChanged,
    required this.onFundChanged,
    required this.onGive,
    required this.onGiveAgain,
  });

  final bool done;
  final int selectedAmount;
  final TextEditingController customController;
  final String fund;
  final String displayAmount;
  final ValueChanged<int> onAmountSelected;
  final ValueChanged<String> onCustomChanged;
  final ValueChanged<String> onFundChanged;
  final VoidCallback onGive;
  final VoidCallback onGiveAgain;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 26),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        border: Border(
          bottom: BorderSide(color: AppColors.outlineVariant),
          left: BorderSide(color: AppColors.outlineVariant),
          right: BorderSide(color: AppColors.outlineVariant),
        ),
      ),
      child: done
          ? _SuccessState(
              displayAmount: displayAmount,
              fund: fund,
              onGiveAgain: onGiveAgain,
            )
          : _FormState(
              selectedAmount: selectedAmount,
              customController: customController,
              fund: fund,
              displayAmount: displayAmount,
              onAmountSelected: onAmountSelected,
              onCustomChanged: onCustomChanged,
              onFundChanged: onFundChanged,
              onGive: onGive,
            ),
    );
  }
}

// ── Form State ────────────────────────────────────────────────────────────────

class _FormState extends StatelessWidget {
  const _FormState({
    required this.selectedAmount,
    required this.customController,
    required this.fund,
    required this.displayAmount,
    required this.onAmountSelected,
    required this.onCustomChanged,
    required this.onFundChanged,
    required this.onGive,
  });

  final int selectedAmount;
  final TextEditingController customController;
  final String fund;
  final String displayAmount;
  final ValueChanged<int> onAmountSelected;
  final ValueChanged<String> onCustomChanged;
  final ValueChanged<String> onFundChanged;
  final VoidCallback onGive;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icon tile: 60px gradient circle with heart icon.
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: AppColors.tertiary,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(
            Icons.favorite_rounded,
            color: AppColors.surfaceElevated,
            size: 28,
          ),
        ),
        const SizedBox(height: 16),

        // Title.
        Text(
          'Generous Giving',
          style: AppTypography.titleMd.copyWith(
            fontSize: 25,
            fontWeight: FontWeight.w800,
            color: AppColors.heading,
          ),
        ),
        const SizedBox(height: 6),

        // Subtitle.
        Text(
          'Supporting our mission and community growth',
          style: AppTypography.bodySm.copyWith(
            fontSize: 13,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 22),

        // Section label.
        _SectionLabel('SELECT AMOUNT'),
        const SizedBox(height: 10),

        // 3-col amount grid.
        Row(
          children: [
            for (int i = 0; i < _kPresets.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: _AmountButton(
                  label: '\$${_kPresets[i]}',
                  isSelected:
                      selectedAmount == _kPresets[i] &&
                      customController.text.isEmpty,
                  onTap: () => onAmountSelected(_kPresets[i]),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),

        // Custom amount field.
        _CustomAmountField(
          controller: customController,
          onChanged: onCustomChanged,
        ),
        const SizedBox(height: 20),

        // Fund section label.
        _SectionLabel('GIVE TO'),
        const SizedBox(height: 10),

        // Fund selector.
        _FundSelector(value: fund, funds: _kFunds, onChanged: onFundChanged),
        const SizedBox(height: 24),

        // Gold CTA.
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onGive,
            icon: const Icon(Icons.favorite_rounded, size: 18),
            label: Text(
              'Give $displayAmount',
              style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w800),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              foregroundColor: AppColors.onSecondary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Success State ─────────────────────────────────────────────────────────────

class _SuccessState extends StatelessWidget {
  const _SuccessState({
    required this.displayAmount,
    required this.fund,
    required this.onGiveAgain,
  });

  final String displayAmount;
  final String fund;
  final VoidCallback onGiveAgain;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 16),
        // Green check circle.
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFF7CC278).withValues(alpha: .16),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_rounded,
            size: 36,
            color: Color(0xFF8FD58A),
          ),
        ),
        const SizedBox(height: 20),

        Text(
          'Thank you!',
          style: AppTypography.titleMd.copyWith(
            fontSize: 23,
            fontWeight: FontWeight.w800,
            color: AppColors.heading,
          ),
        ),
        const SizedBox(height: 10),

        Text(
          'Your gift of $displayAmount toward $fund has been received.',
          textAlign: TextAlign.center,
          style: AppTypography.bodySm.copyWith(
            fontSize: 14,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),

        // Give Again glass pill.
        GestureDetector(
          onTap: onGiveAgain,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Text(
              'Give Again',
              style: AppTypography.bodySm.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.heading,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ── Footer Pill ───────────────────────────────────────────────────────────────

class _FooterPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.shield_rounded,
              size: 14,
              color: AppColors.secondary,
            ),
            const SizedBox(width: 7),
            Text(
              'Secure official Kharis giving portal',
              style: AppTypography.bodySm.copyWith(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared Section Label ──────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.labelMd.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF7A747E),
        letterSpacing: 1.1,
      ),
    );
  }
}

// ── Amount Button ─────────────────────────────────────────────────────────────

class _AmountButton extends StatelessWidget {
  const _AmountButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.secondary : AppColors.surfaceSubtle,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? null
              : Border.all(color: AppColors.outlineVariant),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTypography.bodySm.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isSelected ? AppColors.onSecondary : AppColors.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Custom Amount Field ───────────────────────────────────────────────────────

class _CustomAmountField extends StatelessWidget {
  const _CustomAmountField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
      style: AppTypography.bodySm.copyWith(
        fontSize: 15,
        color: AppColors.onSurface,
      ),
      cursorColor: AppColors.secondary,
      decoration: InputDecoration(
        hintText: 'Other amount',
        hintStyle: AppTypography.bodySm.copyWith(
          fontSize: 15,
          color: AppColors.textMuted,
        ),
        prefixText: '\$ ',
        prefixStyle: AppTypography.bodySm.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.secondary,
        ),
        filled: true,
        fillColor: AppColors.surfaceSubtle,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.secondary, width: 1.5),
        ),
      ),
    );
  }
}

// ── Fund Selector ─────────────────────────────────────────────────────────────

class _FundSelector extends StatelessWidget {
  const _FundSelector({
    required this.value,
    required this.funds,
    required this.onChanged,
  });

  final String value;
  final List<String> funds;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: AppColors.surfaceElevated,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.textFaint,
          ),
          items: funds
              .map(
                (f) => DropdownMenuItem<String>(
                  value: f,
                  child: Text(
                    f,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySm.copyWith(
                      fontSize: 15,
                      color: AppColors.onSurface,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}
