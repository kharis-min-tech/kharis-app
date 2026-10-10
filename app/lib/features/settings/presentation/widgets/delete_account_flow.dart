import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/onboarding/data/auth_repository.dart';
import 'package:kharis_app/features/settings/data/account_deletion.dart';
import 'package:kharis_app/shared/models/user.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/onboarding_provider.dart';

/// Shown once the account is gone, on the Welcome screen.
const String kAccountDeletedMessage = 'Your account has been deleted.';

/// Walks [user] through deleting their account: a confirmation that says
/// what goes (with the password for email sign-ins), progress, then Welcome.
/// Failures are shown and nothing is reported as done unless it is.
Future<void> confirmDeleteAccount(BuildContext context, User user) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final needsPassword = container
      .read(authRepositoryProvider)
      .usesPasswordSignIn;
  final password = await showDialog<String>(
    context: context,
    builder: (_) => DeleteAccountDialog(requirePassword: needsPassword),
  );
  if (password == null || !context.mounted) return;
  await _delete(
    context,
    container,
    uid: user.id,
    password: needsPassword ? password : null,
  );
}

Future<void> _delete(
  BuildContext context,
  ProviderContainer container, {
  required String uid,
  required String? password,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  final navigator = Navigator.of(context, rootNavigator: true);
  void say(String message) =>
      messenger.showSnackBar(SnackBar(content: Text(message)));

  _showProgress(context);
  try {
    await container
        .read(accountDeletionServiceProvider)
        .deleteAccount(uid: uid, password: password);
  } on RecentLoginRequiredException {
    navigator.pop();
    if (!context.mounted) return;
    if (!container.read(authRepositoryProvider).usesPasswordSignIn) {
      say(
        'For your security, sign out and sign in again, then delete your '
        'account.',
      );
      return;
    }
    final retry = await showDialog<String>(
      context: context,
      builder: (_) => const ConfirmPasswordDialog(),
    );
    if (!context.mounted) return;
    if (retry == null) {
      say('Your account was not deleted.');
      return;
    }
    await _delete(context, container, uid: uid, password: retry);
    return;
  } catch (e) {
    navigator.pop();
    debugPrint('[account] deletion failed: $e');
    say(
      e is InvalidCredentialsException
          ? e.message
          : 'We could not delete your account. Check your connection and '
                'try again.',
    );
    return;
  }

  navigator.pop();
  // Saved role and branch were cleared: re-read them so '/' shows Welcome.
  container
    ..invalidate(onboardingCompletedProvider)
    ..invalidate(currentBranchProvider);
  router.go('/');
  say(kAccountDeletedMessage);
}

void _showProgress(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (ctx) => PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: ctx.kc.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
        content: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: ctx.kc.danger,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Deleting your account…',
                style: AppTypography.ui(size: 14).copyWith(color: ctx.kc.onBg),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Confirmation for account deletion. Pops the entered password (empty when
/// [requirePassword] is false) on confirm, null on cancel.
class DeleteAccountDialog extends StatefulWidget {
  const DeleteAccountDialog({super.key, required this.requirePassword});

  final bool requirePassword;

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  bool get _canConfirm => !widget.requirePassword || _password.text.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    final body = AppTypography.ui(size: 14).copyWith(color: kc.muted);
    return AlertDialog(
      backgroundColor: kc.surface,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
      title: _title(context, 'Delete account?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This permanently deletes:', style: body),
            const SizedBox(height: AppSpacing.xs),
            for (final item in const [
              'Your profile and sign-in',
              'Your notes',
              'Your playlists and favourites',
              'Your event RSVPs',
            ])
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text('•  $item', style: body),
              ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'This cannot be undone.',
              style: AppTypography.ui(
                size: 14,
                weight: FontWeight.w600,
              ).copyWith(color: kc.onBg),
            ),
            if (widget.requirePassword) ...[
              const SizedBox(height: AppSpacing.sm),
              _PasswordField(
                key: const ValueKey('delete-account-password'),
                controller: _password,
                onChanged: (_) => setState(() {}),
              ),
            ],
          ],
        ),
      ),
      actions: [
        _cancel(context),
        TextButton(
          onPressed: _canConfirm
              ? () => Navigator.of(context).pop(_password.text)
              : null,
          child: Text(
            'Delete account',
            style: AppTypography.ui(
              size: 14,
              weight: FontWeight.w700,
            ).copyWith(color: _canConfirm ? kc.danger : kc.faint),
          ),
        ),
      ],
    );
  }
}

/// Asks for the password again when the auth backend wants a fresh sign-in.
/// Pops the password on confirm, null on cancel.
class ConfirmPasswordDialog extends StatefulWidget {
  const ConfirmPasswordDialog({super.key});

  @override
  State<ConfirmPasswordDialog> createState() => _ConfirmPasswordDialogState();
}

class _ConfirmPasswordDialogState extends State<ConfirmPasswordDialog> {
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    final canConfirm = _password.text.isNotEmpty;
    return AlertDialog(
      backgroundColor: kc.surface,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
      title: _title(context, 'Confirm your password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'For your security, enter your password again to finish deleting '
            'your account.',
            style: AppTypography.ui(size: 14).copyWith(color: kc.muted),
          ),
          const SizedBox(height: AppSpacing.sm),
          _PasswordField(
            key: const ValueKey('confirm-password'),
            controller: _password,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        _cancel(context),
        TextButton(
          onPressed: canConfirm
              ? () => Navigator.of(context).pop(_password.text)
              : null,
          child: Text(
            'Delete account',
            style: AppTypography.ui(
              size: 14,
              weight: FontWeight.w700,
            ).copyWith(color: canConfirm ? kc.danger : kc.faint),
          ),
        ),
      ],
    );
  }
}

Widget _title(BuildContext context, String text) => Text(
  text,
  style: AppTypography.ui(
    size: 16,
    weight: FontWeight.w700,
  ).copyWith(color: context.kc.onBg),
);

Widget _cancel(BuildContext context) => TextButton(
  onPressed: () => Navigator.of(context).pop(),
  child: Text(
    'Cancel',
    style: AppTypography.ui(
      size: 14,
      weight: FontWeight.w600,
    ).copyWith(color: context.kc.muted),
  ),
);

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      obscureText: true,
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: const [AutofillHints.password],
      style: AppTypography.ui(size: 15).copyWith(color: kc.onBg),
      decoration: InputDecoration(
        hintText: 'Password',
        hintStyle: AppTypography.ui(size: 15).copyWith(color: kc.muted),
        filled: true,
        fillColor: kc.surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.gutter,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputBorder,
          borderSide: BorderSide(color: kc.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputBorder,
          borderSide: BorderSide(color: kc.accentInk, width: 1.4),
        ),
      ),
    );
  }
}
