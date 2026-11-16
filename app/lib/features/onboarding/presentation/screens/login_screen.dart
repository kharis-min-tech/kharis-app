import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kharis_app/features/onboarding/data/auth_repository.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/ui/components/components.dart';

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .login(_emailController.text.trim(), _passwordController.text);
      if (!mounted) return;
      // Opened from More (or Edit profile): return there. From the splash
      // there is nothing beneath, so enter the app.
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop();
      } else {
        context.go('/home');
      }
    } on InvalidCredentialsException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorMessage = 'Something went wrong. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _continueAsGuest() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await ref.read(authRepositoryProvider).loginAsGuest();
      // Guests skip register's branch step, so ask here; otherwise the
      // events feed defaults to every branch at once (tester feedback).
      if (mounted) context.go('/branch-selection');
    } catch (_) {
      // A silent failure reads as a dead button (tester feedback), so say so.
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Could not continue as a guest. Check your connection and '
              'try again.';
        });
      }
    }
  }

  Future<void> _forgotPassword() async {
    final sentTo = await showKBottomSheet<String>(
      context: context,
      title: 'Reset your password',
      builder: (_) =>
          ForgotPasswordDialog(initialEmail: _emailController.text.trim()),
    );
    if (sentTo == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          'If $sentTo has a Kharis account, a reset link is on its way. '
          'Check your inbox and spam folder.',
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

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
              child: Form(
                key: _formKey,
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
                    const KScreenHeader(title: 'Welcome back'),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: KSpace.gutter,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: KSpace.md),
                          Text(
                            'Sign in to your account',
                            style: KharisText.body.copyWith(color: k.muted),
                          ),
                          const SizedBox(height: KSpace.section),
                          KTextField(
                            label: 'Email address',
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            textInputAction: TextInputAction.next,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Email is required';
                              }
                              if (!_emailPattern.hasMatch(v.trim())) {
                                return 'Enter a valid email address';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: KSpace.x3),
                          KTextField(
                            label: 'Password',
                            controller: _passwordController,
                            password: true,
                            autofillHints: const [AutofillHints.password],
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _signIn(),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Password is required';
                              }
                              if (v.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: KTextLink(
                              label: 'Forgot password?',
                              onTap: _isLoading ? null : _forgotPassword,
                            ),
                          ),
                          const SizedBox(height: KSpace.md),
                          if (_errorMessage != null) ...[
                            KInlineError(_errorMessage!),
                            const SizedBox(height: KSpace.xl),
                          ],
                          KButton(
                            label: 'Sign in',
                            size: KButtonSize.cta,
                            expand: true,
                            loading: _isLoading,
                            onPressed: _signIn,
                          ),
                          const SizedBox(height: KSpace.xl),
                          KButton(
                            label: 'Continue as guest',
                            variant: KButtonVariant.outline,
                            expand: true,
                            onPressed: _isLoading ? null : _continueAsGuest,
                          ),
                          const SizedBox(height: KSpace.x3),
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: KSpace.md,
                            children: [
                              Text(
                                "Don't have an account?",
                                style: KharisText.body.copyWith(color: k.muted),
                              ),
                              KTextLink(
                                label: 'Register',
                                onTap: () => context.push('/register'),
                              ),
                            ],
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
      ),
    );
  }
}

/// Asks for an email and sends a password-reset link through the auth
/// repository. Shown in a bottom sheet; pops the address the link was sent
/// to, or null if cancelled.
class ForgotPasswordDialog extends ConsumerStatefulWidget {
  const ForgotPasswordDialog({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  ConsumerState<ForgotPasswordDialog> createState() =>
      _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends ConsumerState<ForgotPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _emailController = TextEditingController(
    text: widget.initialEmail,
  );
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailController.text.trim();
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).sendPasswordResetEmail(email);
      if (mounted) Navigator.of(context).pop(email);
    } on InvalidCredentialsException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'We could not send the email. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      // Keeps the field and button above the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Enter the email you sign in with and we will send you a link '
              'to choose a new password.',
              style: KharisText.body.copyWith(color: context.k.muted),
            ),
            const SizedBox(height: KSpace.x3),
            KTextField(
              key: const ValueKey('reset-email'),
              label: 'Email address',
              controller: _emailController,
              autofocus: widget.initialEmail.isEmpty,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.send,
              onFieldSubmitted: (_) => _send(),
              validator: (v) {
                final value = v?.trim() ?? '';
                if (value.isEmpty) return 'Email is required';
                if (!_emailPattern.hasMatch(value)) {
                  return 'Enter a valid email address';
                }
                return null;
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: KSpace.lg),
              KInlineError(_error!),
            ],
            const SizedBox(height: KSpace.x3),
            KButton(
              label: 'Send reset link',
              expand: true,
              loading: _sending,
              onPressed: _send,
            ),
            const SizedBox(height: KSpace.md),
            KButton(
              label: 'Cancel',
              variant: KButtonVariant.text,
              expand: true,
              onPressed: _sending ? null : () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
