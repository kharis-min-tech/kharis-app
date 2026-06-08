import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kharis_app/core/theme/app_colors.dart';
import 'package:kharis_app/features/onboarding/presentation/widgets/branch_tile.dart';

// Scoped to the onboarding flow — discarded once the router pops this screen.
final _selectedBranchProvider = StateProvider<String?>((ref) => null);

const _kBranches = <({String name, String location})>[
  (name: 'London', location: 'London, UK'),
  (name: 'Birmingham', location: 'Birmingham, UK'),
  (name: 'Reading', location: 'Reading, UK'),
  (name: 'Chatham', location: 'Chatham, UK'),
  (name: 'Croydon', location: 'Croydon, UK'),
  (name: 'Medway', location: 'Medway, UK'),
  (name: 'Accra', location: 'Accra, Ghana'),
  (name: 'Freetown', location: 'Freetown, Sierra Leone'),
];

class BranchSelectionScreen extends ConsumerStatefulWidget {
  const BranchSelectionScreen({super.key});

  @override
  ConsumerState<BranchSelectionScreen> createState() =>
      _BranchSelectionScreenState();
}

class _BranchSelectionScreenState
    extends ConsumerState<BranchSelectionScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<({String name, String location})> get _filtered {
    if (_query.isEmpty) return _kBranches;
    final lower = _query.toLowerCase();
    return _kBranches
        .where((b) => b.name.toLowerCase().contains(lower))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(_selectedBranchProvider);
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),

              // ── Title ────────────────────────────────────────────────────
              Text(
                'Select your branch',
                style: GoogleFonts.mavenPro(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You can change this later in settings',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  color: AppColors.textBody,
                ),
              ),
              const SizedBox(height: 28),

              // ── Search field ─────────────────────────────────────────────
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextField(
                  controller: _searchController,
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Search branches...',
                    hintStyle: GoogleFonts.dmSans(
                      fontSize: 15,
                      color: AppColors.textBody,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.textBody,
                      size: 20,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Branch list ───────────────────────────────────────────────
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No branches found',
                          style: GoogleFonts.dmSans(
                            fontSize: 15,
                            color: AppColors.textBody,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final branch = filtered[i];
                          return BranchTile(
                            name: branch.name,
                            location: branch.location,
                            isSelected: selected == branch.name,
                            onTap: () => ref
                                .read(_selectedBranchProvider.notifier)
                                .state = branch.name,
                          );
                        },
                      ),
              ),
              const SizedBox(height: 20),

              // ── CTA ──────────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      selected != null ? () => context.go('/login') : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.orange,
                    disabledBackgroundColor: AppColors.orange.withValues(alpha: 0.35),
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                  ),
                  child: Text(
                    'CONTINUE',
                    style: GoogleFonts.mavenPro(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
