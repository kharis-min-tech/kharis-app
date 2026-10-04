import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/onboarding/data/auth_repository.dart';
import 'package:kharis_app/features/onboarding/presentation/screens/login_screen.dart'
    show authFieldDecoration;
import 'package:kharis_app/shared/providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .register(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
            displayName: _nameController.text.trim(),
            role: 'new_here',
          );
      if (mounted) context.go('/home');
    } on EmailAlreadyInUseException catch (e) {
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

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 56),

                // ── Heading ─────────────────────────────────────────────────
                Text(
                  'Create Account',
                  textAlign: TextAlign.center,
                  style: AppTypography.headlineLgMobile.copyWith(
                    color: context.kc.onBg,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Join the Kharis family',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyLg.copyWith(color: context.kc.muted),
                ),
                const SizedBox(height: 40),

                // ── Display Name ────────────────────────────────────────────
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  style: _textStyle,
                  decoration: _fieldDecoration(hint: 'Display name'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // ── Email ───────────────────────────────────────────────────
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  style: _textStyle,
                  decoration: _fieldDecoration(hint: 'Email address'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Email is required';
                    }
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v.trim())) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // ── Password ────────────────────────────────────────────────
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  style: _textStyle,
                  decoration: _fieldDecoration(hint: 'Password').copyWith(
                    suffixIcon: _eyeToggle(
                      obscure: _obscurePassword,
                      onTap: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
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
                const SizedBox(height: 12),

                // ── Confirm Password ────────────────────────────────────────
                TextFormField(
                  controller: _confirmController,
                  obscureText: _obscureConfirm,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _createAccount(),
                  style: _textStyle,
                  decoration: _fieldDecoration(hint: 'Confirm password')
                      .copyWith(
                        suffixIcon: _eyeToggle(
                          obscure: _obscureConfirm,
                          onTap: () => setState(
                            () => _obscureConfirm = !_obscureConfirm,
                          ),
                        ),
                      ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (v != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // ── Error message ───────────────────────────────────────────
                if (_errorMessage != null) ...[
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: AppTypography.ui(size: 14, color: AppColors.danger),
                  ),
                  const SizedBox(height: 12),
                ],

                // ── Create Account button ───────────────────────────────────
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _createAccount,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.kc.accent,
                      disabledBackgroundColor: context.kc.accent.withValues(
                        alpha: 0.4,
                      ),
                      foregroundColor: context.kc.onAccent,
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
                              color: context.kc.onAccent,
                            ),
                          )
                        : Text(
                            'Create account',
                            style: AppTypography.ui(
                              size: 15,
                              weight: FontWeight.w700,
                              color: context.kc.onAccent,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Sign In link ────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account?',
                      style: AppTypography.ui(
                        size: 14,
                        color: context.kc.muted,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.pop(),
                      child: Text(
                        'Sign in',
                        style: AppTypography.ui(
                          size: 14,
                          weight: FontWeight.w600,
                          color: context.kc.accentInk,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  TextStyle get _textStyle =>
      AppTypography.ui(size: 15, color: context.kc.onBg);

  InputDecoration _fieldDecoration({required String hint}) =>
      authFieldDecoration(context, hint: hint);

  Widget _eyeToggle({required bool obscure, required VoidCallback onTap}) {
    return IconButton(
      icon: Icon(
        obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        color: context.kc.muted,
        size: 20,
      ),
      onPressed: onTap,
    );
  }
}
