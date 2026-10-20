import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/connect/data/connect_repository.dart';
import 'package:kharis_app/features/connect/presentation/widgets/connect_form_widgets.dart';
import 'package:kharis_app/shared/providers/admin_provider.dart';
import 'package:kharis_app/shared/widgets/press_effect.dart';
import 'package:kharis_app/shared/widgets/shake_effect.dart';

enum _FormState { form, sending, success }

/// "Share a testimony": the website's testimony form (kharis.org → Elvanto)
/// mapped onto the Studio `testimonies` columns. Submissions land
/// unpublished for review. The website's sharing question is a required
/// consent here: the app only collects testimonies the team may share.
class TestimonyScreen extends ConsumerStatefulWidget {
  const TestimonyScreen({super.key});

  @override
  ConsumerState<TestimonyScreen> createState() => _TestimonyScreenState();
}

class _TestimonyScreenState extends ConsumerState<TestimonyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _summaryController = TextEditingController();
  final _testimonyController = TextEditingController();
  final _shakeKey = GlobalKey<ShakeEffectState>();

  String? _selectedBranch;
  String? _category;
  bool _anonymous = false;
  _FormState _state = _FormState.form;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _summaryController.dispose();
    _testimonyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      _shakeKey.currentState?.shake();
      return;
    }
    final branches = ref.read(branchesProvider).valueOrNull ?? const [];
    final branch = branches.where((b) => b.name == _selectedBranch).firstOrNull;
    if (branch == null) {
      _shakeKey.currentState?.shake();
      return;
    }
    setState(() => _state = _FormState.sending);
    try {
      await ref
          .read(connectRepositoryProvider)
          .submitTestimony(
            TestimonySubmission(
              name: _nameController.text.trim(),
              email: _emailController.text.trim(),
              phone: _phoneController.text.trim(),
              branch: branch,
              category: _category,
              summary: _summaryController.text.trim(),
              testimony: _testimonyController.text.trim(),
              anonymous: _anonymous,
            ),
          );
      if (mounted) setState(() => _state = _FormState.success);
    } catch (_) {
      if (mounted) {
        setState(() => _state = _FormState.form);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Your testimony was not sent. Please try again later.',
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
              'Thank you for sharing',
              textAlign: TextAlign.center,
              style: AppTypography.display(
                size: 22,
                weight: FontWeight.w700,
                color: context.kc.onBg,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Our team reviews every testimony.',
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
                'Share your testimony',
                style: AppTypography.display(
                  size: 28,
                  weight: FontWeight.w700,
                  color: context.kc.onBg,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tell us what God has done',
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
                controller: _emailController,
                label: 'Email address',
                hint: 'Optional',
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final emailRe = RegExp(r'^[\w.+\-]+@[\w\-]+\.[a-zA-Z]{2,}$');
                  if (!emailRe.hasMatch(v.trim())) return 'Enter a valid email';
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
              ConnectBranchDropdown(
                label: 'Branch *',
                value: _selectedBranch,
                onChanged: (v) => setState(() => _selectedBranch = v),
                validator: (v) => v == null ? 'Branch is required' : null,
              ),
              const SizedBox(height: 16),
              ConnectDropdownField(
                label: 'Category',
                hint: 'Choose a category',
                items: kTestimonyCategories,
                value: _category,
                onChanged: (v) => setState(() => _category = v),
              ),
              const SizedBox(height: 16),
              ConnectFormField(
                controller: _summaryController,
                label: 'Short title / summary *',
                hint: 'e.g. Healed after surgery',
                maxLength: kTestimonySummaryMaxLength,
                textInputAction: TextInputAction.next,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Add a short title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              ConnectFormField(
                controller: _testimonyController,
                label: 'Your testimony *',
                hint: 'Tell us what God has done',
                maxLines: 6,
                maxLength: kTestimonyMaxLength,
                textInputAction: TextInputAction.newline,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Please share your testimony';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                value: _anonymous,
                onChanged: (v) => setState(() => _anonymous = v),
                activeTrackColor: context.kc.accent,
                title: Text(
                  'Share anonymously',
                  style: AppTypography.ui(
                    size: 15,
                    weight: FontWeight.w600,
                    color: context.kc.onBg,
                  ),
                ),
                subtitle: Text(
                  'Your name is not shown if it is published',
                  style: AppTypography.ui(size: 13, color: context.kc.muted),
                ),
              ),
              _ConsentField(
                title: 'I am happy for Kharis to share my testimony',
                subtitle:
                    'In services, in the app and online, after our team '
                    'reviews it',
                validator: (agreed) => agreed
                    ? null
                    : 'Please confirm we may share your testimony',
              ),
              const SizedBox(height: 24),

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
                          : 'Share testimony',
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

/// A required tick box that validates with the form, styled like the
/// anonymous switch above it.
class _ConsentField extends StatelessWidget {
  const _ConsentField({
    required this.title,
    required this.subtitle,
    required this.validator,
  });

  final String title;
  final String subtitle;
  final String? Function(bool agreed) validator;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    return FormField<bool>(
      initialValue: false,
      validator: (v) => validator(v ?? false),
      builder: (state) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CheckboxListTile.adaptive(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            controlAffinity: ListTileControlAffinity.trailing,
            value: state.value ?? false,
            onChanged: (v) => state.didChange(v ?? false),
            activeColor: kc.accent,
            checkColor: kc.onAccent,
            title: Text(
              title,
              style: AppTypography.ui(
                size: 15,
                weight: FontWeight.w600,
                color: kc.onBg,
              ),
            ),
            subtitle: Text(
              subtitle,
              style: AppTypography.ui(size: 13, color: kc.muted),
            ),
          ),
          if (state.hasError)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                state.errorText!,
                style: AppTypography.ui(size: 12, color: kc.danger),
              ),
            ),
        ],
      ),
    );
  }
}
