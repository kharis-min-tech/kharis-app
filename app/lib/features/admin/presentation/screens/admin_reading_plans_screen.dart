import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/admin/presentation/widgets/reading_plan_form_sheet.dart';
import 'package:kharis_app/features/home/data/daily_content_repository.dart';
import 'package:kharis_app/features/home/data/reading_plan_repository.dart';
import 'package:kharis_app/shared/providers/reading_plan_provider.dart';

/// Admin screen: reading plans. A plan is authored once and covers a date range,
/// advancing a chapter (or a verse block) per day with no further input.
class AdminReadingPlansScreen extends ConsumerStatefulWidget {
  const AdminReadingPlansScreen({super.key});

  @override
  ConsumerState<AdminReadingPlansScreen> createState() =>
      _AdminReadingPlansScreenState();
}

class _AdminReadingPlansScreenState
    extends ConsumerState<AdminReadingPlansScreen> {
  DateTime _previewDate = dateOnly(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(readingPlansProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Reading Plans',
          style: AppTypography.titleMd.copyWith(color: AppColors.heading),
        ),
        iconTheme: const IconThemeData(color: AppColors.heading),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.secondary,
        foregroundColor: AppColors.onSecondary,
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
      body: plansAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.secondary),
        ),
        error: (e, _) => Center(
          child: Text(
            'Could not load plans.',
            style:
                AppTypography.bodyLg.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ),
        data: (plans) => ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.sm,
            AppSpacing.gutter,
            AppSpacing.lg + AppSpacing.lg,
          ),
          children: [
            _PreviewCard(date: _previewDate, onPickDate: _pickPreviewDate),
            const SizedBox(height: AppSpacing.md),
            Text(
              plans.isEmpty ? 'No plans yet' : 'Plans',
              style: AppTypography.labelMd
                  .copyWith(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.xs),
            if (plans.isEmpty)
              Text(
                'Add a plan to schedule a whole month at once — a chapter a '
                'day, or a verse block a day.',
                style:
                    AppTypography.bodySm.copyWith(color: AppColors.textMuted),
              ),
            for (final plan in plans) ...[
              _PlanCard(
                plan: plan,
                onEdit: () => _openForm(plan: plan),
                onDelete: () => _confirmDelete(plan),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickPreviewDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _previewDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2032),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.secondary,
            surface: AppColors.surfaceDark,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _previewDate = dateOnly(picked));
  }

  void _openForm({ReadingPlan? plan}) {
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(readingPlanRepositoryProvider);
    final existing = ref.read(readingPlansProvider).valueOrNull ?? const [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReadingPlanFormSheet(
        plan: plan,
        existing: existing,
        repo: repo,
        onSuccess: (msg) =>
            messenger.showSnackBar(SnackBar(content: Text(msg))),
        onError: (msg) => messenger.showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.errorContainer,
        )),
      ),
    );
  }

  void _confirmDelete(ReadingPlan plan) {
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(readingPlanRepositoryProvider);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: Text(
          'Delete plan?',
          style: AppTypography.titleMd.copyWith(color: AppColors.heading),
        ),
        content: Text(
          'Dates covered by "${planLabel(plan)}" will fall back to an earlier '
          'plan, or to the last day of the plan that ended most recently. This '
          'cannot be undone.',
          style:
              AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: AppTypography.bodySm
                  .copyWith(color: AppColors.onSurfaceVariant),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await repo.deletePlan(plan.id);
                messenger.showSnackBar(
                  const SnackBar(content: Text('Plan deleted.')),
                );
              } catch (e) {
                messenger.showSnackBar(SnackBar(
                  content: Text('Delete failed: $e'),
                  backgroundColor: AppColors.errorContainer,
                ));
              }
            },
            child: Text(
              'Delete',
              style: AppTypography.bodySm.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Resolution preview ───────────────────────────────────────────────────────

/// Shows exactly what a member opening the app on [date] would see, and which
/// rule produced it — a hand-written day, a plan, a pinned expired plan, or the
/// built-in fallback.
class _PreviewCard extends ConsumerWidget {
  const _PreviewCard({required this.date, required this.onPickDate});

  final DateTime date;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(readingPreviewProvider(readingDateKey(date)));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'What members see',
                  style: AppTypography.labelMd.copyWith(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onPickDate,
                icon: const Icon(Icons.calendar_today,
                    size: 16, color: AppColors.secondary),
                label: Text(
                  formatPlanDate(date),
                  style: AppTypography.labelMd
                      .copyWith(color: AppColors.secondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          preview.when(
            loading: () => Text(
              'Resolving...',
              style: AppTypography.bodySm.copyWith(color: AppColors.textMuted),
            ),
            error: (e, _) => Text(
              'Could not resolve this date.',
              style: AppTypography.bodySm.copyWith(color: AppColors.error),
            ),
            data: (resolved) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  resolved.content.reading.reference,
                  style: AppTypography.titleMd.copyWith(
                    color: AppColors.heading,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _sourceLabel(resolved),
                  style: AppTypography.bodySm.copyWith(
                    color: resolved.source == DailyContentSource.fallback
                        ? AppColors.error
                        : AppColors.onSurfaceVariant,
                  ),
                ),
                if (resolved.content.prayer.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    resolved.content.prayer,
                    style: AppTypography.bodySm
                        .copyWith(color: AppColors.textMuted),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _sourceLabel(ResolvedDailyContent resolved) {
    final plan = (resolved.planTitle ?? '').isNotEmpty
        ? '"${resolved.planTitle}"'
        : 'a plan';
    switch (resolved.source) {
      case DailyContentSource.day:
        return 'Written by hand for this date — overrides any plan.';
      case DailyContentSource.plan:
        return 'From plan $plan.';
      case DailyContentSource.planLastDay:
        return 'Plan $plan has finished — held on its last day until a new '
            'plan starts.';
      case DailyContentSource.fallback:
        return 'Nothing covers this date. Members see the built-in default '
            'reading.';
    }
  }
}

// ── Plan card ────────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.onEdit,
    required this.onDelete,
  });

  final ReadingPlan plan;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: AppRadius.cardBorder,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.15),
                      borderRadius: AppRadius.pillBorder,
                    ),
                    child: Text(
                      '${formatPlanDate(plan.startDate)} → '
                      '${formatPlanDate(plan.endDate)}',
                      style: AppTypography.labelMd
                          .copyWith(color: AppColors.secondary),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    planLabel(plan),
                    style: AppTypography.bodyLg.copyWith(
                      color: AppColors.heading,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${plan.days} days · ${planRuleSummary(plan)}',
                    style: AppTypography.bodySm
                        .copyWith(color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Day 1: ${plan.readingForDay(0).reference}  ·  '
                    'Day ${plan.days}: ${plan.lastReading.reference}',
                    style: AppTypography.bodySm
                        .copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  color: AppColors.onSurfaceVariant,
                  onPressed: onEdit,
                  tooltip: 'Edit',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  color: AppColors.error,
                  onPressed: onDelete,
                  tooltip: 'Delete',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
