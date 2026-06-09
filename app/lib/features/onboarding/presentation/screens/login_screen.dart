import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kharis_app/core/theme/app_colors.dart';
import 'package:kharis_app/features/onboarding/data/auth_repository.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';

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
      await ref.read(authRepositoryProvider).login(
            _emailController.text.trim(),
            _passwordController.text,
          );
      if (mounted) context.go('/home');
    } on InvalidCredentialsException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _continueAsGuest() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).loginAsGuest();
      if (mounted) context.go('/home');
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 56),

                // ── Dove icon ───────────────────────────────────────────────
                Center(
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: CustomPaint(
                      painter: _DovePainter(color: AppColors.purple),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // ── Heading ─────────────────────────────────────────────────
                Text(
                  'Welcome back',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.mavenPro(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign in to your account',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    color: AppColors.textBody,
                  ),
                ),
                const SizedBox(height: 40),

                // ── Email field ─────────────────────────────────────────────
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
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

                // ── Password field ──────────────────────────────────────────
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _signIn(),
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                  decoration: _fieldDecoration(hint: 'Password').copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppColors.textBody,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required';
                    if (v.length < 6) return 'Password must be at least 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // ── Error message ───────────────────────────────────────────
                if (_errorMessage != null) ...[
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      color: AppColors.error,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // ── Sign In button ──────────────────────────────────────────
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signIn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.5),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                      shadowColor: Colors.transparent,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white),
                            ),
                          )
                        : Text(
                            'SIGN IN',
                            style: GoogleFonts.mavenPro(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
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
                      "Don't have an account? ",
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        color: AppColors.textBody,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.push('/register'),
                      child: Text(
                        'Register',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          color: AppColors.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),

                // ── Continue as Guest ───────────────────────────────────────
                TextButton(
                  onPressed: _isLoading ? null : _continueAsGuest,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textMuted,
                  ),
                  child: Text(
                    'Continue as Guest',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      color: AppColors.textMuted,
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

  InputDecoration _fieldDecoration({required String hint}) {
    return InputDecoration(
      filled: true,
      fillColor: AppColors.surfaceSubtle,
      hintText: hint,
      hintStyle: GoogleFonts.dmSans(
        fontSize: 15,
        color: AppColors.textBody,
      ),
      errorStyle: GoogleFonts.dmSans(
        fontSize: 12,
        color: AppColors.error,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.accent, width: 1),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}

// ── Dove painter (matches splash_screen.dart silhouette) ─────────────────────

class _DovePainter extends CustomPainter {
  const _DovePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final w = size.width;
    final h = size.height;

    // Body
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.50, h * 0.38)
        ..cubicTo(w * 0.28, h * 0.30, w * 0.08, h * 0.45, w * 0.12, h * 0.62)
        ..cubicTo(w * 0.15, h * 0.74, w * 0.30, h * 0.78, w * 0.42, h * 0.72)
        ..cubicTo(w * 0.50, h * 0.68, w * 0.56, h * 0.70, w * 0.62, h * 0.76)
        ..cubicTo(w * 0.70, h * 0.84, w * 0.80, h * 0.80, w * 0.82, h * 0.70)
        ..cubicTo(w * 0.85, h * 0.55, w * 0.72, h * 0.42, w * 0.50, h * 0.38)
        ..close(),
      paint,
    );

    // Left wing
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.42, h * 0.50)
        ..cubicTo(w * 0.28, h * 0.32, w * 0.05, h * 0.28, w * 0.05, h * 0.44)
        ..cubicTo(w * 0.05, h * 0.52, w * 0.20, h * 0.56, w * 0.38, h * 0.58)
        ..close(),
      paint,
    );

    // Right wing
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.58, h * 0.48)
        ..cubicTo(w * 0.72, h * 0.30, w * 0.95, h * 0.26, w * 0.95, h * 0.42)
        ..cubicTo(w * 0.95, h * 0.50, w * 0.80, h * 0.55, w * 0.62, h * 0.56)
        ..close(),
      paint,
    );

    // Head
    canvas.drawPath(
      Path()
        ..addOval(Rect.fromCenter(
          center: Offset(w * 0.50, h * 0.28),
          width: w * 0.22,
          height: h * 0.22,
        )),
      paint,
    );

    // Beak
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.50, h * 0.22)
        ..lineTo(w * 0.38, h * 0.18)
        ..lineTo(w * 0.46, h * 0.26)
        ..close(),
      paint,
    );

    // Tail
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.62, h * 0.72)
        ..cubicTo(w * 0.72, h * 0.82, w * 0.85, h * 0.90, w * 0.88, h * 0.82)
        ..cubicTo(w * 0.90, h * 0.76, w * 0.80, h * 0.68, w * 0.68, h * 0.68)
        ..close(),
      paint,
    );
  }

  @override
  bool shouldRepaint(_DovePainter old) => old.color != color;
}
