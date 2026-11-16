import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kharis_app/features/connect/data/connect_repository.dart';
import 'package:kharis_app/features/connect/presentation/widgets/connect_form_widgets.dart';
import 'package:kharis_app/ui/components/components.dart';

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

  String? _selectedBranch;
  DateTime _firstVisitDate = DateTime.now();
  _FormState _state = _FormState.form;
  String? _error;

  @override
  void initState() {
    super.initState();
    _dateController.text = _formatDate(_firstVisitDate);
  }

  static String _formatDate(DateTime date) =>
      DateFormat('d MMMM yyyy').format(date);

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
    );
    if (picked != null) {
      setState(() {
        _firstVisitDate = picked;
        _dateController.text = _formatDate(picked);
      });
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _state = _FormState.sending;
      _error = null;
    });
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
        setState(() {
          _state = _FormState.form;
          _error = 'Your details were not sent. Please try again later.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConnectFormPage(
      child: _state == _FormState.success
          ? const ConnectFormSuccess(
              title: 'Welcome to Kharis',
              hint: 'Someone from your branch will be in touch soon.',
            )
          : _buildForm(),
    );
  }

  Widget _buildForm() {
    final error = _error;
    return ConnectFormBody(
      formKey: _formKey,
      title: 'New here?',
      subtitle: 'We would love to get to know you',
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
          controller: _phoneController,
          label: 'Phone number',
          hint: 'Optional',
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: KSpace.x3),
        KTextField(
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
        const SizedBox(height: KSpace.x3),
        ConnectBranchDropdown(
          label: 'Branch',
          value: _selectedBranch,
          onChanged: (v) => setState(() => _selectedBranch = v),
        ),
        const SizedBox(height: KSpace.x3),
        KTextField(
          controller: _dateController,
          label: 'First visit date',
          readOnly: true,
          onTap: _pickDate,
          trailing: KIcon(KIcons.calendar, color: context.k.muted),
        ),
        const SizedBox(height: KSpace.section),
        if (error != null) ...[
          KInlineError(error),
          const SizedBox(height: KSpace.xl),
        ],
        KButton(
          label: 'Connect with us',
          size: KButtonSize.cta,
          expand: true,
          loading: _state == _FormState.sending,
          onPressed: _submit,
        ),
      ],
    );
  }
}
