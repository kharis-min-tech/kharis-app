import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kharis_app/core/theme/app_colors.dart';
import 'package:kharis_app/shared/providers/cache_provider.dart';
import 'package:kharis_app/features/journey/data/journey_content.dart';
import 'package:kharis_app/features/connect/presentation/screens/new_here_screen.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

/// Persisted set of completed step indices (0-3).
final _completedStepsProvider =
    StateNotifierProvider<_CompletedStepsNotifier, Set<int>>((ref) {
  final cache = ref.read(cacheServiceProvider);
  return _CompletedStepsNotifier(cache);
});

class _CompletedStepsNotifier extends StateNotifier<Set<int>> {
  _CompletedStepsNotifier(this._cache) : super(_load(_cache));

  final dynamic _cache; // CacheService

  static const _key = 'journey_completed_steps';

  static Set<int> _load(dynamic cache) {
    final raw = cache.getPreference<String>(_key, '');
    if (raw.isEmpty) return {};
    return raw
        .split(',')
        .map((s) => int.tryParse(s.trim()))
        .whereType<int>()
        .toSet();
  }

  void toggle(int index) {
    final next = Set<int>.from(state);
    if (next.contains(index)) {
      next.remove(index);
    } else {
      next.add(index);
    }
    state = next;
    _cache.cachePreference(_key, next.isEmpty ? '' : next.join(','));
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class JourneyScreen extends ConsumerWidget {
  const JourneyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completed = ref.watch(_completedStepsProvider);
    final allDone = completed.length == kJourneySteps.length;

    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              // Back chevron
              GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                child: const Icon(
                  Icons.chevron_left,
                  color: AppColors.textMuted,
                  size: 28,
                ),
              ),

              const SizedBox(height: 20),

              // Heading
              Text(
                'Your Journey',
                style: GoogleFonts.mavenPro(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                'Salvation - Baptism - Holy Spirit - Next Steps',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),

              const SizedBox(height: 32),

              // Stepper
              ...List.generate(kJourneySteps.length, (i) {
                final step = kJourneySteps[i];
                final isDone = completed.contains(i);
                final isLast = i == kJourneySteps.length - 1;

                return _StepCard(
                  index: i,
                  step: step,
                  isDone: isDone,
                  isLast: isLast,
                  onToggle: () =>
                      ref.read(_completedStepsProvider.notifier).toggle(i),
                );
              }),

              // Celebration card
              if (allDone) ...[
                const SizedBox(height: 8),
                _CelebrationCard(
                  onConnect: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const NewHereScreen(),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Step card ─────────────────────────────────────────────────────────────────

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.index,
    required this.step,
    required this.isDone,
    required this.isLast,
    required this.onToggle,
  });

  final int index;
  final JourneyStep step;
  final bool isDone;
  final bool isLast;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left rail: circle + connecting line
          SizedBox(
            width: 40,
            child: Column(
              children: [
                _RailCircle(number: index + 1, done: isDone),
                if (!isLast)
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 2,
                        color: AppColors.surfaceSubtle,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 14),

          // Card content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      step.title,
                      style: GoogleFonts.mavenPro(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Scripture quote
                    Text(
                      step.scripture,
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: AppColors.accent,
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 4),

                    // Scripture ref
                    Text(
                      step.scriptureRef,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accent,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Body
                    Text(
                      step.body,
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        color: AppColors.textBody,
                        height: 1.6,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Mark complete pill
                    Align(
                      alignment: Alignment.centerRight,
                      child: _CompletePill(done: isDone, onTap: onToggle),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Rail circle ───────────────────────────────────────────────────────────────

class _RailCircle extends StatelessWidget {
  const _RailCircle({required this.number, required this.done});

  final int number;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: done
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.purple, AppColors.accent],
              )
            : null,
        color: done ? null : AppColors.surfaceSubtle,
      ),
      child: Center(
        child: done
            ? const Icon(Icons.check, color: Colors.white, size: 16)
            : Text(
                '$number',
                style: GoogleFonts.mavenPro(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
      ),
    );
  }
}

// ── Complete pill ─────────────────────────────────────────────────────────────

class _CompletePill extends StatelessWidget {
  const _CompletePill({required this.done, required this.onTap});

  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: done ? AppColors.accent : Colors.transparent,
          border: Border.all(
            color: AppColors.accent,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (done) ...[
              const Icon(Icons.check, color: Colors.white, size: 14),
              const SizedBox(width: 6),
            ],
            Text(
              done ? 'Completed' : 'Mark complete',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: done ? Colors.white : AppColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Celebration card ──────────────────────────────────────────────────────────

class _CelebrationCard extends StatelessWidget {
  const _CelebrationCard({required this.onConnect});

  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A1040),
            Color(0xFF1A1A2E),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.purple.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome to new life in Christ.',
            style: GoogleFonts.mavenPro(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 10),

          Text(
            'Speak to any team member on Sunday. We want to celebrate with you.',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              color: AppColors.textBody,
              height: 1.6,
            ),
          ),

          const SizedBox(height: 20),

          GestureDetector(
            onTap: onConnect,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [AppColors.purple, AppColors.accent],
                ),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'New Here? Connect',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward, color: Colors.white, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
