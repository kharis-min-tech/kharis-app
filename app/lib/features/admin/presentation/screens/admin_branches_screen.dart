import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/onboarding/data/branch_repository.dart';
import 'package:kharis_app/shared/providers/admin_provider.dart';
import 'package:go_router/go_router.dart';

// ── Main screen ───────────────────────────────────────────────────────────────

/// Admin screen: list + CRUD for [Branch].
class AdminBranchesScreen extends ConsumerWidget {
  const AdminBranchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchesAsync = ref.watch(branchesProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Branches',
          style: AppTypography.titleMd.copyWith(color: AppColors.heading),
        ),
        iconTheme: const IconThemeData(color: AppColors.heading),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.secondary,
        foregroundColor: AppColors.onSecondary,
        onPressed: () => _openForm(context, ref),
        child: const Icon(Icons.add),
      ),
      body: branchesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.secondary),
        ),
        error: (e, _) => Center(
          child: Text(
            'Could not load branches.',
            style: AppTypography.bodyLg.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
        data: (branches) {
          if (branches.isEmpty) {
            return Center(
              child: Text(
                'No branches yet.',
                style: AppTypography.bodyLg.copyWith(color: AppColors.textMuted),
              ),
            );
          }
          final sorted = [...branches]
            ..sort((a, b) => a.order.compareTo(b.order));
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.sm,
              AppSpacing.gutter,
              AppSpacing.lg + AppSpacing.lg,
            ),
            itemCount: sorted.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, i) => _BranchCard(
              branch: sorted[i],
              onEdit: () => _openForm(context, ref, branch: sorted[i]),
              onDelete: () => _confirmDelete(context, ref, sorted[i]),
              onTap: () => context.push(
                '/admin/branches/${sorted[i].id}',
                extra: sorted[i].name,
              ),
            ),
          );
        },
      ),
    );
  }

  void _openForm(BuildContext context, WidgetRef ref, {Branch? branch}) {
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(branchRepositoryProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BranchFormSheet(
        branch: branch,
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

  void _confirmDelete(BuildContext context, WidgetRef ref, Branch branch) {
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(branchRepositoryProvider);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: Text(
          'Delete branch?',
          style: AppTypography.titleMd.copyWith(color: AppColors.heading),
        ),
        content: Text(
          'This will permanently remove "${branch.name}". This cannot be undone.',
          style: AppTypography.bodySm.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
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
                await repo.deleteBranch(branch.id);
                messenger.showSnackBar(
                  const SnackBar(content: Text('Branch deleted.')),
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

// ── Branch card ───────────────────────────────────────────────────────────────

class _BranchCard extends StatelessWidget {
  const _BranchCard({
    required this.branch,
    required this.onEdit,
    required this.onDelete,
    required this.onTap,
  });

  final Branch branch;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: AppRadius.cardBorder,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Gradient swatch with optional landmark image on top
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: SizedBox(
                width: 64,
                height: 64,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: branch.gradient,
                        ),
                      ),
                    ),
                    if (branch.imageUrl != null)
                      Image.network(
                        branch.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    branch.name,
                    style: AppTypography.bodyLg.copyWith(
                      color: AppColors.heading,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    branch.subtitle,
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.textMuted,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (branch.address != null || branch.meetingDays != null || branch.meetingTime != null) ...[
                    const SizedBox(height: 2),
                    if (branch.address != null)
                      Text(
                        branch.address!,
                        style: AppTypography.labelMd.copyWith(
                          color: AppColors.textFaint,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (branch.meetingDays != null || branch.meetingTime != null)
                      Text(
                        [
                          if (branch.meetingDays != null) branch.meetingDays!,
                          if (branch.meetingTime != null) branch.meetingTime!,
                        ].join(', '),
                        style: AppTypography.labelMd.copyWith(
                          color: AppColors.textFaint,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                  const SizedBox(height: AppSpacing.xs),
                  // Gradient swatch pill
                  Row(
                    children: [
                      _ColorDot(color: branch.gradientStart),
                      const SizedBox(width: AppSpacing.xs),
                      _ColorDot(color: branch.gradientEnd),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Order: ${branch.order}',
                        style: AppTypography.labelMd.copyWith(
                          color: AppColors.textFaint,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.tune, size: 12, color: AppColors.textFaint),
                      const SizedBox(width: 2),
                      Text(
                        'Customize',
                        style: AppTypography.labelMd.copyWith(
                          color: AppColors.textFaint,
                        ),
                      ),
                    ],
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
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.outlineVariant, width: 1),
      ),
    );
  }
}

// ── Add / Edit form sheet ─────────────────────────────────────────────────────

class _BranchFormSheet extends StatefulWidget {
  const _BranchFormSheet({
    this.branch,
    required this.repo,
    required this.onSuccess,
    required this.onError,
  });

  final Branch? branch;
  final BranchRepository repo;
  final void Function(String) onSuccess;
  final void Function(String) onError;

  @override
  State<_BranchFormSheet> createState() => _BranchFormSheetState();
}

class _BranchFormSheetState extends State<_BranchFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _subtitleCtrl;
  late final TextEditingController _startHexCtrl;
  late final TextEditingController _endHexCtrl;
  late final TextEditingController _imageUrlCtrl;
  late final TextEditingController _orderCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _meetingDaysCtrl;
  late final TextEditingController _meetingTimeCtrl;

  Color _gradientStart = const Color(0xFF2E4368);
  Color _gradientEnd = const Color(0xFFC4794A);
  bool _saving = false;

  static final _hexRegex = RegExp(r'^#[0-9A-Fa-f]{6}$');

  @override
  void initState() {
    super.initState();
    final b = widget.branch;
    _nameCtrl = TextEditingController(text: b?.name ?? '');
    _subtitleCtrl = TextEditingController(text: b?.subtitle ?? '');

    final startHex = b != null ? Branch.toHex(b.gradientStart) : '#2E4368';
    final endHex = b != null ? Branch.toHex(b.gradientEnd) : '#C4794A';
    _startHexCtrl = TextEditingController(text: startHex);
    _endHexCtrl = TextEditingController(text: endHex);
    _gradientStart = Branch.parseHex(startHex, const Color(0xFF2E4368));
    _gradientEnd = Branch.parseHex(endHex, const Color(0xFFC4794A));

    _imageUrlCtrl = TextEditingController(text: b?.imageUrl ?? '');
    _orderCtrl = TextEditingController(
      text: (b?.order ?? 99).toString(),
    );
    _addressCtrl = TextEditingController(text: b?.address ?? '');
    _meetingDaysCtrl = TextEditingController(text: b?.meetingDays ?? '');
    _meetingTimeCtrl = TextEditingController(text: b?.meetingTime ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _subtitleCtrl.dispose();
    _startHexCtrl.dispose();
    _endHexCtrl.dispose();
    _imageUrlCtrl.dispose();
    _orderCtrl.dispose();
    _addressCtrl.dispose();
    _meetingDaysCtrl.dispose();
    _meetingTimeCtrl.dispose();
    super.dispose();
  }

  void _onStartHexChanged(String value) {
    final parsed = Branch.parseHex(value, _gradientStart);
    setState(() => _gradientStart = parsed);
  }

  void _onEndHexChanged(String value) {
    final parsed = Branch.parseHex(value, _gradientEnd);
    setState(() => _gradientEnd = parsed);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.branch != null;

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
                isEdit ? 'Edit Branch' : 'New Branch',
                style: AppTypography.titleMd.copyWith(color: AppColors.heading),
              ),
              const SizedBox(height: AppSpacing.md),

              // Name
              _label('Name'),
              const SizedBox(height: AppSpacing.xs),
              TextFormField(
                controller: _nameCtrl,
                style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
                decoration: _deco(hint: 'Branch name'),
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: AppSpacing.sm),

              // Subtitle
              _label('Subtitle'),
              const SizedBox(height: AppSpacing.xs),
              TextFormField(
                controller: _subtitleCtrl,
                style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
                decoration: _deco(hint: 'Short description'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.sm),

              // Gradient preview + hex fields
              _label('Gradient'),
              const SizedBox(height: AppSpacing.xs),

              // Live gradient preview swatch
              Container(
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [_gradientStart, _gradientEnd],
                  ),
                  borderRadius: AppRadius.inputBorder,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _startHexCtrl,
                      style: AppTypography.bodyLg.copyWith(
                        color: AppColors.onSurface,
                      ),
                      decoration: _deco(hint: '#2E4368').copyWith(
                        prefixText: 'Start: ',
                        prefixStyle: AppTypography.labelMd.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      textInputAction: TextInputAction.next,
                      onChanged: _onStartHexChanged,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        if (!_hexRegex.hasMatch(v.trim())) {
                          return 'Use #RRGGBB format';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextFormField(
                      controller: _endHexCtrl,
                      style: AppTypography.bodyLg.copyWith(
                        color: AppColors.onSurface,
                      ),
                      decoration: _deco(hint: '#C4794A').copyWith(
                        prefixText: 'End: ',
                        prefixStyle: AppTypography.labelMd.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      textInputAction: TextInputAction.next,
                      onChanged: _onEndHexChanged,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        if (!_hexRegex.hasMatch(v.trim())) {
                          return 'Use #RRGGBB format';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              // Image URL
              _label('Image URL (optional)'),
              const SizedBox(height: AppSpacing.xs),
              TextFormField(
                controller: _imageUrlCtrl,
                style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
                decoration: _deco(hint: 'https://...'),
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.sm),

              // Venue Address
              _label('Venue Address (optional)'),
              const SizedBox(height: AppSpacing.xs),
              TextFormField(
                controller: _addressCtrl,
                style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
                decoration: _deco(hint: 'e.g. 123 Church Street, London'),
                textInputAction: TextInputAction.next,
                maxLines: 2,
                minLines: 1,
              ),
              const SizedBox(height: AppSpacing.sm),

              // Meeting Days
              _label('Meeting Days (optional)'),
              const SizedBox(height: AppSpacing.xs),
              TextFormField(
                controller: _meetingDaysCtrl,
                style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
                decoration: _deco(hint: 'e.g. Sundays'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.sm),

              // Meeting Time
              _label('Meeting Time (optional)'),
              const SizedBox(height: AppSpacing.xs),
              TextFormField(
                controller: _meetingTimeCtrl,
                style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
                decoration: _deco(hint: 'e.g. 10:00 AM'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.sm),

              // Order
              _label('Order'),
              const SizedBox(height: AppSpacing.xs),
              TextFormField(
                controller: _orderCtrl,
                style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
                decoration: _deco(hint: '0, 1, 2...'),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (int.tryParse(v.trim()) == null) return 'Must be a number';
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),

              // Save
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
                          isEdit ? 'Save changes' : 'Add branch',
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
      final name = _nameCtrl.text.trim();
      final subtitle = _subtitleCtrl.text.trim();
      final startColor = Branch.parseHex(
        _startHexCtrl.text.trim(),
        const Color(0xFF2E4368),
      );
      final endColor = Branch.parseHex(
        _endHexCtrl.text.trim(),
        const Color(0xFFC4794A),
      );
      final imageUrl = _imageUrlCtrl.text.trim().isEmpty
          ? null
          : _imageUrlCtrl.text.trim();
      final order = int.parse(_orderCtrl.text.trim());
      final address = _addressCtrl.text.trim().isEmpty
          ? null
          : _addressCtrl.text.trim();
      final meetingDays = _meetingDaysCtrl.text.trim().isEmpty
          ? null
          : _meetingDaysCtrl.text.trim();
      final meetingTime = _meetingTimeCtrl.text.trim().isEmpty
          ? null
          : _meetingTimeCtrl.text.trim();

      if (widget.branch == null) {
        await widget.repo.addBranch(
          name: name,
          subtitle: subtitle,
          gradientStart: startColor,
          gradientEnd: endColor,
          imageUrl: imageUrl,
          order: order,
          address: address,
          meetingDays: meetingDays,
          meetingTime: meetingTime,
        );
        widget.onSuccess('Branch added.');
      } else {
        await widget.repo.updateBranch(
          widget.branch!.id,
          name: name,
          subtitle: subtitle,
          gradientStart: startColor,
          gradientEnd: endColor,
          imageUrl: imageUrl,
          order: order,
          address: address,
          meetingDays: meetingDays,
          meetingTime: meetingTime,
        );
        widget.onSuccess('Branch updated.');
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      widget.onError('Save failed: $e');
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _label(String text) => Text(
        text,
        style: AppTypography.labelMd.copyWith(
          color: AppColors.onSurfaceVariant,
        ),
      );

  InputDecoration _deco({String? hint}) => InputDecoration(
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
