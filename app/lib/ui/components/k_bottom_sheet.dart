import 'package:flutter/material.dart';

import '../../theme/kharis_theme.dart';
import 'k_layout.dart';

enum KSheetTitleSize {
  /// The pageTitle style, for a sheet that is a page in itself (Grace).
  page,

  /// The section style, for pickers and menus.
  section,
}

/// The body of a bottom sheet: sheet colour, 16 top corners, a 36×4 grab
/// handle, an optional title and the content. Show it with
/// [showKBottomSheet].
class KBottomSheet extends StatelessWidget {
  const KBottomSheet({
    super.key,
    required this.child,
    this.title,
    this.titleSize = KSheetTitleSize.section,
  });

  final Widget child;
  final String? title;
  final KSheetTitleSize titleSize;

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: k.sheet,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(KRadius.sheet),
        ),
        boxShadow: KShadow.sheet,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              KSpace.gutter,
              KSpace.md,
              KSpace.gutter,
              KSpace.gutter,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: k.line,
                      borderRadius: const BorderRadius.all(
                        Radius.circular(KRadius.xs),
                      ),
                    ),
                    child: const SizedBox(
                      width: KSize.sheetHandleWidth,
                      height: KSize.sheetHandleHeight,
                    ),
                  ),
                ),
                const SizedBox(height: KSpace.x3),
                if (title != null) ...[
                  Semantics(
                    header: true,
                    child: Text(
                      title!,
                      style:
                          (titleSize == KSheetTitleSize.page
                                  ? KharisText.pageTitle
                                  : KharisText.section)
                              .copyWith(color: k.text),
                    ),
                  ),
                  const SizedBox(height: KSpace.xl),
                ],
                Flexible(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows [builder] in a [KBottomSheet] over a scrim. Dismiss by swiping down
/// or tapping the scrim. With reduce motion on, the sheet fades in instead of
/// sliding. Focus is trapped in the sheet and returns when it closes.
Future<T?> showKBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  String? title,
  KSheetTitleSize titleSize = KSheetTitleSize.section,
}) {
  final k = context.k;

  Widget sheet(BuildContext sheetContext) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: KSize.maxContentWidth),
    child: KBottomSheet(
      title: title,
      titleSize: titleSize,
      child: builder(sheetContext),
    ),
  );

  if (MediaQuery.disableAnimationsOf(context)) {
    final navigator = Navigator.of(context, rootNavigator: true);
    final themes = InheritedTheme.capture(from: context, to: navigator.context);
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: k.scrim,
      transitionDuration: KMotion.fast,
      transitionBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
      pageBuilder: (dialogContext, _, _) => themes.wrap(
        SafeArea(
          bottom: false,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              // Swiping down still closes the sheet; only the slide is gone.
              onVerticalDragEnd: (details) {
                if ((details.primaryVelocity ?? 0) > 0) {
                  Navigator.of(dialogContext).maybePop();
                }
              },
              child: Builder(builder: sheet),
            ),
          ),
        ),
      ),
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    backgroundColor: kClear(k.sheet),
    barrierColor: k.scrim,
    elevation: 0,
    constraints: const BoxConstraints(maxWidth: KSize.maxContentWidth),
    builder: sheet,
  );
}
