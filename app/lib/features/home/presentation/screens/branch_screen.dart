import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:kharis_app/features/home/presentation/widgets/campus_card.dart';
import 'package:kharis_app/shared/providers/campus_config_provider.dart';
import 'package:kharis_app/ui/components/components.dart';

/// Home's branch in full (`/branch`): where it meets, directions, contacts
/// and every service as a timetable, as [CampusCard] lays them out. The
/// header names the branch, so the card drops its own; its "Change branch"
/// button carries the `home-branch-change` key. Pushed above the tab shell
/// from Home's Next service card, so it shows the branch that card showed
/// ([homeCampusProvider]).
class BranchScreen extends ConsumerWidget {
  const BranchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(homeCampusProvider)?.name;
    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: KSize.maxContentWidth),
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(
                top: KSpace.md,
                bottom: KSpace.section,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Opened with nothing beneath it (a deep link), system
                  // back goes Home rather than leaving the app.
                  PopScope(
                    canPop: GoRouter.maybeOf(context)?.canPop() ?? true,
                    onPopInvokedWithResult: (didPop, _) {
                      if (!didPop) GoRouter.of(context).go('/home');
                    },
                    child: name == null
                        ? const SizedBox.shrink()
                        : KScreenHeader(title: name),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(
                      KSpace.gutter,
                      KSpace.x3,
                      KSpace.gutter,
                      0,
                    ),
                    child: CampusCard(showHeader: false, homeScope: true),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
