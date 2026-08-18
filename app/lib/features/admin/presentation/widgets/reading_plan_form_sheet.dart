import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:kharis_app/core/constants/bible_books.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/home/data/reading_plan_repository.dart';

/// `Jan 4, 2026`.
String formatPlanDate(DateTime date) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

/// Display name for a plan — its title, falling back to the book.
String planLabel(ReadingPlan plan) =>
    plan.title.isNotEmpty ? plan.title : plan.book;

/// One-line description of how a plan advances from day to day.
String planRuleSummary(ReadingPlan plan) {
  if (plan.mode == ReadingPlanMode.verse) {
    final perDay = plan.versesPerDay == 1
        ? 'one verse a day'
        : '${plan.versesPerDay} verses a day';
    return '${plan.book} ${plan.startChapter}, $perDay';
  }
  final range = (plan.verses ?? '').trim();
  return 'One chapter a day${range.isEmpty ? '' : ' (verses $range)'}';
}

/// Bottom sheet that creates or edits a [ReadingPlan].
///
/// A plan is authored once and covers a date range; the reading for each day is
/// derived, never typed in per day.
class ReadingPlanFormSheet extends StatefulWidget {
  const ReadingPlanFormSheet({
    super.key,
    this.plan,
    required this.existing,
    required this.repo,
    required this.onSuccess,
    required this.onError,
  });

  final ReadingPlan? plan;

  /// Already-saved plans, used to warn about an overlapping start date.
  final List<ReadingPlan> existing;
  final ReadingPlanRepository repo;
  final void Function(String) onSuccess;
  final void Function(String) onError;

  @override
  State<ReadingPlanFormSheet> createState() => _ReadingPlanFormSheetState();
}

