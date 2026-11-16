import 'package:flutter/material.dart';

import 'package:kharis_app/ui/components/components.dart';

/// The page frame shared by the member's library screens (collections,
/// Favourites, notes): a [KScreenHeader] that scrolls with the content, no
/// back button (swipe back and the system back leave), and content centred
/// at the maximum content width on wide screens.
class LibraryScaffold extends StatelessWidget {
  const LibraryScaffold({
    super.key,
    required this.title,
    required this.slivers,
    this.titleKey,
    this.actions = const [],
  });

  final String title;
  final Key? titleKey;

  /// Up to two [KIconButton]s.
  final List<Widget> actions;

  /// The content under the header. Wrap boxes in [LibrarySection].
  final List<Widget> slivers;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: KSize.maxContentWidth),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: KSpace.x3),
                    child: KScreenHeader(
                      key: titleKey,
                      title: title,
                      actions: actions,
                    ),
                  ),
                ),
                ...slivers,
                SliverToBoxAdapter(
                  child: SizedBox(
                    height:
                        MediaQuery.paddingOf(context).bottom +
                        KSize.contentBottomPad,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A block of content inside a [LibraryScaffold], inset by the page gutter.
class LibrarySection extends StatelessWidget {
  const LibrarySection({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: KSpace.gutter),
        child: child,
      ),
    );
  }
}

/// An empty or error state that fills what is left of a [LibraryScaffold]
/// and centres [child] in it.
class LibraryFill extends StatelessWidget {
  const LibraryFill({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(child: child),
    );
  }
}

/// Stands in for a group of list rows while they load: the same card, row
/// height, thumbnail and two text lines as the real rows.
class LibraryListSkeleton extends StatelessWidget {
  const LibraryListSkeleton({super.key, this.rows = 3});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: KListGroup(
        children: [
          for (var i = 0; i < rows; i++)
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: KSize.listRow),
              child: const Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: KSpace.x3,
                  vertical: KSpace.md,
                ),
                child: Row(
                  children: [
                    KSkeleton(width: KSize.thumb, height: KSize.thumb),
                    SizedBox(width: KSpace.xl),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FractionallySizedBox(
                            widthFactor: 0.6,
                            child: KSkeleton(
                              height: KSpace.xxl,
                              radius: KRadius.xs,
                            ),
                          ),
                          SizedBox(height: KSpace.sm),
                          FractionallySizedBox(
                            widthFactor: 0.35,
                            child: KSkeleton(
                              height: KSpace.xl,
                              radius: KRadius.xs,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
