import 'package:flutter/material.dart';

import '../../theme/kharis_theme.dart';
import 'k_icon.dart';

/// How the Bible reader lays a chapter out.
enum KReaderLayout {
  /// Each verse on its own line.
  verses,

  /// Verses run together in the translation's paragraphs.
  paragraphs,
}

/// The Bible reader's toolbar, three controls in one row:
///
/// * the chapter stepper: Previous, the passage button ("John 1" with a
///   chevron, which opens the passage picker) and Next. With no [passage]
///   (nothing to read) it is left out; Previous or Next with no callback is
///   drawn dimmed and announced as disabled (the start or end of the Bible),
///   and with neither the arrows are left out;
/// * the translation button ("NIV" with a chevron), which opens the
///   translation switcher;
/// * Study tools, which opens search, highlights, notes, the layout and the
///   text size.
///
/// The controls are 38 tall inside a 44 hit area, and grow with the text.
/// The passage and the translation shorten with an ellipsis before anything
/// overflows.
class KReaderToolbar extends StatelessWidget {
  const KReaderToolbar({
    super.key,
    required this.passage,
    required this.version,
    required this.onPassage,
    required this.onVersion,
    required this.onStudy,
    this.previousLabel,
    this.nextLabel,
    this.onPrevious,
    this.onNext,
  });

  /// The open chapter, for example "John 1"; null hides the stepper.
  final String? passage;

  /// The translation's abbreviation, for example "NIV".
  final String version;
  final VoidCallback? onPassage;
  final VoidCallback? onVersion;
  final VoidCallback? onStudy;

  /// The chapters either side, for screen readers ("John 2").
  final String? previousLabel;
  final String? nextLabel;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  /// How far the 38 visible controls sit inside their 44 hit area.
  static const double _hitPad = (KSize.touchMin - KSize.toolbar) / 2;

  /// The most of the row the translation button takes before it shortens.
  static const double _versionShare = 0.3;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final passage = this.passage;
    final steps = onPrevious != null || onNext != null;
    final label = KharisText.itemTitle.copyWith(color: k.text);

    final translation = _Group(
      children: [
        Flexible(
          child: _Hit(
            key: const Key('bible-translation'),
            label: 'Translation, $version. Change translation',
            tooltip: 'Change translation',
            onTap: onVersion,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(
                start: KSpace.lg,
                end: KSpace.md,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      version,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: label.copyWith(color: k.primaryText),
                    ),
                  ),
                  const SizedBox(width: KSpace.xs),
                  KIcon(KIcons.chevronDown, size: KSize.iconSm, color: k.text),
                ],
              ),
            ),
          ),
        ),
      ],
    );

    final study = _Group(
      children: [
        _Hit(
          key: const Key('bible-study'),
          label: 'Study tools',
          tooltip: 'Study tools',
          onTap: onStudy,
          child: const KIcon(KIcons.more, size: KSize.iconSm),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) => Row(
        children: [
          Expanded(
            child: passage == null
                ? const SizedBox.shrink()
                : Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: _Group(
                      children: [
                        if (steps) ...[
                          _Step(
                            key: const Key('bible-toolbar-prev'),
                            icon: KIcons.chevronLeft,
                            label: previousLabel == null
                                ? 'Previous chapter'
                                : 'Previous chapter, $previousLabel',
                            onTap: onPrevious,
                          ),
                          const _Divider(),
                        ],
                        Flexible(
                          child: _Hit(
                            key: const Key('bible-reference'),
                            label: '$passage. Choose a book and chapter',
                            onTap: onPassage,
                            child: Padding(
                              padding: const EdgeInsetsDirectional.only(
                                start: KSpace.lg,
                                end: KSpace.md,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      passage,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: label,
                                    ),
                                  ),
                                  const SizedBox(width: KSpace.xs),
                                  KIcon(
                                    KIcons.chevronDown,
                                    size: KSize.iconSm,
                                    color: k.text,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (steps) ...[
                          const _Divider(),
                          _Step(
                            key: const Key('bible-toolbar-next'),
                            icon: KIcons.chevronRight,
                            label: nextLabel == null
                                ? 'Next chapter'
                                : 'Next chapter, $nextLabel',
                            onTap: onNext,
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
          const SizedBox(width: KSpace.md),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: constraints.maxWidth * _versionShare,
            ),
            child: translation,
          ),
          const SizedBox(width: KSpace.md),
          study,
        ],
      ),
    );
  }
}

/// Controls sharing one surface box with the card border and chip corners.
/// The box is drawn 38 tall behind children that are each 44 to the touch.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return Stack(
      children: [
        Positioned.fill(
          top: KReaderToolbar._hitPad,
          bottom: KReaderToolbar._hitPad,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: k.surface,
              borderRadius: const BorderRadius.all(
                Radius.circular(KRadius.chip),
              ),
              border: Border.all(color: k.border),
            ),
          ),
        ),
        Row(mainAxisSize: MainAxisSize.min, children: children),
      ],
    );
  }
}

/// The hairline between controls in one group.
class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: context.k.line),
      child: const SizedBox(width: 1, height: KSize.iconMd),
    );
  }
}

/// One control: a 44 hit area, read as a button, with an optional tooltip
/// for an icon on its own.
class _Hit extends StatelessWidget {
  const _Hit({
    super.key,
    required this.label,
    required this.onTap,
    required this.child,
    this.tooltip,
  });

  final String label;
  final VoidCallback? onTap;
  final Widget child;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final hit = Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: KSize.touchMin,
            minHeight: KSize.touchMin,
          ),
          child: Center(widthFactor: 1, heightFactor: 1, child: child),
        ),
      ),
    );
    final tooltip = this.tooltip;
    if (tooltip == null) return hit;
    return Tooltip(message: tooltip, excludeFromSemantics: true, child: hit);
  }
}

/// Previous or Next chapter: a chevron, dimmed when there is no chapter
/// that way.
class _Step extends StatelessWidget {
  const _Step({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final String icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _Hit(
      label: label,
      tooltip: label,
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? KRatio.disabled : 1,
        child: KIcon(icon, size: KSize.iconSm, color: context.k.text),
      ),
    );
  }
}
