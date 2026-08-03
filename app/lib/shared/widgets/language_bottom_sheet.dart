import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/theme.dart';
import '../providers/cache_provider.dart';

const _kAppLanguageKey = 'app_language';

Future<String?> showLanguageBottomSheet(
  BuildContext context, {
  String selected = 'English', // kept for API compat; sheet reads cache
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: context.kc.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _LanguageBottomSheet(),
  );
}

const _kLanguages = [
  ('🇬🇧', 'English'),
  ('🇫🇷', 'French'),
  ('🇵🇹', 'Portuguese'),
  ('🇬🇭', 'Twi'),
  ('🇸🇱', 'Krio'),
];

class _LanguageBottomSheet extends ConsumerStatefulWidget {
  const _LanguageBottomSheet();

  @override
  ConsumerState<_LanguageBottomSheet> createState() =>
      _LanguageBottomSheetState();
}

class _LanguageBottomSheetState extends ConsumerState<_LanguageBottomSheet> {
  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = ref
        .read(cacheServiceProvider)
        .getPreference<String>(_kAppLanguageKey, 'English');
  }

  void _select(String name) {
    ref.read(cacheServiceProvider).cachePreference(_kAppLanguageKey, name);
    Navigator.of(context).pop(name);
  }

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
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: context.kc.onBg,
              ),
            ),
            const SizedBox(height: 16),
            ..._kLanguages.map(
              (entry) => _LanguageRow(
                flag: entry.$1,
                name: entry.$2,
                isSelected: entry.$2 == _selected,
                onTap: () => _select(entry.$2),
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
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  color: context.kc.onBg,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check,
                color: context.kc.accentInk,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
