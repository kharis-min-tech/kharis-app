import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/connect/data/connect_repository.dart';
import 'package:kharis_app/features/connect/presentation/widgets/connect_form_widgets.dart';
import 'package:kharis_app/shared/widgets/press_effect.dart';
import 'package:kharis_app/shared/widgets/shake_effect.dart';

enum _FormState { form, sending, success }

class NewHereScreen extends ConsumerStatefulWidget {
  const NewHereScreen({super.key});

  @override
  ConsumerState<NewHereScreen> createState() => _NewHereScreenState();
}

class _NewHereScreenState extends ConsumerState<NewHereScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _dateController = TextEditingController();
  final _shakeKey = GlobalKey<ShakeEffectState>();

  String? _selectedBranch;
  DateTime _firstVisitDate = DateTime.now();
  _FormState _state = _FormState.form;

  @override
  void initState() {
    super.initState();
    _dateController.text = _formatDate(_firstVisitDate);
  }

  static String _formatDate(DateTime date) =>
      DateFormat('dd MMM yyyy').format(date);

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _dateController.dispose();
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
            primary: context.kc.accentInk,
            surface: context.kc.surfaceAlt,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _firstVisitDate = picked;
        _dateController.text = _formatDate(picked);
      });
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      _shakeKey.currentState?.shake();
      return;
    }
    setState(() => _state = _FormState.sending);
    try {
      await ref
          .read(connectRepositoryProvider)
          .submitVisitor(
            VisitorSubmission(
              name: _nameController.text.trim(),
              phone: _phoneController.text.trim(),
              email: _emailController.text.trim(),
              branchName: _selectedBranch,
              firstVisitDate: _firstVisitDate,
            ),
          );
      if (mounted) setState(() => _state = _FormState.success);
    } catch (_) {
      if (mounted) {
        setState(() => _state = _FormState.form);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Your details were not sent. Please try again later.',
            ),
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
          icon: Icon(Icons.arrow_back_ios, color: context.kc.onBg, size: 20),
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
            Icon(Icons.check_circle, color: context.kc.accentInk, size: 56),
            const SizedBox(height: 24),
            Text(
              'Welcome to Kharis',
              textAlign: TextAlign.center,
              style: AppTypography.display(
                size: 22,
                weight: FontWeight.w700,
                color: context.kc.onBg,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Someone from your branch will be in touch soon.',
              textAlign: TextAlign.center,
              style: AppTypography.ui(size: 15, color: context.kc.muted),
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.kc.accent,
                  foregroundColor: context.kc.onAccent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Done',
                  style: AppTypography.ui(size: 14, weight: FontWeight.w700),
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
                'New here?',
                style: AppTypography.display(
                  size: 28,
                  weight: FontWeight.w700,
                  color: context.kc.onBg,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'We would love to get to know you',
                style: AppTypography.ui(size: 15, color: context.kc.muted),
              ),
              const SizedBox(height: 28),

              ConnectFormField(
                controller: _nameController,
                label: 'Full name *',
                hint: 'Your name',
                textInputAction: TextInputAction.next,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Name is required';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ConnectFormField(
                controller: _phoneController,
                label: 'Phone number',
                hint: 'Optional',
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              ConnectFormField(
                controller: _emailController,
                label: 'Email address *',
                hint: 'you@example.com',
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Email is required';
                  final emailRe = RegExp(r'^[\w.+\-]+@[\w\-]+\.[a-zA-Z]{2,}$');
                  if (!emailRe.hasMatch(v.trim())) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ConnectBranchDropdown(
                label: 'Branch',
                value: _selectedBranch,
                onChanged: (v) => setState(() => _selectedBranch = v),
              ),
              const SizedBox(height: 16),
              ConnectFormField(
                controller: _dateController,
                label: 'First visit date',
                readOnly: true,
                onTap: _pickDate,
                suffixIcon: Icon(
                  Icons.calendar_today_outlined,
                  color: context.kc.muted,
                  size: 18,
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
                      elevation: 0,
                    ),
                    onPressed: _state == _FormState.sending ? null : _submit,
                    child: Text(
                      _state == _FormState.sending
                          ? 'Sending...'
                          : 'Connect with us',
                      style: AppTypography.ui(
                        size: 14,
                        weight: FontWeight.w700,
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
