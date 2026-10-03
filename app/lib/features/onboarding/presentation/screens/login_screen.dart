import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/onboarding/data/auth_repository.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';

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

  bool _obscurePassword = true;
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
    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).loginAsGuest();
      // Guests skip register's branch step, so ask here; otherwise the
      // events feed defaults to every campus at once (tester feedback).
      if (mounted) context.go('/branch-selection');
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final sentTo = await showDialog<String>(
      context: context,
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
    final kc = context.kc;
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      appBar: canPop
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(color: kc.onBg),
            )
          : null,
      body: SafeArea(
        top: !canPop,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: canPop ? 8 : 56),

                // ── Dove logo ──────────────────────────────────────────────
                Center(
                  child: Image.asset(
                    'assets/figma/dove_logo.png',
                    width: 72,
                    height: 72,
                    color: kc.onChip,
                  ),
                ),
                const SizedBox(height: 32),

                // ── Heading ─────────────────────────────────────────────────
                Text(
                  'Welcome back',
                  textAlign: TextAlign.center,
                  style: AppTypography.headlineLgMobile.copyWith(
                    color: kc.onBg,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign in to your account',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyLg.copyWith(color: kc.muted),
                ),
                const SizedBox(height: 40),

                // ── Email field ─────────────────────────────────────────────
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  style: AppTypography.ui(size: 15, color: kc.onBg),
                  decoration: authFieldDecoration(
                    context,
                    hint: 'Email address',
                  ),
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
                const SizedBox(height: 12),

                // ── Password field ──────────────────────────────────────────
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _signIn(),
                  style: AppTypography.ui(size: 15, color: kc.onBg),
                  decoration: authFieldDecoration(context, hint: 'Password')
                      .copyWith(
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword
                              ? 'Show password'
                              : 'Hide password',
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: kc.muted,
                            size: 20,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required';
                    if (v.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isLoading ? null : _forgotPassword,
                    child: Text(
                      'Forgot password?',
                      style: AppTypography.ui(
                        size: 13.5,
                        weight: FontWeight.w600,
                        color: kc.accentInk,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // ── Error message ───────────────────────────────────────────
                if (_errorMessage != null) ...[
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: AppTypography.ui(size: 14, color: AppColors.danger),
                  ),
                  const SizedBox(height: 12),
                ],

                // ── Sign In button ──────────────────────────────────────────
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signIn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kc.accent,
                      disabledBackgroundColor: kc.accent.withValues(alpha: 0.4),
                      foregroundColor: kc.onAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.buttonBorder,
                      ),
                      elevation: 0,
                      shadowColor: Colors.transparent,
                    ),
                    child: _isLoading
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: kc.onAccent,
                            ),
                          )
                        : Text(
                            'Sign in',
                            style: AppTypography.ui(
                              size: 15,
                              weight: FontWeight.w700,
                              color: kc.onAccent,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Register link ───────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account?",
                      style: AppTypography.ui(size: 14, color: kc.muted),
                    ),
                    TextButton(
                      onPressed: () => context.push('/register'),
                      child: Text(
                        'Register',
                        style: AppTypography.ui(
                          size: 14,
                          weight: FontWeight.w600,
                          color: kc.accentInk,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // ── Continue as Guest ───────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _continueAsGuest,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kc.onBg,
                      side: BorderSide(color: kc.outline),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.buttonBorder,
                      ),
                    ),
                    child: Text(
                      'Continue as Guest',
                      style: AppTypography.ui(
                        size: 15,
                        weight: FontWeight.w600,
                        color: kc.onBg,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Text-field decoration shared by the sign-in and register forms.
InputDecoration authFieldDecoration(
  BuildContext context, {
  required String hint,
}) {
  final kc = context.kc;
  OutlineInputBorder border(Color? color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: AppRadius.inputBorder,
        borderSide: color == null
            ? BorderSide.none
            : BorderSide(color: color, width: width),
      );
  return InputDecoration(
    filled: true,
    fillColor: kc.surfaceAlt,
    hintText: hint,
    hintStyle: AppTypography.ui(size: 15, color: kc.muted),
    errorStyle: AppTypography.ui(size: 12, color: AppColors.danger),
    border: border(null),
    enabledBorder: border(null),
    focusedBorder: border(kc.accentInk, 2),
    errorBorder: border(AppColors.danger),
    focusedErrorBorder: border(AppColors.danger, 1.5),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );
}

/// Asks for an email and sends a password-reset link through the auth
/// repository. Pops the address the link was sent to, or null if cancelled.
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
    final kc = context.kc;
    return AlertDialog(
      backgroundColor: kc.surface,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
      title: Text(
        'Reset your password',
        style: AppTypography.display(
          size: 20,
          weight: FontWeight.w700,
          color: kc.onBg,
        ),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the email you sign in with and we will send you a link '
              'to choose a new password.',
              style: AppTypography.ui(size: 14, height: 1.45, color: kc.muted),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const ValueKey('reset-email'),
              controller: _emailController,
              autofocus: widget.initialEmail.isEmpty,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.send,
              onFieldSubmitted: (_) => _send(),
              style: AppTypography.ui(size: 15, color: kc.onBg),
              decoration: authFieldDecoration(context, hint: 'Email address'),
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
              const SizedBox(height: 10),
              Text(
                _error!,
                style: AppTypography.ui(size: 13, color: AppColors.danger),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: AppTypography.ui(
              size: 14,
              weight: FontWeight.w600,
              color: kc.muted,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _sending ? null : _send,
          style: ElevatedButton.styleFrom(
            backgroundColor: kc.accent,
            foregroundColor: kc.onAccent,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
          ),
          child: _sending
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: kc.onAccent,
                  ),
                )
              : Text(
                  'Send reset link',
                  style: AppTypography.ui(
                    size: 14,
                    weight: FontWeight.w700,
                    color: kc.onAccent,
                  ),
                ),
        ),
      ],
    );
  }
}
