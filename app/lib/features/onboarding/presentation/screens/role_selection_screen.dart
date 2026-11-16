import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kharis_app/core/constants/app_assets.dart';
import 'package:kharis_app/features/onboarding/presentation/widgets/role_card.dart';
import 'package:kharis_app/shared/providers/onboarding_provider.dart';
import 'package:kharis_app/ui/components/components.dart';
import 'package:url_launcher/url_launcher.dart';

/// Church privacy policy (verified 200). kharis.org publishes no terms of
/// service, so none is linked.
const String _kPrivacyPolicyUrl = 'https://kharis.org/privacy-policy/';

/// Width over height of the community photo.
const double _kBannerAspect = 3;

/// Role selection. Pick how the user relates to Kharis; every role continues
/// to branch selection.
class RoleSelectionScreen extends ConsumerStatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  ConsumerState<RoleSelectionScreen> createState() =>
      _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends ConsumerState<RoleSelectionScreen> {
  void _select(String role) {
    ref.read(onboardingRepositoryProvider).saveRole(role);
    context.go('/branch-selection');
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: KSize.maxContentWidth),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: KSpace.gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: KSpace.gutter),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: KDoveMark(size: KSize.thumb),
                    ),
                  ),
                  const SizedBox(height: KSpace.x3),
                  const KScreenHeader(title: 'Welcome home'),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: KSpace.gutter,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: KSpace.md),
                        Text(
                          'How are you connected to Kharis?',
                          style: KharisText.body.copyWith(color: k.muted),
                        ),
                        const SizedBox(height: KSpace.section),
                        ClipRRect(
                          borderRadius: const BorderRadius.all(
                            Radius.circular(KRadius.card),
                          ),
                          child: AspectRatio(
                            aspectRatio: _kBannerAspect,
                            child: ColoredBox(
                              color: k.surface2,
                              child: Image.asset(
                                AppAssets.communityRole,
                                fit: BoxFit.cover,
                                excludeFromSemantics: true,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: KSpace.md),
                        Text(
                          'One family, many stories',
                          style: KharisText.caption.copyWith(color: k.muted),
                        ),
                        const SizedBox(height: KSpace.section),
                        KListGroup(
                          children: [
                            RoleCard(
                              icon: KIcons.home,
                              title: 'Member',
                              description: 'I call Kharis my church home',
                              onTap: () => _select('member'),
                            ),
                            // One card for first-timers and visitors: the two
                            // meant the same thing to members (team review),
                            // and both settle in through the same New here
                            // path.
                            RoleCard(
                              icon: KIcons.sparkle,
                              title: 'New here',
                              description:
                                  'Visiting or just exploring? Help me '
                                  'settle in',
                              onTap: () => _select('new_here'),
                            ),
                            RoleCard(
                              icon: KIcons.heart,
                              title: 'Partner',
                              description: 'I support Kharis in ministry',
                              onTap: () => _select('partner'),
                            ),
                          ],
                        ),
                        const SizedBox(height: KSpace.x3),
                        Center(
                          child: KTextLink(
                            label: 'Privacy policy',
                            onTap: () => launchUrl(
                              Uri.parse(_kPrivacyPolicyUrl),
                              mode: LaunchMode.inAppBrowserView,
                            ),
                          ),
                        ),
                      ],
                    ),
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
