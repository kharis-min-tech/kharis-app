import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'giving_webview_screen.dart';

/// Giving URL used by both GIVE NOW and any future deep-link.
const String _kGivingUrl = 'https://kharis.org/give';

const List<int> _kPresets = [10, 50, 100];

const List<String> _kCategories = [
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
  int? _selectedPreset = 50;
  final TextEditingController _customController = TextEditingController();
  String _selectedCategory = _kCategories[0];

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── 1. Header ────────────────────────────────────────────────────
              Text(
                'Generous Giving',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Supporting our mission and community growth',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),

              // ── 2. Glass portal card ─────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E).withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── SELECT AMOUNT ────────────────────────────────────────
                    Text(
                      'SELECT AMOUNT',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ── Preset buttons row ───────────────────────────────────
                    Row(
                      children: [
                        for (int i = 0; i < _kPresets.length; i++) ...[
                          if (i > 0) const SizedBox(width: 10),
                          Expanded(
                            child: _AmountButton(
                              label: '£${_kPresets[i]}',
                              isSelected: _selectedPreset == _kPresets[i] &&
                                  _customController.text.isEmpty,
                              onTap: () => setState(() {
                                _selectedPreset = _kPresets[i];
                                _customController.clear();
                              }),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),

                    // ── Custom amount input ──────────────────────────────────
                    _CustomAmountField(
                      controller: _customController,
                      onChanged: (v) => setState(() {
                        if (v.isNotEmpty) _selectedPreset = null;
                      }),
                    ),
                    const SizedBox(height: 20),

                    // ── GIVE TO ──────────────────────────────────────────────
                    Text(
                      'GIVE TO',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 10),

                    _CategoryDropdown(
                      value: _selectedCategory,
                      categories: _kCategories,
                      onChanged: (v) => setState(() => _selectedCategory = v),
                    ),
                    const SizedBox(height: 20),

                    // ── Give Now CTA ─────────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => openGivingFlow(context, _kGivingUrl),
                        icon: const Icon(Icons.favorite_rounded, size: 18),
                        label: Text(
                          'Give Now',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          foregroundColor: AppColors.onSecondary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Payment icons row ────────────────────────────────────
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.credit_card_outlined,
                          color: AppColors.textMuted,
                          size: 22,
                        ),
                        SizedBox(width: 16),
                        Icon(
                          Icons.account_balance_outlined,
                          color: AppColors.textMuted,
                          size: 22,
                        ),
                        SizedBox(width: 16),
                        Icon(
                          Icons.contactless,
                          color: AppColors.textMuted,
                          size: 22,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── 3. Trust badge ───────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.lock_outline_rounded,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'You are viewing our secure official giving portal.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ── _AmountButton ──────────────────────────────────────────────────────────────

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
          color: AppColors.surfaceSubtle,
          borderRadius: BorderRadius.circular(AppRadius.defaultRadius),
          border: Border.all(
            color: isSelected ? AppColors.secondary : AppColors.outlineVariant,
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isSelected ? AppColors.secondary : AppColors.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

// ── _CustomAmountField ─────────────────────────────────────────────────────────

class _CustomAmountField extends StatelessWidget {
  const _CustomAmountField({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
      ],
      style: GoogleFonts.plusJakartaSans(
        fontSize: 15,
        color: AppColors.onSurface,
      ),
      cursorColor: AppColors.secondary,
      decoration: InputDecoration(
        hintText: 'Other amount',
        hintStyle: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          color: AppColors.textMuted,
        ),
        prefixText: '£ ',
        prefixStyle: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          color: AppColors.textMuted,
        ),
        filled: true,
        fillColor: AppColors.surfaceSubtle,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.defaultRadius),
          borderSide: const BorderSide(color: AppColors.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.defaultRadius),
          borderSide: const BorderSide(color: AppColors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.defaultRadius),
          borderSide: const BorderSide(color: AppColors.secondary, width: 2),
        ),
      ),
    );
  }
}

// ── _CategoryDropdown ──────────────────────────────────────────────────────────

class _CategoryDropdown extends StatelessWidget {
  const _CategoryDropdown({
    required this.value,
    required this.categories,
    required this.onChanged,
  });

  final String value;
  final List<String> categories;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadius.defaultRadius),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: AppColors.surfaceElevated,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.textMuted,
          ),
          items: categories
              .map(
                (c) => DropdownMenuItem<String>(
                  value: c,
                  child: Text(
                    c,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
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
