import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/connect/data/connect_repository.dart';
import 'package:kharis_app/features/connect/presentation/widgets/connect_form_widgets.dart';
import 'package:kharis_app/shared/widgets/press_effect.dart';
import 'package:kharis_app/shared/widgets/shake_effect.dart';

enum _FormState { form, success }

class NewHereScreen extends StatefulWidget {
  const NewHereScreen({super.key});

  @override
  State<NewHereScreen> createState() => _NewHereScreenState();
}

class _NewHereScreenState extends State<NewHereScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _shakeKey = GlobalKey<ShakeEffectState>();

  String? _selectedBranch;
  DateTime _firstVisitDate = DateTime.now();
  _FormState _state = _FormState.form;

  final _repo = ConnectRepository();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _firstVisitDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: AppColors.primary,
                surface: context.kc.surfaceAlt,
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _firstVisitDate = picked);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      _shakeKey.currentState?.shake();
      return;
    }
    setState(() => _state = _FormState.success);
    try {
      await _repo.submitVisitor(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        branch: _selectedBranch ?? '',
        firstVisitDate: _firstVisitDate,
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
              'Welcome to the family!',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: context.kc.onBg,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your branch team will reach out soon.',
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
              'New Here?',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: context.kc.onBg,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'We would love to get to know you',
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

            // Phone
            ConnectFormField(
              controller: _phoneController,
              label: 'Phone Number',
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 14),

            // Email
            ConnectFormField(
              controller: _emailController,
              label: 'Email Address *',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email is required';
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

            // First visit date
            GestureDetector(
              onTap: _pickDate,
              child: AbsorbPointer(
                child: ConnectFormField(
                  controller: TextEditingController(
                    text: DateFormat('dd MMM yyyy').format(_firstVisitDate),
                  ),
                  label: 'First Visit Date',
                  suffixIcon: Icon(
                    Icons.calendar_today_outlined,
                    color: context.kc.muted,
                    size: 18,
                  ),
                ),
              ),
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
                    'CONNECT WITH US',
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
