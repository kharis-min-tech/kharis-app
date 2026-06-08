import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';

class GivingScreen extends StatefulWidget {
  const GivingScreen({super.key});

  @override
  State<GivingScreen> createState() => _GivingScreenState();
}

class _GivingScreenState extends State<GivingScreen> {
  int _selectedIndex = 2; // Default to £50

  static const List<String> _amounts = ['£10', '£25', '£50', '£100', '£250', 'Custom'];

  String get _selectedLabel {
    if (_selectedIndex < 0 || _selectedIndex >= _amounts.length) return 'GIVE';
    final a = _amounts[_selectedIndex];
    if (a == 'Custom') return 'GIVE';
    return 'GIVE $a';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ScriptureBlock(),
              const SizedBox(height: 24),
              _BranchSelector(),
              const SizedBox(height: 28),
              Text(
                'Select Amount',
                style: GoogleFonts.mavenPro(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              _AmountGrid(
                amounts: _amounts,
                selectedIndex: _selectedIndex,
                onSelected: (i) => setState(() => _selectedIndex = i),
              ),
              const SizedBox(height: 28),
              _GiveButton(label: _selectedLabel),
              const SizedBox(height: 36),
              Text(
                'Other Ways to Give',
                style: GoogleFonts.mavenPro(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              _OtherWayCard(
                iconColor: AppColors.purple,
                icon: Icons.account_balance_outlined,
                title: 'Bank Transfer',
                subtitle: 'Sort Code: 20-00-00 · Acc: 12345678',
              ),
              const SizedBox(height: 12),
              _OtherWayCard(
                iconColor: AppColors.orange,
                icon: Icons.business_outlined,
                title: 'Building Fund',
                subtitle: 'Dedicated fund for the new building',
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScriptureBlock extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '"Each of you should give what you have decided in your heart to give, not reluctantly or under compulsion, for God loves a cheerful giver."',
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.dmSans(
            color: AppColors.textBody,
            fontSize: 15,
            fontStyle: FontStyle.italic,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '2 Corinthians 9:7',
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(
            color: AppColors.orange,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _BranchSelector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(
            'Branch',
            style: GoogleFonts.dmSans(
              color: AppColors.textBody,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          Text(
            'London',
            style: GoogleFonts.dmSans(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.textBody,
            size: 20,
          ),
        ],
      ),
    );
  }
}

class _AmountGrid extends StatelessWidget {
  const _AmountGrid({
    required this.amounts,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> amounts;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.2,
      ),
      itemCount: amounts.length,
      itemBuilder: (context, i) {
        final selected = i == selectedIndex;
        return GestureDetector(
          onTap: () => onSelected(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: selected
                  ? Border.all(color: AppColors.orange, width: 1)
                  : Border.all(color: Colors.transparent, width: 1),
            ),
            alignment: Alignment.center,
            child: Text(
              amounts[i],
              style: GoogleFonts.mavenPro(
                color: selected ? AppColors.orange : AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GiveButton extends StatelessWidget {
  const _GiveButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: TextButton(
        onPressed: () {},
        style: TextButton.styleFrom(
          backgroundColor: AppColors.orange,
          foregroundColor: AppColors.textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.mavenPro(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

class _OtherWayCard extends StatelessWidget {
  const _OtherWayCard({
    required this.iconColor,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final Color iconColor;
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.mavenPro(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: GoogleFonts.dmSans(
                    color: AppColors.textBody,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textMuted,
            size: 20,
          ),
        ],
      ),
    );
  }
}
