import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

class TodaysReadingCard extends ConsumerWidget {
  const TodaysReadingCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentAsync = ref.watch(dailyContentProvider);

    return contentAsync.when(
      loading: () => _buildPill(
        label: "Today's reading",
        reference: 'Loading...',
      ),
      error: (_, _) => _buildPill(
        label: "Today's reading",
        reference: 'John 10',
      ),
      data: (content) => _buildPill(
        label: "Today's reading",
        reference: '${content.reading.book} ${content.reading.chapter}',
      ),
    );
  }

  Widget _buildPill({required String label, required String reference}) {
    return Builder(
      builder: (context) => GestureDetector(
        onTap: () => context.push('/reading'),
        child: _pillBody(label: label, reference: reference),
      ),
    );
  }

  Widget _pillBody({required String label, required String reference}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.pill,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  reference,
                  style: GoogleFonts.mavenPro(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Color(0xFFD4A017), // gold
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.menu_book_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}
