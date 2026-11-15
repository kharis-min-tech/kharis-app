import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:kharis_app/ui/components/components.dart';
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
      child: Dialog(
        backgroundColor: ctx.k.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(KRadius.card)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(KSpace.gutter),
          child: Row(
            children: [
              SizedBox.square(
                dimension: KSize.icon,
                child: CircularProgressIndicator(color: ctx.k.primaryText),
              ),
              const SizedBox(width: KSpace.xl),
              Expanded(
                child: Text(
                  'Deleting your account…',
                  style: KharisText.body.copyWith(color: ctx.k.text),
                ),
              ),
            ],
          ),
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
    final k = context.k;
    final body = KharisText.body.copyWith(color: k.muted);
    return _ConfirmDialog(
      title: 'Delete account?',
      canConfirm: _canConfirm,
      onConfirm: () => Navigator.of(context).pop(_password.text),
      children: [
        Text('This permanently deletes:', style: body),
        for (final item in const [
          'Your profile and sign-in',
          'Your notes',
          'Your collections and favourites',
          'Your event RSVPs',
        ])
          Padding(
            padding: const EdgeInsets.only(top: KSpace.xs),
            child: Text('•  $item', style: body),
          ),
        const SizedBox(height: KSpace.xl),
        Text(
          'This cannot be undone.',
          style: KharisText.itemTitle.copyWith(color: k.text),
        ),
        if (widget.requirePassword) ...[
          const SizedBox(height: KSpace.x3),
          KTextField(
            key: const ValueKey('delete-account-password'),
            label: 'Password',
            controller: _password,
            password: true,
            autofillHints: const [AutofillHints.password],
            onChanged: (_) => setState(() {}),
          ),
        ],
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
    return _ConfirmDialog(
      title: 'Confirm your password',
      canConfirm: _password.text.isNotEmpty,
      onConfirm: () => Navigator.of(context).pop(_password.text),
      children: [
        Text(
          'For your security, enter your password again to finish deleting '
          'your account.',
          style: KharisText.body.copyWith(color: context.k.muted),
        ),
        const SizedBox(height: KSpace.x3),
        KTextField(
          key: const ValueKey('confirm-password'),
          label: 'Password',
          controller: _password,
          password: true,
          autofillHints: const [AutofillHints.password],
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }
}

/// The shared frame of both confirmations: a title, what will happen, then
/// the destructive confirm ('Delete account', in the error role) above a
/// plain 'Cancel'.
class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.title,
    required this.children,
    required this.canConfirm,
    required this.onConfirm,
  });

  final String title;
  final List<Widget> children;
  final bool canConfirm;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Dialog(
      backgroundColor: k.surface,
      insetPadding: const EdgeInsets.all(KSpace.gutter),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(KRadius.card)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: KSize.maxContentWidth),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(KSpace.gutter),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: KharisText.section.copyWith(color: k.text),
                ),
              ),
              const SizedBox(height: KSpace.xl),
              ...children,
              const SizedBox(height: KSpace.gutter),
              KDestructiveButton(
                label: 'Delete account',
                expand: true,
                onPressed: canConfirm ? onConfirm : null,
              ),
              const SizedBox(height: KSpace.md),
              KButton(
                label: 'Cancel',
                variant: KButtonVariant.text,
                expand: true,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
