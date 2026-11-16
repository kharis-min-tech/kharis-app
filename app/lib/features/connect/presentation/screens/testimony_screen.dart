import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kharis_app/features/connect/data/connect_repository.dart';
import 'package:kharis_app/features/connect/presentation/widgets/connect_form_widgets.dart';
import 'package:kharis_app/shared/providers/admin_provider.dart';
import 'package:kharis_app/ui/components/components.dart';

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

  String? _selectedBranch;
  String? _category;
  bool _anonymous = false;
  _FormState _state = _FormState.form;
  String? _error;

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
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final branches = ref.read(branchesProvider).valueOrNull ?? const [];
    final branch = branches.where((b) => b.name == _selectedBranch).firstOrNull;
    if (branch == null) return;
    setState(() {
      _state = _FormState.sending;
      _error = null;
    });
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
        setState(() {
          _state = _FormState.form;
          _error = 'Your testimony was not sent. Please try again later.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConnectFormPage(
      child: _state == _FormState.success
          ? const ConnectFormSuccess(
              title: 'Thank you for sharing',
              hint: 'Our team reviews every testimony.',
            )
          : _buildForm(),
    );
  }

  Widget _buildForm() {
    final error = _error;
    return ConnectFormBody(
      formKey: _formKey,
      title: 'Share your testimony',
      subtitle: 'Tell us what God has done',
      children: [
        KTextField(
          controller: _nameController,
          label: 'Full name *',
          hint: 'Your name',
          textInputAction: TextInputAction.next,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Name is required';
            return null;
          },
        ),
        const SizedBox(height: KSpace.x3),
        KTextField(
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
        const SizedBox(height: KSpace.x3),
        KTextField(
          controller: _phoneController,
          label: 'Phone number',
          hint: 'Optional',
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: KSpace.x3),
        ConnectBranchDropdown(
          label: 'Branch *',
          value: _selectedBranch,
          onChanged: (v) => setState(() => _selectedBranch = v),
          validator: (v) => v == null ? 'Branch is required' : null,
        ),
        const SizedBox(height: KSpace.x3),
        KSelectField(
          label: 'Category',
          hint: 'Choose a category',
          items: kTestimonyCategories,
          value: _category,
          onChanged: (v) => setState(() => _category = v),
        ),
        const SizedBox(height: KSpace.x3),
        KTextField(
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
        const SizedBox(height: KSpace.md),
        KTextField(
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
        const SizedBox(height: KSpace.md),
        _ConsentField(
          anonymous: _anonymous,
          onAnonymousChanged: (v) => setState(() => _anonymous = v),
          validator: (agreed) =>
              agreed ? null : 'Please confirm we may share your testimony',
        ),
        const SizedBox(height: KSpace.section),
        if (error != null) ...[
          KInlineError(error),
          const SizedBox(height: KSpace.xl),
        ],
        KButton(
          label: 'Share testimony',
          size: KButtonSize.cta,
          expand: true,
          loading: _state == _FormState.sending,
          onPressed: _submit,
        ),
      ],
    );
  }
}

/// The two choices about sharing, in one card: the anonymous switch, and the
/// required consent tick, which validates with the form.
class _ConsentField extends StatelessWidget {
  const _ConsentField({
    required this.anonymous,
    required this.onAnonymousChanged,
    required this.validator,
  });

  final bool anonymous;
  final ValueChanged<bool> onAnonymousChanged;
  final String? Function(bool agreed) validator;

  @override
  Widget build(BuildContext context) {
    return FormField<bool>(
      initialValue: false,
      validator: (v) => validator(v ?? false),
      builder: (state) {
        final agreed = state.value ?? false;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KListGroup(
              children: [
                _ChoiceRow(
                  title: 'Share anonymously',
                  subtitle: 'Your name is not shown if it is published',
                  onTap: () => onAnonymousChanged(!anonymous),
                  control: KSwitch(
                    value: anonymous,
                    onChanged: onAnonymousChanged,
                  ),
                ),
                _ChoiceRow(
                  title: 'I am happy for Kharis to share my testimony',
                  subtitle:
                      'In services, in the app and online, after our team '
                      'reviews it',
                  onTap: () => state.didChange(!agreed),
                  control: _Tick(
                    checked: agreed,
                    onTap: () => state.didChange(!agreed),
                  ),
                ),
              ],
            ),
            if (state.hasError) ...[
              const SizedBox(height: KSpace.sm),
              KInlineError(state.errorText!),
            ],
          ],
        );
      },
    );
  }
}

/// A row with a title that wraps, a line under it and a switch or tick at
/// the end. Tapping anywhere on the row changes the control, and the row
/// reads as one item.
class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.control,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget control;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return MergeSemantics(
      child: InkWell(
        onTap: onTap,
        excludeFromSemantics: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: KSize.listRow),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: KSpace.x3,
              vertical: KSpace.xl,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: KharisText.itemTitle.copyWith(color: k.text),
                      ),
                      const SizedBox(height: KSpace.xxs),
                      Text(
                        subtitle,
                        style: KharisText.meta.copyWith(color: k.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: KSpace.xl),
                control,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A tick box: an empty outlined square, or a filled one with a tick, so the
/// state never rests on colour alone. Exposed to screen readers as checked
/// or not.
class _Tick extends StatelessWidget {
  const _Tick({required this.checked, required this.onTap});

  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Semantics(
      checked: checked,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: checked ? k.primary : k.surface,
          borderRadius: const BorderRadius.all(Radius.circular(KRadius.xs)),
          border: Border.all(
            color: checked ? k.primary : k.muted,
            width: KSize.outline,
          ),
        ),
        child: SizedBox.square(
          dimension: KSize.radio,
          child: checked
              ? Center(
                  child: KIcon(
                    KIcons.check,
                    size: KSize.iconSm,
                    color: k.onPrimary,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