class _ReadingPlanFormSheetState extends State<ReadingPlanFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleCtrl;
  late final TextEditingController _daysCtrl;
  late final TextEditingController _versesCtrl;
  late final TextEditingController _startVerseCtrl;
  late final TextEditingController _versesPerDayCtrl;
  late final TextEditingController _prayerCtrl;

  late String _book;
  late DateTime _startDate;
  late ReadingPlanMode _mode;
  late int _startChapter;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final plan = widget.plan;
    _book = plan?.book ?? 'Proverbs';
    _startDate = plan?.startDate ?? dateOnly(DateTime.now());
    _mode = plan?.mode ?? ReadingPlanMode.chapter;
    _startChapter = plan?.startChapter ?? 1;
    _titleCtrl = TextEditingController(text: plan?.title ?? '');
    _daysCtrl = TextEditingController(
      text: '${plan?.days ?? _defaultDays(_book, _startChapter)}',
    );
    _versesCtrl = TextEditingController(text: plan?.verses ?? '');
    _startVerseCtrl = TextEditingController(text: '${plan?.startVerse ?? 1}');
    _versesPerDayCtrl =
        TextEditingController(text: '${plan?.versesPerDay ?? 1}');
    _prayerCtrl = TextEditingController(text: plan?.prayer ?? '');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _daysCtrl.dispose();
    _versesCtrl.dispose();
    _startVerseCtrl.dispose();
    _versesPerDayCtrl.dispose();
    _prayerCtrl.dispose();
    super.dispose();
  }

  int get _chapterCount => kBibleBooks[_book] ?? 1;

  /// One chapter per day to the end of the book — the common case.
  int _defaultDays(String book, int startChapter) =>
      ((kBibleBooks[book] ?? 1) - startChapter + 1).clamp(1, 366);

  ReadingPlan get _draft => ReadingPlan(
        id: widget.plan?.id ?? '',
        title: _titleCtrl.text.trim(),
        book: _book,
        startDate: _startDate,
        days: (int.tryParse(_daysCtrl.text.trim()) ?? 1).clamp(1, 400),
        mode: _mode,
        startChapter: _startChapter,
        verses:
            _versesCtrl.text.trim().isEmpty ? null : _versesCtrl.text.trim(),
        startVerse: int.tryParse(_startVerseCtrl.text.trim()) ?? 1,
        versesPerDay: int.tryParse(_versesPerDayCtrl.text.trim()) ?? 1,
        prayer: _prayerCtrl.text.trim(),
      );

  /// Plans whose range already contains the new start date. Not an error — the
  /// later-starting plan wins for the overlap — but the admin should know.
  List<ReadingPlan> get _overlaps => widget.existing
      .where((plan) => plan.id != widget.plan?.id && plan.covers(_startDate))
      .toList();

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
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
    if (picked != null) setState(() => _startDate = dateOnly(picked));
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final plan = _draft;
    try {
      await widget.repo.savePlan(plan);
      widget.onSuccess(
        '${planLabel(plan)} saved — ${plan.days} days from '
        '${formatPlanDate(plan.startDate)}.',
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      widget.onError('Save failed: $e');
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final overlaps = _overlaps;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.md,
        bottom: AppSpacing.md + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.outlineVariant,
                    borderRadius: AppRadius.pillBorder,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                widget.plan == null ? 'New Reading Plan' : 'Edit Reading Plan',
                style: AppTypography.titleMd.copyWith(color: AppColors.heading),
              ),
              const SizedBox(height: 4),
              Text(
                'Set it once — every date in the range resolves on its own and '
                'members are notified each morning.',
                style:
                    AppTypography.bodySm.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSpacing.md),
              ..._identityFields(),
              ..._advanceFields(),
              _label('Length in days'),
              TextFormField(
                controller: _daysCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style:
                    AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
                decoration: _deco(hint: '31'),
                validator: (value) {
                  final parsed = int.tryParse((value ?? '').trim()) ?? 0;
                  if (parsed < 1) return 'At least 1 day';
                  if (parsed > 400) return 'At most 400 days';
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.sm),
              _label('Prayer shown each day (optional)'),
              TextFormField(
                controller: _prayerCtrl,
                maxLines: 3,
                style:
                    AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
                decoration: _deco(hint: 'Generated from the reading if blank'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.md),
              _DraftPreview(plan: _draft),
              if (overlaps.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Overlaps ${overlaps.map(planLabel).join(', ')}. This plan '
                  'starts later, so it wins for the overlapping dates; the '
                  'earlier plan resumes once this one ends.',
                  style: AppTypography.bodySm
                      .copyWith(color: AppColors.secondary),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: AppColors.onSecondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.cardBorder,
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.onSecondary,
                          ),
                        )
                      : Text(
                          widget.plan == null ? 'Create plan' : 'Save plan',
                          style: AppTypography.labelMd.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSecondary,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }

  /// Name, book and start date.
  List<Widget> _identityFields() => [
        _label('Name'),
        TextFormField(
          controller: _titleCtrl,
          style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
          decoration: _deco(hint: 'January – Proverbs'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.sm),
        _label('Book'),
        DropdownButtonFormField<String>(
          initialValue: _book,
          dropdownColor: AppColors.surfaceElevated,
          style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
          decoration: _deco(),
          items: kBibleBooks.entries
              .map((entry) => DropdownMenuItem(
                    value: entry.key,
                    child: Text('${entry.key} (${entry.value} ch)'),
                  ))
              .toList(),
          onChanged: (book) {
            if (book == null) return;
            setState(() {
              _book = book;
              _startChapter = 1;
              if (_mode == ReadingPlanMode.chapter) {
                _daysCtrl.text = '${_defaultDays(book, 1)}';
              }
            });
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        _label('Start date'),
        GestureDetector(
          onTap: _pickStartDate,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: AppRadius.inputBorder,
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today,
                    size: 18, color: AppColors.secondary),
                const SizedBox(width: 10),
                Text(
                  formatPlanDate(_startDate),
                  style: AppTypography.bodyLg
                      .copyWith(color: AppColors.onSurface),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
      ];

  /// Mode switch plus the fields that mode needs.
  List<Widget> _advanceFields() => [
        _label('Advances by'),
        SegmentedButton<ReadingPlanMode>(
          segments: const [
            ButtonSegment(
              value: ReadingPlanMode.chapter,
              label: Text('A chapter a day'),
            ),
            ButtonSegment(
              value: ReadingPlanMode.verse,
              label: Text('Verses a day'),
            ),
          ],
          selected: {_mode},
          showSelectedIcon: false,
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith((states) =>
                states.contains(WidgetState.selected)
                    ? AppColors.secondary
                    : AppColors.surfaceSubtle),
            foregroundColor: WidgetStateProperty.resolveWith((states) =>
                states.contains(WidgetState.selected)
                    ? AppColors.onSecondary
                    : AppColors.onSurfaceVariant),
          ),
          onSelectionChanged: (selection) =>
              setState(() => _mode = selection.first),
        ),
        const SizedBox(height: AppSpacing.sm),
        _label(_mode == ReadingPlanMode.chapter
            ? 'Starting chapter'
            : 'Chapter'),
        DropdownButtonFormField<int>(
          initialValue: _startChapter.clamp(1, _chapterCount),
          dropdownColor: AppColors.surfaceElevated,
          style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
          decoration: _deco(),
          items: List.generate(
            _chapterCount,
            (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}')),
          ),
          onChanged: (chapter) {
            if (chapter == null) return;
            setState(() {
              _startChapter = chapter;
              if (_mode == ReadingPlanMode.chapter) {
                _daysCtrl.text = '${_defaultDays(_book, chapter)}';
              }
            });
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_mode == ReadingPlanMode.chapter) ...[
          _label('Verse range each day (optional)'),
          TextFormField(
            controller: _versesCtrl,
            style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
            decoration: _deco(hint: 'Whole chapter'),
            onChanged: (_) => setState(() {}),
          ),
        ] else
          Row(
            children: [
              Expanded(
                child: _numberField(
                  label: 'First verse',
                  controller: _startVerseCtrl,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _numberField(
                  label: 'Verses per day',
                  controller: _versesPerDayCtrl,
                ),
              ),
            ],
          ),
        const SizedBox(height: AppSpacing.sm),
      ];

  Widget _numberField({
    required String label,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
          decoration: _deco(hint: '1'),
          validator: (value) {
            final parsed = int.tryParse((value ?? '').trim()) ?? 0;
            return parsed < 1 ? 'Must be 1 or more' : null;
          },
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: Text(
          text,
          style:
              AppTypography.labelMd.copyWith(color: AppColors.onSurfaceVariant),
        ),
      );

  InputDecoration _deco({String? hint}) => InputDecoration(
        hintText: hint,
        hintStyle: AppTypography.bodyLg.copyWith(color: AppColors.textFaint),
        filled: true,
        fillColor: AppColors.surfaceSubtle,
        border: OutlineInputBorder(
          borderRadius: AppRadius.inputBorder,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputBorder,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputBorder,
          borderSide: const BorderSide(color: AppColors.secondary, width: 1.5),
        ),
        errorStyle: AppTypography.labelMd.copyWith(color: AppColors.error),
      );
}

/// Live preview: day 1, day 2 (the "it must advance" case the product owner
/// called out) and the final day, plus what happens after the plan ends.
class _DraftPreview extends StatelessWidget {
  const _DraftPreview({required this.plan});

  final ReadingPlan plan;

  @override
  Widget build(BuildContext context) {
    final start = plan.startDate;
    final secondDay = DateTime(start.year, start.month, start.day + 1);
    final rows = <String>[
      'Day 1 · ${formatPlanDate(start)} — ${plan.readingForDay(0).reference}',
      if (plan.days > 1)
        'Day 2 · ${formatPlanDate(secondDay)} — '
            '${plan.readingForDay(1).reference}',
      if (plan.days > 2)
        'Day ${plan.days} · ${formatPlanDate(plan.endDate)} — '
            '${plan.lastReading.reference}',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Preview',
            style: AppTypography.labelMd.copyWith(
              color: AppColors.secondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                row,
                style: AppTypography.bodySm
                    .copyWith(color: AppColors.onSurfaceVariant),
              ),
            ),
          const SizedBox(height: 4),
          Text(
            'After ${formatPlanDate(plan.endDate)} members keep seeing '
            '${plan.lastReading.reference} until the next plan starts.',
            style: AppTypography.bodySm.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
