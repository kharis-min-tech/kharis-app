import 'package:flutter/material.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/admin/presentation/widgets/studio_form_kit.dart';
import 'package:kharis_app/shared/models/campus_config.dart';

/// When a Home block shows at all, for blocks that depend on state.
String? homeSectionCondition(HomeSectionId id) => switch (id) {
  HomeSectionId.profileCompletion => 'Only while a profile is incomplete',
  HomeSectionId.live => 'Only while the church is live',
  HomeSectionId.continueListening => 'Only when there is a message to resume',
  _ => null,
};

/// Orders and toggles Home blocks: a campus's own `branches/{id}.home` or
/// the church-wide `config/home`. Shared by the branch page and App settings.
///
/// Starts from [initial], or from [inherited] (the layout that applies
/// meanwhile) when nothing is set here. [clearLabel] hands `null` to
/// [onSave], removing the stored layout. [onSave] reports its own failure
/// and then throws; the editor keeps the arrangement.
class HomeLayoutEditor extends StatefulWidget {
  const HomeLayoutEditor({
    super.key,
    required this.initial,
    required this.inherited,
    required this.inheritedHint,
    required this.clearLabel,
    required this.onSave,
  });

  /// The stored layout; null while none is set here.
  final HomeLayout? initial;

  /// What members get while [initial] is null.
  final HomeLayout inherited;

  /// e.g. 'Using the church-wide default.'
  final String inheritedHint;

  /// e.g. 'Use church-wide default'.
  final String clearLabel;

  final Future<void> Function(HomeLayout? home) onSave;

  @override
  State<HomeLayoutEditor> createState() => _HomeLayoutEditorState();
}

class _HomeLayoutEditorState extends State<HomeLayoutEditor> {
  late List<HomeSection> _sections;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _sections = _complete(widget.initial ?? widget.inherited);
  }

  /// Every block exactly once: round-tripping through [HomeLayout.fromJson]
  /// appends any the layout omits, disabled.
  static List<HomeSection> _complete(HomeLayout layout) => [
    ...(HomeLayout.fromJson(layout.toJson()) ?? HomeLayout.fallback).sections,
  ];

  void _move(int from, int to) {
    if (to < 0 || to >= _sections.length) return;
    setState(() => _sections.insert(to, _sections.removeAt(from)));
  }

  void _toggle(int i, bool enabled) => setState(
    () => _sections[i] = HomeSection(_sections[i].id, enabled: enabled),
  );

  Future<void> _save({required bool clear}) async {
    setState(() => _saving = true);
    try {
      await widget.onSave(clear ? null : HomeLayout(List.of(_sections)));
      if (clear && mounted) {
        setState(() => _sections = _complete(widget.inherited));
      }
    } catch (_) {
      // [HomeLayoutEditor.onSave] already told the admin.
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.initial == null
              ? widget.inheritedHint
              : 'Custom layout. Top to bottom is the order on Home.',
          style: AppTypography.bodySm.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (var i = 0; i < _sections.length; i++)
          _SectionRow(
            key: ValueKey('home-row-${_sections[i].id.id}'),
            section: _sections[i],
            isFirst: i == 0,
            isLast: i == _sections.length - 1,
            onUp: () => _move(i, i - 1),
            onDown: () => _move(i, i + 1),
            onToggle: (v) => _toggle(i, v),
          ),
        const SizedBox(height: AppSpacing.sm),
        StudioSaveButton(
          label: 'Save Home layout',
          saving: _saving,
          onPressed: () => _save(clear: false),
        ),
        if (widget.initial != null)
          Center(
            child: TextButton(
              onPressed: _saving ? null : () => _save(clear: true),
              child: Text(
                widget.clearLabel,
                style: AppTypography.labelMd.copyWith(
                  color: AppColors.secondary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({
    super.key,
    required this.section,
    required this.isFirst,
    required this.isLast,
    required this.onUp,
    required this.onDown,
    required this.onToggle,
  });

  final HomeSection section;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onUp;
  final VoidCallback onDown;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final label = section.id.label;
    final condition = homeSectionCondition(section.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Container(
        padding: const EdgeInsets.only(left: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.surfaceSubtle,
          borderRadius: AppRadius.inputBorder,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.bodyLg.copyWith(
                      color: section.enabled
                          ? AppColors.onSurface
                          : AppColors.textMuted,
                    ),
                  ),
                  if (condition != null)
                    Text(
                      condition,
                      style: AppTypography.labelMd.copyWith(
                        color: AppColors.textFaint,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_upward_rounded, size: 18),
              color: AppColors.onSurfaceVariant,
              tooltip: 'Move $label up',
              onPressed: isFirst ? null : onUp,
            ),
            IconButton(
              icon: const Icon(Icons.arrow_downward_rounded, size: 18),
              color: AppColors.onSurfaceVariant,
              tooltip: 'Move $label down',
              onPressed: isLast ? null : onDown,
            ),
            Switch(
              key: ValueKey('home-switch-${section.id.id}'),
              value: section.enabled,
              activeThumbColor: AppColors.secondary,
              onChanged: onToggle,
            ),
          ],
        ),
      ),
    );
  }
}
