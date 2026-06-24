import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// Admin screen: list + CRUD for daily [DailyContent] (Bible readings).
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
            onPressed: () => _openSeriesForm(context, ref),
            icon: const Icon(Icons.date_range, size: 18, color: AppColors.secondary),
            label: Text(
              'Series',
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
              child: Text(
                'No readings configured yet.',
                style: AppTypography.bodyLg.copyWith(
                  color: AppColors.textMuted,
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

  void _openSeriesForm(BuildContext context, WidgetRef ref) {
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(dailyContentRepositoryProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SeriesFormSheet(
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

// ── Bible books with chapter counts ──────────────────────────────────────────

const _bibleBooks = <String, int>{
  'Genesis': 50, 'Exodus': 40, 'Leviticus': 27, 'Numbers': 36,
  'Deuteronomy': 34, 'Joshua': 24, 'Judges': 21, 'Ruth': 4,
  '1 Samuel': 31, '2 Samuel': 24, '1 Kings': 22, '2 Kings': 25,
  '1 Chronicles': 29, '2 Chronicles': 36, 'Ezra': 10, 'Nehemiah': 13,
  'Esther': 10, 'Job': 42, 'Psalms': 150, 'Proverbs': 31,
  'Ecclesiastes': 12, 'Song of Solomon': 8, 'Isaiah': 66, 'Jeremiah': 52,
  'Lamentations': 5, 'Ezekiel': 48, 'Daniel': 12, 'Hosea': 14,
  'Joel': 3, 'Amos': 9, 'Obadiah': 1, 'Jonah': 4,
  'Micah': 7, 'Nahum': 3, 'Habakkuk': 3, 'Zephaniah': 3,
  'Haggai': 2, 'Zechariah': 14, 'Malachi': 4,
  'Matthew': 28, 'Mark': 16, 'Luke': 24, 'John': 21,
  'Acts': 28, 'Romans': 16, '1 Corinthians': 16, '2 Corinthians': 13,
  'Galatians': 6, 'Ephesians': 6, 'Philippians': 4, 'Colossians': 4,
  '1 Thessalonians': 5, '2 Thessalonians': 3, '1 Timothy': 6, '2 Timothy': 4,
  'Titus': 3, 'Philemon': 1, 'Hebrews': 13, 'James': 5,
  '1 Peter': 5, '2 Peter': 3, '1 John': 5, '2 John': 1,
  '3 John': 1, 'Jude': 1, 'Revelation': 22,
};

// ── Generate Series form sheet ───────────────────────────────────────────────

class _SeriesFormSheet extends StatefulWidget {
  const _SeriesFormSheet({
    required this.repo,
    required this.onSuccess,
    required this.onError,
  });

  final DailyContentRepository repo;
  final void Function(String) onSuccess;
  final void Function(String) onError;

  @override
  State<_SeriesFormSheet> createState() => _SeriesFormSheetState();
}

class _SeriesFormSheetState extends State<_SeriesFormSheet> {
  String? _selectedBook;
  int _startChapter = 1;
  int _endChapter = 1;
  DateTime _startDate = DateTime.now();
  bool _saving = false;

  int get _totalChapters => _bibleBooks[_selectedBook] ?? 1;
  int get _dayCount => (_endChapter - _startChapter + 1).clamp(1, 366);
  DateTime get _endDate => _startDate.add(Duration(days: _dayCount - 1));

  String _fmtDate(DateTime dt) {
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${m[dt.month - 1]} ${dt.day}, ${dt.year}';
  }


  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
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
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _generate() async {
    if (_selectedBook == null) return;
    setState(() => _saving = true);
    try {
      final count = await widget.repo.batchSetContent(
        book: _selectedBook!,
        startChapter: _startChapter,
        startDate: _startDate,
        days: _dayCount,
      );
      widget.onSuccess('Created $count readings: $_selectedBook $_startChapter-$_endChapter');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      widget.onError('Failed: $e');
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.md, right: AppSpacing.md,
        top: AppSpacing.md,
        bottom: AppSpacing.md + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant,
                  borderRadius: AppRadius.pillBorder,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Generate Reading Series',
              style: AppTypography.titleMd.copyWith(color: AppColors.heading),
            ),
            const SizedBox(height: 4),
            Text(
              'One chapter per day, auto-assigned to dates',
              style: AppTypography.bodySm.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Book dropdown ──────────────────────────────────────────────
            Text('Book', style: AppTypography.labelMd.copyWith(color: AppColors.onSurfaceVariant)),
            const SizedBox(height: AppSpacing.xs),
            DropdownButtonFormField<String>(
              initialValue: _selectedBook,
              dropdownColor: AppColors.surfaceElevated,
              style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
              decoration: InputDecoration(
                hintText: 'Select a book',
                hintStyle: AppTypography.bodyLg.copyWith(color: AppColors.textFaint),
                filled: true,
                fillColor: AppColors.surfaceSubtle,
                border: OutlineInputBorder(
                  borderRadius: AppRadius.inputBorder,
                  borderSide: BorderSide.none,
                ),
              ),
              items: _bibleBooks.keys.map((book) => DropdownMenuItem(
                value: book,
                child: Text('$book (${_bibleBooks[book]} ch)'),
              )).toList(),
              onChanged: (book) {
                if (book == null) return;
                setState(() {
                  _selectedBook = book;
                  _startChapter = 1;
                  _endChapter = _bibleBooks[book]!;
                });
              },
            ),
            const SizedBox(height: AppSpacing.sm),

            // ── Chapter range ──────────────────────────────────────────────
            if (_selectedBook != null) ...[
              Text('Chapter Range', style: AppTypography.labelMd.copyWith(color: AppColors.onSurfaceVariant)),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _startChapter,
                      dropdownColor: AppColors.surfaceElevated,
                      style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
                      decoration: InputDecoration(
                        labelText: 'From',
                        labelStyle: AppTypography.labelMd.copyWith(color: AppColors.textMuted),
                        filled: true, fillColor: AppColors.surfaceSubtle,
                        border: OutlineInputBorder(borderRadius: AppRadius.inputBorder, borderSide: BorderSide.none),
                      ),
                      items: List.generate(_totalChapters, (i) => DropdownMenuItem(
                        value: i + 1,
                        child: Text('${i + 1}'),
                      )),
                      onChanged: (v) => setState(() {
                        _startChapter = v ?? 1;
                        if (_endChapter < _startChapter) _endChapter = _startChapter;
                      }),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('to', style: AppTypography.bodyLg.copyWith(color: AppColors.textMuted)),
                  ),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _endChapter,
                      dropdownColor: AppColors.surfaceElevated,
                      style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
                      decoration: InputDecoration(
                        labelText: 'To',
                        labelStyle: AppTypography.labelMd.copyWith(color: AppColors.textMuted),
                        filled: true, fillColor: AppColors.surfaceSubtle,
                        border: OutlineInputBorder(borderRadius: AppRadius.inputBorder, borderSide: BorderSide.none),
                      ),
                      items: List.generate(
                        _totalChapters - _startChapter + 1,
                        (i) => DropdownMenuItem(
                          value: _startChapter + i,
                          child: Text('${_startChapter + i}'),
                        ),
                      ),
                      onChanged: (v) => setState(() => _endChapter = v ?? _startChapter),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              // ── Start date ─────────────────────────────────────────────
              Text('Start Date', style: AppTypography.labelMd.copyWith(color: AppColors.onSurfaceVariant)),
              const SizedBox(height: AppSpacing.xs),
              GestureDetector(
                onTap: _pickStartDate,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSubtle,
                    borderRadius: AppRadius.inputBorder,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 18, color: AppColors.secondary),
                      const SizedBox(width: 10),
                      Text(
                        _fmtDate(_startDate),
                        style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // ── Preview ────────────────────────────────────────────────
              Container(
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
                    Text(
                      '$_selectedBook $_startChapter - $_endChapter',
                      style: AppTypography.bodyLg.copyWith(
                        color: AppColors.heading,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '$_dayCount days: ${_fmtDate(_startDate)} to ${_fmtDate(_endDate)}',
                      style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Day 1: $_selectedBook $_startChapter  ...  Day $_dayCount: $_selectedBook $_endChapter',
                      style: AppTypography.bodySm.copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // ── Generate button ────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _generate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: AppColors.onSecondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.cardBorder,
                    ),
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onSecondary),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: Text(
                    _saving ? 'Generating...' : 'Generate $_dayCount Readings',
                    style: AppTypography.labelMd.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSecondary,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}
