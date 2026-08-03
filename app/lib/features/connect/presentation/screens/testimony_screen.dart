import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/connect/data/connect_repository.dart';
import 'package:kharis_app/features/connect/presentation/widgets/connect_form_widgets.dart';
import 'package:kharis_app/shared/widgets/press_effect.dart';
import 'package:kharis_app/shared/widgets/shake_effect.dart';

enum _FormState { form, success }

class TestimonyScreen extends StatefulWidget {
  const TestimonyScreen({super.key});

  @override
  State<TestimonyScreen> createState() => _TestimonyScreenState();
}

class _TestimonyScreenState extends State<TestimonyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _testimonyController = TextEditingController();
  final _shakeKey = GlobalKey<ShakeEffectState>();

  String? _selectedBranch;
  _FormState _state = _FormState.form;

  final _repo = ConnectRepository();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _testimonyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      _shakeKey.currentState?.shake();
      return;
    }
    setState(() => _state = _FormState.success);
    try {
      await _repo.submitTestimony(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        branch: _selectedBranch ?? '',
        text: _testimonyController.text.trim(),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _state = _FormState.form);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Something went wrong. Please try again.'),
            backgroundColor: AppColors.errorContainer,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: context.kc.onBg,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: _state == _FormState.success ? _buildSuccess() : _buildForm(),
      ),
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: AppColors.primary, size: 56),
            const SizedBox(height: 24),
            Text(
              'Thank you for sharing!',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: context.kc.onBg,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Our team reviews every testimony.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                color: context.kc.muted,
              ),
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.kc.accent,
                  foregroundColor: context.kc.onAccent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Done',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Form(
        key: _formKey,
        child: ShakeEffect(
          key: _shakeKey,
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Share Your Testimony',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: context.kc.onBg,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tell us what God has done',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                color: context.kc.muted,
              ),
            ),
            const SizedBox(height: 28),

            // Name
            ConnectFormField(
              controller: _nameController,
              label: 'Full Name *',
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Name is required';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Email (optional, validated if non-empty)
            ConnectFormField(
              controller: _emailController,
              label: 'Email Address',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final emailRe = RegExp(r'^[\w.+\-]+@[\w\-]+\.[a-zA-Z]{2,}$');
                if (!emailRe.hasMatch(v.trim())) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Branch dropdown
            ConnectBranchDropdown(
              value: _selectedBranch,
              onChanged: (v) => setState(() => _selectedBranch = v),
            ),
            const SizedBox(height: 14),

            // Testimony text
            ConnectFormField(
              controller: _testimonyController,
              label: 'Your Testimony *',
              maxLines: 6,
              maxLength: 2000,
              textInputAction: TextInputAction.newline,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Please share your testimony';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),

            // Submit
            PressEffect(
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.kc.accent,
                    foregroundColor: context.kc.onAccent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _submit,
                  child: Text(
                    'SHARE TESTIMONY',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
          ),
        ),
      ),
    );
  }
}
