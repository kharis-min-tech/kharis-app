import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';

Future<String?> showLanguageBottomSheet(
  BuildContext context, {
  String selected = 'English',
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.surfaceElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _LanguageBottomSheet(selected: selected),
  );
}

const _kLanguages = [
  ('🇬🇧', 'English'),
  ('🇫🇷', 'French'),
  ('🇵🇹', 'Portuguese'),
  ('🇬🇭', 'Twi'),
  ('🇸🇱', 'Krio'),
];

class _LanguageBottomSheet extends StatelessWidget {
  const _LanguageBottomSheet({required this.selected});

  final String selected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Language',
              style: GoogleFonts.mavenPro(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            ..._kLanguages.map(
              (entry) => _LanguageRow(
                flag: entry.$1,
                name: entry.$2,
                isSelected: entry.$2 == selected,
                onTap: () => Navigator.of(context).pop(entry.$2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({
    required this.flag,
    required this.name,
    required this.isSelected,
    required this.onTap,
  });

  final String flag;
  final String name;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                name,
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  color: AppColors.textPrimary,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check,
                color: AppColors.accent,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
