import 'package:flutter/widgets.dart';

import '../../theme/kharis_theme.dart';
import 'k_button.dart';
import 'k_icon.dart';

/// What a list shows when it has nothing in it: an icon, a one-line title, a
/// one-line hint and an optional button, centred.
class KEmptyState extends StatelessWidget {
  const KEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.hint,
    this.action,
  });

  /// One of the [KIcons] paths.
  final String icon;
  final String title;
  final String hint;

  /// Usually a [KButton].
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return Padding(
      padding: const EdgeInsets.all(KSpace.gutter),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          KIcon(icon, size: KSize.iconLg, color: k.muted),
          const SizedBox(height: KSpace.xl),
          Text(
            title,
            textAlign: TextAlign.center,
            style: KharisText.title.copyWith(color: k.text),
          ),
          const SizedBox(height: KSpace.xs),
          Text(
            hint,
            textAlign: TextAlign.center,
            style: KharisText.meta.copyWith(color: k.muted),
          ),
          if (action != null) ...[const SizedBox(height: KSpace.x3), action!],
        ],
      ),
    );
  }
}

/// What a list shows when loading fails: one line saying what happened and
/// what to do, and a Retry button.
class KErrorState extends StatelessWidget {
  const KErrorState({
    super.key,
    required this.message,
    required this.onRetry,
    this.retryLabel = 'Retry',
  });

  /// For example "Messages didn't load. Check your connection and retry."
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return Padding(
      padding: const EdgeInsets.all(KSpace.gutter),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: KharisText.body.copyWith(color: k.text),
            ),
          ),
          const SizedBox(height: KSpace.xl),
          KButton(
            label: retryLabel,
            onPressed: onRetry,
            variant: KButtonVariant.outline,
          ),
        ],
      ),
    );
  }
}

/// A surface2 block that stands in for content while it loads. Size it to
/// match the real layout. Hidden from screen readers.
class KSkeleton extends StatelessWidget {
  const KSkeleton({
    super.key,
    this.width,
    this.height,
    this.radius = KRadius.tile,
  });

  /// Null fills the available width.
  final double? width;
  final double? height;

  /// One of the [KRadius] values.
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.k.surface2,
          borderRadius: BorderRadius.all(Radius.circular(radius)),
        ),
        child: SizedBox(width: width ?? double.infinity, height: height),
      ),
    );
  }
}
