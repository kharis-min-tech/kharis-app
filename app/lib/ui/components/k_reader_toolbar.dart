import 'package:flutter/widgets.dart';

import '../../theme/kharis_theme.dart';
import 'k_icon.dart';

/// How the Bible reader lays a chapter out.
enum KReaderLayout {
  /// Each verse on its own line.
  verses,

  /// Verses run together in the translation's paragraphs.
  paragraphs,
}

/// The Bible reader's toolbar: the layout toggle on the left, and on the
/// right one grouped control holding Search and the passage button
/// ("John 1 · NIV" with a chevron), which opens the passage picker. With no
/// [passage] (nothing to read) the group holds Search alone.
///
/// The controls are 38 tall inside a 44 hit area, and grow with the text.
class KReaderToolbar extends StatelessWidget {
  const KReaderToolbar({
    super.key,
    required this.layout,
    required this.onLayoutChanged,
    required this.passage,
    required this.version,
    required this.onSearch,
    required this.onPassage,
  });

  final KReaderLayout layout;
  final ValueChanged<KReaderLayout> onLayoutChanged;

  /// The open chapter, for example "John 1"; null hides the passage button.
  final String? passage;

  /// The version's abbreviation, for example "NIV".
  final String version;
  final VoidCallback? onSearch;
  final VoidCallback? onPassage;

  /// How far the 38 visible controls sit inside their 44 hit area.
  static const double _hitPad = (KSize.touchMin - KSize.toolbar) / 2;

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return Row(
      children: [
        Semantics(
          container: true,
          label: 'Reading layout',
          child: _Group(
            children: [
              _LayoutButton(
                key: const Key('reader-layout-verses'),
                icon: KIcons.scroll,
                label: 'One verse per line',
                selected: layout == KReaderLayout.verses,
                onTap: () => onLayoutChanged(KReaderLayout.verses),
              ),
              _LayoutButton(
                key: const Key('reader-layout-paragraphs'),
                icon: KIcons.pages,
                label: 'Paragraphs',
                selected: layout == KReaderLayout.paragraphs,
                onTap: () => onLayoutChanged(KReaderLayout.paragraphs),
              ),
            ],
          ),
        ),
        const SizedBox(width: KSpace.md),
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: _Group(
              children: [
                _Hit(
                  key: const Key('bible-search'),
                  label: 'Search',
                  onTap: onSearch,
                  child: const KIcon(KIcons.search, size: KSize.iconSm),
                ),
                if (passage case final passage?) ...[
                  DecoratedBox(
                    decoration: BoxDecoration(color: k.line),
                    child: const SizedBox(width: 1, height: KSize.iconMd),
                  ),
                  Flexible(
                    child: _Hit(
                      key: const Key('bible-reference'),
                      label:
                          '$passage, $version. '
                          'Change book, chapter or version',
                      onTap: onPassage,
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: KSpace.xl,
                          end: KSpace.lg,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                passage,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: KharisText.itemTitle.copyWith(
                                  color: k.text,
                                ),
                              ),
                            ),
                            Text(
                              ' \u00B7 ',
                              style: KharisText.itemTitle.copyWith(
                                color: k.muted,
                              ),
                            ),
                            Text(
                              version,
                              maxLines: 1,
                              style: KharisText.itemTitle.copyWith(
                                color: k.primaryText,
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
                ],
              ],
            ),
          ),
        ),
      ],
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

/// One control: a 44 hit area, read as a button.
class _Hit extends StatelessWidget {
  const _Hit({
    super.key,
    required this.label,
    required this.onTap,
    required this.child,
    this.selected,
  });

  final String label;
  final VoidCallback? onTap;
  final Widget child;

  /// Set for a control that is one of a set of choices.
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      selected: selected,
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
  }
}

/// One side of the layout toggle. Selected: an inverse block behind the
/// icon, and the selected state announced.
class _LayoutButton extends StatelessWidget {
  const _LayoutButton({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// The block is drawn inside the 38 box, clear of its border.
  static const double _width = 36;
  static const double _height = 30;

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return _Hit(
      label: label,
      selected: selected,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? k.inverse : null,
          borderRadius: const BorderRadius.all(Radius.circular(KRadius.xs)),
        ),
        child: SizedBox(
          width: _width,
          height: _height,
          child: Center(
            child: KIcon(
              icon,
              size: KSize.iconSm,
              color: selected ? k.onInverse : k.text,
            ),
          ),
        ),
      ),
    );
  }
}
