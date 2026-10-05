import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/admin/presentation/widgets/giving_editor.dart';
import 'package:kharis_app/features/admin/presentation/widgets/home_layout_editor.dart';
import 'package:kharis_app/features/admin/providers/content_config_providers.dart';
import 'package:kharis_app/shared/models/campus_config.dart';

/// Super-admin screen for church-wide app settings: the giving details
/// (`config/giving`) and default Home layout (`config/home`) every campus
/// uses unless its branch page sets its own.
class AdminAppSettingsScreen extends ConsumerWidget {
  const AdminAppSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final givingAsync = ref.watch(adminChurchGivingProvider);
    final homeAsync = ref.watch(adminChurchHomeProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'App settings',
          style: AppTypography.titleMd.copyWith(color: AppColors.heading),
        ),
        iconTheme: const IconThemeData(color: AppColors.heading),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.sm,
          AppSpacing.gutter,
          AppSpacing.lg + AppSpacing.lg,
        ),
        children: [
          _SettingsCard(
            title: 'Church-wide giving',
            subtitle:
                'Shown in Giving for every branch without its own details.',
            child: givingAsync.when(
              loading: () => const _Loading(),
              error: (_, _) => const _LoadError('giving details'),
              // Keyed on the stored value so a save (or another admin's)
              // refreshes the fields.
              data: (giving) => GivingEditor(
                key: ValueKey(giving),
                initial: giving,
                clearLabel: 'Use the app’s built-in details',
                fallbackHint:
                    'Not set: the app shows its built-in church details.',
                onSave: (g) => _save(
                  context,
                  () => ref
                      .read(contentConfigRepositoryProvider)
                      .setChurchGiving(g),
                  g == null
                      ? 'Giving now uses the app’s built-in details.'
                      : 'Church-wide giving updated.',
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _SettingsCard(
            title: 'Default Home layout',
            subtitle:
                'The Home blocks every branch without its own layout shows, '
                'top to bottom.',
            child: homeAsync.when(
              loading: () => const _Loading(),
              error: (_, _) => const _LoadError('Home layout'),
              data: (home) => HomeLayoutEditor(
                key: ValueKey(home),
                initial: home,
                inherited: HomeLayout.fallback,
                inheritedHint:
                    'Using the app’s built-in layout. Saving makes it the '
                    'church-wide default.',
                clearLabel: 'Use the app’s built-in layout',
                onSave: (h) => _save(
                  context,
                  () => ref
                      .read(contentConfigRepositoryProvider)
                      .setChurchHome(h),
                  h == null
                      ? 'Home now uses the app’s built-in layout.'
                      : 'Default Home layout updated.',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Runs [write], reporting the outcome; rethrows so the editor keeps the
  /// admin's input on failure.
  static Future<void> _save(
    BuildContext context,
    Future<void> Function() write,
    String done,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await write();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Save failed: $e'),
          backgroundColor: AppColors.errorContainer,
        ),
      );
      rethrow;
    }
    messenger.showSnackBar(
      SnackBar(content: Text(done), backgroundColor: AppColors.surfaceElevated),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: AppRadius.cardBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.bodyLg.copyWith(
              color: AppColors.heading,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: AppTypography.bodySm.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
    child: Center(child: CircularProgressIndicator(color: AppColors.secondary)),
  );
}

class _LoadError extends StatelessWidget {
  const _LoadError(this.what);

  final String what;

  @override
  Widget build(BuildContext context) => Text(
    'Could not load the $what.',
    style: AppTypography.bodySm.copyWith(color: AppColors.textMuted),
  );
}
