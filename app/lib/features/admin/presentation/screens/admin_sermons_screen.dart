import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kharis_app/core/services/firebase_service.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/core/utils/sermon_categorizer.dart';
import 'package:kharis_app/features/messages/data/firestore_sermon_repository.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';
import 'package:kharis_app/shared/widgets/artwork_image.dart';

// ── Constants ──────────────────────────────────────────────────────────────────

const _sourceOptions = ['audio', 'youtube'];

// ── Main screen ───────────────────────────────────────────────────────────────

/// Admin screen: list + CRUD for Firestore-managed sermons.
///
/// Only sermons stored in the `sermons` Firestore collection are editable
/// here. The archive/API sermons are read-only (they arrive from the Kharis
/// sermon API automatically). Admins can add new sermon entries, edit
/// metadata, feature/unfeature, and delete.
class AdminSermonsScreen extends ConsumerWidget {
  const AdminSermonsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sermonsAsync = ref.watch(adminSermonsProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Sermons',
          style: AppTypography.titleMd.copyWith(color: AppColors.heading),
        ),
        iconTheme: const IconThemeData(color: AppColors.heading),
      ),
      // Firebase off ⇒ no writable backing store, so no create control at all
      // rather than a button that opens a form nothing can save.
      floatingActionButton: kUseFirebase
          ? FloatingActionButton(
              backgroundColor: AppColors.secondary,
              foregroundColor: AppColors.onSecondary,
              onPressed: () => _openForm(context, ref),
              child: const Icon(Icons.add),
            )
          : null,
      body: sermonsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.secondary),
        ),
        error: (e, _) => _EmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Could not load sermons',
          subtitle: 'Check your connection and try again.',
        ),
        data: (sermons) {
          if (sermons.isEmpty) {
            return _EmptyState(
              icon: kUseFirebase
                  ? Icons.mic_none_rounded
                  : Icons.cloud_off_rounded,
              title: kUseFirebase
                  ? 'No CMS sermons yet'
                  : 'Sermon CMS unavailable',
              subtitle: kUseFirebase
                  ? 'Tap + to add a sermon. RSS episodes appear automatically in the app.'
                  : 'Firebase is disabled in this build, so sermons cannot be managed here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.sm,
              AppSpacing.gutter,
              AppSpacing.lg + AppSpacing.lg,
            ),
            itemCount: sermons.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, index) => _SermonAdminCard(
              sermon: sermons[index],
              onEdit: () =>
                  _openForm(context, ref, sermon: sermons[index]),
              onDelete: () =>
                  _confirmDelete(context, ref, sermons[index]),
              onToggleFeature: () => _toggleFeature(context, ref, sermons[index]),
            ),
          );
        },
      ),
    );
  }

  void _openForm(BuildContext context, WidgetRef ref, {Sermon? sermon}) {
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(adminSermonRepositoryProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SermonFormSheet(
        sermon: sermon,
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

  void _confirmDelete(BuildContext context, WidgetRef ref, Sermon sermon) {
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: Text(
          'Delete sermon?',
          style: AppTypography.titleMd.copyWith(color: AppColors.heading),
        ),
        content: Text(
          'This will permanently remove "${sermon.title}" from the CMS. '
          'RSS/catalogue episodes are unaffected.',
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
                await ref
                    .read(adminSermonRepositoryProvider)
                    .deleteSermon(sermon.id);
                messenger.showSnackBar(const SnackBar(
                  content: Text('Sermon deleted.'),
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

  void _toggleFeature(BuildContext context, WidgetRef ref, Sermon sermon) {
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(adminSermonRepositoryProvider);
    () async {
      try {
        await repo.setFeatured(sermon.id, !sermon.isFeatured);
        messenger.showSnackBar(SnackBar(
          content: Text(sermon.isFeatured
              ? 'Removed from featured.'
              : 'Added to featured.'),
          backgroundColor: AppColors.surfaceElevated,
        ));
      } catch (e) {
        messenger.showSnackBar(SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: AppColors.errorContainer,
        ));
      }
    }();
  }
}

// ── List card ─────────────────────────────────────────────────────────────────

class _SermonAdminCard extends StatelessWidget {
  const _SermonAdminCard({
    required this.sermon,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleFeature,
  });

  final Sermon sermon;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleFeature;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: AppRadius.cardBorder,
        border: sermon.isFeatured
            ? Border.all(color: AppColors.secondary.withValues(alpha: 0.4))
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.defaultRadius),
              child: SizedBox(
                width: 56,
                height: 56,
                child: ArtworkImage(
                  url: sermon.artworkUrl,
                  gradientIndex: sermon.artworkColor ?? 0,
                  radius: AppRadius.defaultRadius,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (sermon.isFeatured)
                        const Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: AppColors.secondary,
                          ),
                        ),
                      Flexible(
                        child: Text(
                          sermon.title,
                          style: AppTypography.bodyLg.copyWith(
                            color: AppColors.heading,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        sermon.speaker,
                        style: AppTypography.labelMd
                            .copyWith(color: AppColors.textMuted),
                      ),
                      if (sermon.category != null) ...[
                        const SizedBox(width: 8),
                        _MiniChip(label: sermon.category!),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sermon.formattedDuration.isEmpty
                        ? _formatDate(sermon.publishedAt)
                        : '${sermon.formattedDuration} · ${_formatDate(sermon.publishedAt)}',
                    style: AppTypography.labelMd
                        .copyWith(color: AppColors.textFaint),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  icon: Icon(
                    sermon.isFeatured
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    size: 20,
                  ),
                  color: sermon.isFeatured
                      ? AppColors.secondary
                      : AppColors.onSurfaceVariant,
                  onPressed: onToggleFeature,
                  tooltip: sermon.isFeatured ? 'Unfeature' : 'Feature',
                ),
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

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'No date';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

// ── Mini chip ─────────────────────────────────────────────────────────────────

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: AppRadius.pillBorder,
      ),
      child: Text(
        label,
        style: AppTypography.labelMd.copyWith(
          fontSize: 10,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.textFaint),
            const SizedBox(height: AppSpacing.sm),
            Text(
              title,
              style: AppTypography.titleMd.copyWith(color: AppColors.heading),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle,
              style:
                  AppTypography.bodySm.copyWith(color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Add / Edit form sheet ─────────────────────────────────────────────────────

class _SermonFormSheet extends StatefulWidget {
  const _SermonFormSheet({
    this.sermon,
    required this.repo,
    required this.onSuccess,
    required this.onError,
  });

  final Sermon? sermon;
  final FirestoreSermonRepository repo;
  final void Function(String) onSuccess;
  final void Function(String) onError;

  @override
  State<_SermonFormSheet> createState() => _SermonFormSheetState();
}

class _SermonFormSheetState extends State<_SermonFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _speakerCtrl;
  late final TextEditingController _audioUrlCtrl;
  late final TextEditingController _artworkUrlCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _seriesCtrl;
  late final TextEditingController _videoIdCtrl;
  late final TextEditingController _durationCtrl;

  late String _category;
  late String _source;
  late bool _isFeatured;
  DateTime? _publishedAt;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.sermon;
    _titleCtrl = TextEditingController(text: s?.title ?? '');
    _speakerCtrl = TextEditingController(text: s?.speaker ?? 'David Antwi');
    _audioUrlCtrl = TextEditingController(text: s?.audioUrl ?? '');
    _artworkUrlCtrl = TextEditingController(text: s?.artworkUrl ?? '');
    _descriptionCtrl = TextEditingController(text: s?.description ?? '');
    _seriesCtrl = TextEditingController(text: s?.series ?? '');
    _videoIdCtrl = TextEditingController(text: s?.videoId ?? '');
    _durationCtrl = TextEditingController(
      text: s?.duration != null ? '${s!.duration!.inSeconds}' : '',
    );
    _category = s?.category ?? kSermonCategories.skip(1).first;
    _source = s?.source ?? _sourceOptions.first;
    _isFeatured = s?.isFeatured ?? false;
    _publishedAt = s?.publishedAt;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _speakerCtrl.dispose();
    _audioUrlCtrl.dispose();
    _artworkUrlCtrl.dispose();
    _descriptionCtrl.dispose();
    _seriesCtrl.dispose();
    _videoIdCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.sermon != null;
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
                isEdit ? 'Edit Sermon' : 'New Sermon',
                style: AppTypography.titleMd.copyWith(color: AppColors.heading),
              ),
              const SizedBox(height: AppSpacing.md),

              _inputLabel('Title'),
              const SizedBox(height: AppSpacing.xs),
              TextFormField(
                controller: _titleCtrl,
                style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
                decoration: _inputDeco(hint: 'Sermon title'),
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Title is required' : null,
              ),
              const SizedBox(height: AppSpacing.sm),

              _inputLabel('Speaker'),
              const SizedBox(height: AppSpacing.xs),
              TextFormField(
                controller: _speakerCtrl,
                style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
                decoration: _inputDeco(hint: 'e.g. David Antwi'),
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Speaker is required' : null,
              ),
              const SizedBox(height: AppSpacing.sm),

              _inputLabel('Category'),
              const SizedBox(height: AppSpacing.xs),
              DropdownButtonFormField<String>(
                initialValue: _category,
                dropdownColor: AppColors.surfaceContainer,
                style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
                decoration: _inputDeco(),
                items: kSermonCategories
                    .where((c) => c != 'All')
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _category = v);
                },
              ),
              const SizedBox(height: AppSpacing.sm),

              _inputLabel('Source'),
              const SizedBox(height: AppSpacing.xs),
              DropdownButtonFormField<String>(
                initialValue: _source,
                dropdownColor: AppColors.surfaceContainer,
                style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
                decoration: _inputDeco(),
                items: _sourceOptions
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _source = v);
                },
              ),
              const SizedBox(height: AppSpacing.sm),

              _inputLabel('Audio URL'),
              const SizedBox(height: AppSpacing.xs),
              TextFormField(
                controller: _audioUrlCtrl,
                style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
                decoration: _inputDeco(hint: 'https://...mp3'),
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.sm),

              _inputLabel('YouTube Video ID (optional)'),
              const SizedBox(height: AppSpacing.xs),
              TextFormField(
                controller: _videoIdCtrl,
                style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
                decoration: _inputDeco(hint: 'e.g. dQw4w9WgXcQ'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.sm),

              _inputLabel('Artwork URL (optional)'),
              const SizedBox(height: AppSpacing.xs),
              TextFormField(
                controller: _artworkUrlCtrl,
                style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
                decoration: _inputDeco(hint: 'https://...jpg'),
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.sm),

              _inputLabel('Duration in seconds (optional)'),
              const SizedBox(height: AppSpacing.xs),
              TextFormField(
                controller: _durationCtrl,
                style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
                decoration: _inputDeco(hint: 'e.g. 3600'),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.sm),

              _inputLabel('Series (optional)'),
              const SizedBox(height: AppSpacing.xs),
              TextFormField(
                controller: _seriesCtrl,
                style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
                decoration: _inputDeco(hint: 'e.g. Acts Series'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.sm),

              // Publish date
              _inputLabel('Publish Date'),
              const SizedBox(height: AppSpacing.xs),
              GestureDetector(
                onTap: _pickDate,
                child: AbsorbPointer(
                  child: TextFormField(
                    style:
                        AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
                    decoration: _inputDeco(
                      hint: _publishedAt != null
                          ? _formatDate(_publishedAt!)
                          : 'Select date',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              _inputLabel('Description (optional)'),
              const SizedBox(height: AppSpacing.xs),
              TextFormField(
                controller: _descriptionCtrl,
                style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
                decoration: _inputDeco(hint: 'Sermon description / notes'),
                maxLines: 3,
                textInputAction: TextInputAction.newline,
              ),
              const SizedBox(height: AppSpacing.sm),

              // Featured toggle
              SwitchListTile(
                title: Text(
                  'Featured on Messages',
                  style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
                ),
                subtitle: Text(
                  'Featured sermons appear in the Messages hero carousel.',
                  style: AppTypography.bodySm
                      .copyWith(color: AppColors.textMuted),
                ),
                value: _isFeatured,
                onChanged: (v) => setState(() => _isFeatured = v),
                activeThumbColor: AppColors.secondary,
              ),
              const SizedBox(height: AppSpacing.md),

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
                          isEdit ? 'Save changes' : 'Add sermon',
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _publishedAt ?? DateTime.now(),
      firstDate: DateTime(2010),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.secondary,
            onPrimary: AppColors.onSecondary,
            surface: AppColors.surfaceDark,
            onSurface: AppColors.onSurface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _publishedAt = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = widget.repo;

      final title = _titleCtrl.text.trim();
      final speaker = _speakerCtrl.text.trim();
      final audioUrl = _audioUrlCtrl.text.trim();
      final artworkUrl = _artworkUrlCtrl.text.trim().isEmpty
          ? null
          : _artworkUrlCtrl.text.trim();
      final description = _descriptionCtrl.text.trim().isEmpty
          ? null
          : _descriptionCtrl.text.trim();
      final series =
          _seriesCtrl.text.trim().isEmpty ? null : _seriesCtrl.text.trim();
      final videoId =
          _videoIdCtrl.text.trim().isEmpty ? null : _videoIdCtrl.text.trim();
      final durationSeconds = int.tryParse(_durationCtrl.text.trim());

      if (widget.sermon == null) {
        await repo.addSermon(
          title: title,
          speaker: speaker,
          audioUrl: audioUrl,
          artworkUrl: artworkUrl,
          durationSeconds: durationSeconds,
          publishedAt: _publishedAt,
          series: series,
          description: description,
          category: _category,
          videoId: videoId,
          source: _source,
          isFeatured: _isFeatured,
        );
        widget.onSuccess('Sermon added.');
      } else {
        await repo.updateSermon(
          widget.sermon!.id,
          title: title,
          speaker: speaker,
          audioUrl: audioUrl,
          artworkUrl: artworkUrl,
          durationSeconds: durationSeconds,
          publishedAt: _publishedAt,
          series: series,
          description: description,
          category: _category,
          videoId: videoId,
          source: _source,
          isFeatured: _isFeatured,
        );
        widget.onSuccess('Sermon updated.');
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      widget.onError('Save failed: $e');
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _inputLabel(String text) => Text(
        text,
        style: AppTypography.labelMd.copyWith(color: AppColors.onSurfaceVariant),
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
          borderSide: const BorderSide(color: AppColors.secondary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputBorder,
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputBorder,
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        errorStyle: AppTypography.labelMd.copyWith(color: AppColors.error),
      );
}

String _formatDate(DateTime dt) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
}
