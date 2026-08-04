import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/home/data/daily_content_repository.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final _recentReadingsProvider =
    StreamProvider<List<MapEntry<String, DailyContent>>>((ref) {
  return ref
      .watch(dailyContentRepositoryProvider)
      .watchRecentContent(limit: 30);
});

// ── Main screen ───────────────────────────────────────────────────────────────

/// Admin screen: list + CRUD for one-off daily [DailyContent] documents.
///
/// A document here overrides the reading plan for its date, so this screen is
/// for special-casing a single day. Whole ranges are scheduled on the Reading
/// Plans screen, which advances a chapter a day on its own.
class AdminBibleReadingScreen extends ConsumerWidget {
  const AdminBibleReadingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readingsAsync = ref.watch(_recentReadingsProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Bible Reading',
          style: AppTypography.titleMd.copyWith(color: AppColors.heading),
        ),
        iconTheme: const IconThemeData(color: AppColors.heading),
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/admin/reading-plans'),
            icon: const Icon(Icons.auto_stories_rounded,
                size: 18, color: AppColors.secondary),
            label: Text(
              'Plans',
              style: AppTypography.labelMd.copyWith(color: AppColors.secondary),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.secondary,
        foregroundColor: AppColors.onSecondary,
        onPressed: () => _openForm(context, ref),
        child: const Icon(Icons.add),
      ),
      body: readingsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.secondary),
        ),
        error: (e, _) => Center(
          child: Text(
            'Could not load readings.',
            style: AppTypography.bodyLg.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
        data: (entries) {
          if (entries.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.gutter),
                child: Text(
                  'No one-off days saved. Day-to-day readings come from Plans; '
                  'add a day here only to override a single date.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyLg.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.sm,
              AppSpacing.gutter,
              AppSpacing.lg + AppSpacing.lg,
            ),
            itemCount: entries.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, index) {
              final entry = entries[index];
              return _ReadingCard(
                dateKey: entry.key,
                content: entry.value,
                onEdit: () => _openForm(context, ref,
                    dateKey: entry.key, content: entry.value),
                onDelete: () => _confirmDelete(context, ref, entry.key),
              );
            },
          );
        },
      ),
    );
  }

  void _openForm(
    BuildContext context,
    WidgetRef ref, {
    String? dateKey,
    DailyContent? content,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(dailyContentRepositoryProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReadingFormSheet(
        dateKey: dateKey,
        content: content,
        repo: repo,
        onSuccess: (msg) => messenger.showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppColors.surfaceElevated,
          ),
        ),
        onError: (msg) => messenger.showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppColors.errorContainer,
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String dateKey) {
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(dailyContentRepositoryProvider);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: Text(
          'Delete reading?',
          style: AppTypography.titleMd.copyWith(color: AppColors.heading),
        ),
        content: Text(
          'This will permanently remove the reading for "$dateKey". This cannot be undone.',
          style: AppTypography.bodySm
              .copyWith(color: AppColors.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await repo.deleteContent(dateKey);
                messenger.showSnackBar(const SnackBar(
                  content: Text('Reading deleted.'),
                ));
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

// ── List card ─────────────────────────────────────────────────────────────────

class _ReadingCard extends StatelessWidget {
  const _ReadingCard({
    required this.dateKey,
    required this.content,
    required this.onEdit,
    required this.onDelete,
  });

  final String dateKey;
  final DailyContent content;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final prayer = content.prayer;
    final snippet = prayer.length > 80 ? '${prayer.substring(0, 80)}...' : prayer;

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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.15),
                          borderRadius: AppRadius.pillBorder,
                        ),
                        child: Text(
                          dateKey,
                          style: AppTypography.labelMd
                              .copyWith(color: AppColors.secondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    content.reading.reference,
                    style: AppTypography.bodyLg.copyWith(
                      color: AppColors.heading,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (snippet.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      snippet,
                      style: AppTypography.bodySm
                          .copyWith(color: AppColors.textMuted),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (content.prayerReference.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      content.prayerReference,
                      style: AppTypography.labelMd
                          .copyWith(color: AppColors.onSurfaceVariant),
                    ),
                  ],
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

// ── Add / Edit form sheet ─────────────────────────────────────────────────────

class _ReadingFormSheet extends StatefulWidget {
  const _ReadingFormSheet({
    this.dateKey,
    this.content,
    required this.repo,
    required this.onSuccess,
    required this.onError,
  });

  final String? dateKey;
  final DailyContent? content;
  final DailyContentRepository repo;
  final void Function(String) onSuccess;
  final void Function(String) onError;

  @override
  State<_ReadingFormSheet> createState() => _ReadingFormSheetState();
}

class _ReadingFormSheetState extends State<_ReadingFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late DateTime _selectedDate;
  late final TextEditingController _bookCtrl;
  late final TextEditingController _chapterCtrl;
  late final TextEditingController _verseCtrl;
  late final TextEditingController _prayerCtrl;
  late final TextEditingController _prayerRefCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Parse existing date key or default to today.
    _selectedDate = _parseDate(widget.dateKey) ?? DateTime.now();

    final reading = widget.content?.reading;
    _bookCtrl = TextEditingController(text: reading?.book ?? '');
    _chapterCtrl =
        TextEditingController(text: reading != null ? '${reading.chapter}' : '');
    _verseCtrl = TextEditingController(text: reading?.verse ?? '');
    _prayerCtrl = TextEditingController(text: widget.content?.prayer ?? '');
    _prayerRefCtrl =
        TextEditingController(text: widget.content?.prayerReference ?? '');
  }

  @override
  void dispose() {
    _bookCtrl.dispose();
    _chapterCtrl.dispose();
    _verseCtrl.dispose();
    _prayerCtrl.dispose();
    _prayerRefCtrl.dispose();
    super.dispose();
  }

  DateTime? _parseDate(String? key) {
    if (key == null) return null;
    final parts = key.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  String _formatDateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  String _formatDisplayDate(DateTime dt) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
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
    if (picked != null) setState(() => _selectedDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.content != null;
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
                isEdit ? 'Edit Reading' : 'New Reading',
                style:
                    AppTypography.titleMd.copyWith(color: AppColors.heading),
              ),
              const SizedBox(height: AppSpacing.md),

              // Date picker
              _inputLabel('Date'),
              const SizedBox(height: AppSpacing.xs),
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSubtle,
                    borderRadius: AppRadius.inputBorder,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _formatDisplayDate(_selectedDate),
                          style: AppTypography.bodyLg
                              .copyWith(color: AppColors.onSurface),
                        ),
                      ),
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 18,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Book
              _inputLabel('Book'),
              const SizedBox(height: AppSpacing.xs),
              TextFormField(
                controller: _bookCtrl,
                style: AppTypography.bodyLg
                    .copyWith(color: AppColors.onSurface),
                decoration: _inputDeco(hint: 'e.g. Psalms'),
                textInputAction: TextInputAction.next,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Book is required'
                    : null,
              ),
              const SizedBox(height: AppSpacing.sm),

              // Chapter
              _inputLabel('Chapter'),
              const SizedBox(height: AppSpacing.xs),
              TextFormField(
                controller: _chapterCtrl,
                style: AppTypography.bodyLg
                    .copyWith(color: AppColors.onSurface),
                decoration: _inputDeco(hint: 'e.g. 23'),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Chapter is required';
                  if (int.tryParse(v.trim()) == null) return 'Must be a number';
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.sm),

              // Verse
              _inputLabel('Verse'),
              const SizedBox(height: AppSpacing.xs),
              TextFormField(
                controller: _verseCtrl,
                style: AppTypography.bodyLg
                    .copyWith(color: AppColors.onSurface),
                decoration: _inputDeco(hint: 'e.g. 1-6'),
                textInputAction: TextInputAction.next,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Verse is required'
                    : null,
              ),
              const SizedBox(height: AppSpacing.sm),

              // Prayer
              _inputLabel('Prayer'),
              const SizedBox(height: AppSpacing.xs),
              TextFormField(
                controller: _prayerCtrl,
                style: AppTypography.bodyLg
                    .copyWith(color: AppColors.onSurface),
                decoration: _inputDeco(hint: 'Enter the prayer text'),
                maxLines: 4,
                textInputAction: TextInputAction.next,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Prayer is required'
                    : null,
              ),
              const SizedBox(height: AppSpacing.sm),

              // Prayer Reference
              _inputLabel('Prayer Reference'),
              const SizedBox(height: AppSpacing.xs),
              TextFormField(
                controller: _prayerRefCtrl,
                style: AppTypography.bodyLg
                    .copyWith(color: AppColors.onSurface),
                decoration: _inputDeco(hint: 'e.g. Psalm 23:1'),
                textInputAction: TextInputAction.done,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Prayer reference is required'
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _saving ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: AppColors.onSecondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.buttonBorder,
                    ),
                  ),
                  child: _saving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.onSecondary,
                          ),
                        )
                      : Text(
                          isEdit ? 'Save changes' : 'Add reading',
                          style: AppTypography.bodyLg.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSecondary,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final dateKey = _formatDateKey(_selectedDate);
      final content = DailyContent(
        reading: BibleReading(
          book: _bookCtrl.text.trim(),
          chapter: int.parse(_chapterCtrl.text.trim()),
          verse: _verseCtrl.text.trim(),
        ),
        prayer: _prayerCtrl.text.trim(),
        prayerReference: _prayerRefCtrl.text.trim(),
      );

      await widget.repo.setContent(dateKey, content);
      widget.onSuccess(widget.content != null ? 'Reading updated.' : 'Reading added.');

      if (mounted) Navigator.pop(context);
    } catch (e) {
      widget.onError('Save failed: $e');
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _inputLabel(String text) => Text(
        text,
        style: AppTypography.labelMd
            .copyWith(color: AppColors.onSurfaceVariant),
      );

  InputDecoration _inputDeco({String? hint}) => InputDecoration(
        hintText: hint,
        hintStyle: AppTypography.bodyLg.copyWith(color: AppColors.textFaint),
        filled: true,
        fillColor: AppColors.surfaceSubtle,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
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
          borderSide:
              const BorderSide(color: AppColors.secondary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputBorder,
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputBorder,
          borderSide:
              const BorderSide(color: AppColors.error, width: 1.5),
        ),
        errorStyle:
            AppTypography.labelMd.copyWith(color: AppColors.error),
      );
}
