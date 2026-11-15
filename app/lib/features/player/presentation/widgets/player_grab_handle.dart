import 'package:flutter/material.dart';

import 'package:kharis_app/ui/components/components.dart';

/// The grab handle at the top of the full player. The player is a full-screen
/// route with no back button: a swipe down (here, or from the top of the
/// page), a swipe back or the system back closes it, and the handle makes
/// that gesture discoverable. A tap on it closes the player as well, and
/// screen readers get it as a "Close player" button.
class PlayerGrabHandle extends StatelessWidget {
  const PlayerGrabHandle({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Close player',
      onTap: onClose,
      excludeSemantics: true,
      child: GestureDetector(
        key: const Key('player-grab-handle'),
        behavior: HitTestBehavior.opaque,
        onTap: onClose,
        onVerticalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) > 0) onClose();
        },
        child: SizedBox(
          height: KSize.touchMin,
          width: double.infinity,
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: context.k.muted,
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
        ),
      ),
    );
  }
}
