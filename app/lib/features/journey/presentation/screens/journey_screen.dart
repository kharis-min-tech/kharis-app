import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/shared/providers/cache_provider.dart';
import 'package:kharis_app/features/journey/data/journey_content.dart';
import 'package:kharis_app/features/connect/presentation/screens/new_here_screen.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

/// Persisted set of completed step indices (0-3).
final _completedStepsProvider =
    StateNotifierProvider<_CompletedStepsNotifier, Set<int>>((ref) {
  return _CompletedStepsNotifier(ref.watch(cacheServiceProvider));
});

class _CompletedStepsNotifier extends StateNotifier<Set<int>> {
  _CompletedStepsNotifier(this._cache) : super(_load(_cache));

  final dynamic _cache; // CacheService

  static const _key = 'journey_completed_steps';

  static Set<int> _load(dynamic cache) {
    final raw = cache.getStringList(_key) as List<String>?;
    if (raw == null) return <int>{};
    return raw.map(int.parse).toSet();
  }

  void toggle(int index) {
    final next = Set<int>.from(state);
    if (!next.add(index)) next.remove(index);
    state = next;
    _cache.setStringList(_key, next.map((e) => e.toString()).toList());
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

/// "Your Journey" — scripture-forward growth path (design-handoff v3).
/// Calm warm surface, Newsreader serif scripture, gold progress accents.
class JourneyScreen extends ConsumerWidget {
  const JourneyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completed = ref.watch(_completedStepsProvider);
    final allDone = completed.length == kJourneySteps.length;

    return Scaffold(
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
                child: Icon(
                  Icons.chevron_left,
                  color: context.kc.muted,
                  size: 28,
                ),
              ),

              const SizedBox(height: 20),

              // Heading
              Text(
                'Your Journey',
                style: AppTypography.display(size: 28, weight: FontWeight.w700)
                    .copyWith(color: context.kc.onBg),
              ),

              const SizedBox(height: 6),

              Text(
                'Salvation \u00B7 Baptism \u00B7 Holy Spirit \u00B7 Next Steps',
                style: AppTypography.serif(size: 15, italic: true)
                    .copyWith(color: context.kc.muted),
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
                        color: context.kc.divider,
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
                  color: context.kc.surface,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  boxShadow: AppShadows.card,
                ),
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      step.title,
                      style: AppTypography.ui(
                        size: 17,
                        weight: FontWeight.w700,
                        color: context.kc.onBg,
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Scripture quote (serif, scripture-forward)
                    Text(
                      step.scripture,
                      style: AppTypography.serif(
                        size: 15,
                        italic: true,
                        height: 1.55,
                        color: AppColors.primary,
                      ),
                    ),

                    const SizedBox(height: 4),

                    // Scripture ref
                    Text(
                      step.scriptureRef,
                      style: AppTypography.ui(
                        size: 12,
                        weight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Body
                    Text(
                      step.body,
                      style: AppTypography.ui(
                        size: 14,
                        height: 1.6,
                        color: context.kc.muted,
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
        color: done ? context.kc.accent : context.kc.chipBg,
      ),
      child: Center(
        child: done
            ? Icon(Icons.check, color: context.kc.onAccent, size: 16)
            : Text(
                '$number',
                style: AppTypography.ui(
                  size: 13,
                  weight: FontWeight.w700,
                  color: AppColors.primary,
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
          color: done ? context.kc.accent : Colors.transparent,
          // Matches the fill once complete so the rim stays invisible; the
          // darkened gold while it is still an outline on the page.
          border: Border.all(
            color: done ? context.kc.accent : context.kc.accentInk,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (done) ...[
              Icon(Icons.check, color: context.kc.onAccent, size: 14),
              const SizedBox(width: 6),
            ],
            Text(
              done ? 'Completed' : 'Mark complete',
              style: AppTypography.ui(
                size: 13,
                weight: FontWeight.w600,
                color: done ? context.kc.onAccent : AppColors.hqStroke,
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
          colors: [AppColors.primary, AppColors.primaryDeep],
        ),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome to new life in Christ.',
            style: AppTypography.display(size: 20, weight: FontWeight.w700)
                .copyWith(color: AppColors.onPrimary),
          ),

          const SizedBox(height: 10),

          Text(
            'Speak to any team member on Sunday. We want to celebrate with you.',
            style: AppTypography.serif(
              size: 15,
              italic: true,
              height: 1.55,
              color: AppColors.darkMuted3,
            ),
          ),

          const SizedBox(height: 20),

          GestureDetector(
            onTap: onConnect,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'New Here? Connect',
                    style: AppTypography.ui(
                      size: 14,
                      weight: FontWeight.w700,
                      color: AppColors.onSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward,
                      color: AppColors.onSecondary, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
