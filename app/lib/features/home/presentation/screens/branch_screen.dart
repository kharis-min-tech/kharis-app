import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/home/presentation/widgets/campus_card.dart';
import 'package:kharis_app/shared/providers/campus_config_provider.dart';
import 'package:kharis_app/shared/widgets/branch_picker_sheet.dart';

/// The member's branch in full (`/branch`): every service at every venue,
/// directions and contacts, as [CampusCard] lays them out. The AppBar names
/// the branch and offers Change, so the card drops its own header. Pushed
/// above the tab shell from Home's Next service card.
class BranchScreen extends ConsumerWidget {
  const BranchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kc = context.kc;
    final name = ref.watch(currentCampusProvider)?.name;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kc.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: Icon(Icons.arrow_back_rounded, color: kc.onBg),
          onPressed: () {
            final router = GoRouter.of(context);
            router.canPop() ? router.pop() : router.go('/home');
          },
        ),
        title: name == null
            ? null
            : Text(name, style: AppTypography.titleMd.copyWith(color: kc.onBg)),
        actions: [
          Semantics(
            label: 'Change branch',
            button: true,
            excludeSemantics: true,
            child: TextButton(
              key: const Key('home-branch-change'),
              onPressed: () => pickActiveBranch(context, ref),
              style: TextButton.styleFrom(
                foregroundColor: kc.onChip,
                minimumSize: const Size(48, 44),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: Text(
                'Change',
                style: AppTypography.ui(size: 14, weight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: SafeArea(top: false, child: CampusCard(showHeader: false)),
      ),
    );
  }
}
