import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:kharis_app/shared/models/user.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/widgets/branch_picker_sheet.dart';
import 'package:kharis_app/ui/components/components.dart';

/// Whether [user] has an editable member profile. Guests (anonymous
/// sessions) and signed-out sessions do not.
bool hasMemberProfile(User? user) =>
    user != null && user.role != 'guest' && user.email.isNotEmpty;

/// Lets a signed-in member edit their display name, avatar, phone and
/// birthday. The branch row opens the shared branch sheet, which persists
/// through [setActiveBranch] like every other branch change. Guests see a
/// sign-in prompt instead of a form that cannot save.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _photoController = TextEditingController();
  final _phoneController = TextEditingController();
  DateTime? _dob;
  bool _saving = false;
  bool _initialized = false;

  @override
  void dispose() {
    _nameController.dispose();
    _photoController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final k = context.k;
    SnackBar failure(String message) => SnackBar(
      content: Text(message, style: KharisText.body.copyWith(color: k.onError)),
      backgroundColor: k.error,
    );
    try {
      final photo = _photoController.text.trim();
      final phone = _phoneController.text.trim();
      await ref
          .read(firebaseAuthRepositoryProvider)
          .updateProfile(
            displayName: _nameController.text.trim(),
            photoUrl: photo.isEmpty ? null : photo,
            phone: phone.isEmpty ? null : phone,
            dob: _dob,
          );
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Profile updated')));
      context.pop();
    } on FirebaseException catch (e) {
      // Surface the real reason: a permission or network failure reads very
      // differently to the member.
      messenger.showSnackBar(failure('Could not save: ${e.message ?? e.code}'));
    } catch (_) {
      messenger.showSnackBar(failure('Could not save. Please try again.'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1920),
      lastDate: now,
      helpText: 'Date of birth',
    );
    if (picked != null) setState(() => _dob = picked);
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.valueOrNull;
    final branch = ref.watch(currentBranchProvider).valueOrNull;

    final Widget body;
    if (userAsync.isLoading && user == null) {
      body = const _FormSkeleton();
    } else if (!hasMemberProfile(user)) {
      body = const _SignInPrompt();
    } else {
      if (!_initialized) {
        final member = user!;
        _nameController.text = member.displayName;
        _photoController.text = member.photoUrl ?? '';
        _phoneController.text = member.phone ?? '';
        _dob = member.dob;
        _initialized = true;
      }
      body = _form(branch);
    }

    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: KSize.maxContentWidth),
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(
                top: KSpace.md,
                bottom: KSize.contentBottomPad,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const KScreenHeader(title: 'Edit profile'),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      KSpace.gutter,
                      KSpace.x3,
                      KSpace.gutter,
                      0,
                    ),
                    child: body,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _form(String? branch) {
    final k = context.k;
    final dob = _dob;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KTextField(
            label: 'Display name',
            controller: _nameController,
            hint: 'Your name',
            textCapitalization: TextCapitalization.words,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
          ),
          const SizedBox(height: KSpace.gutter),
          KFieldLabel(
            label: 'Home branch',
            child: KListGroup(
              children: [
                KListRow(
                  key: const ValueKey('profile-campus-row'),
                  title: branch ?? kChooseBranchLabel,
                  trailing: Text(
                    'Change',
                    style: KharisText.link.copyWith(color: k.primaryText),
                  ),
                  onTap: () => pickActiveBranch(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: KSpace.gutter),
          KTextField(
            label: 'Avatar image URL (optional)',
            controller: _photoController,
            hint: 'https://...',
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: KSpace.gutter),
          KTextField(
            label: 'Phone (optional)',
            controller: _phoneController,
            hint: '+44 ...',
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: KSpace.gutter),
          KFieldLabel(
            label: 'Birthday (optional)',
            child: KListGroup(
              children: [
                KListRow(
                  key: const ValueKey('profile-birthday-row'),
                  title: dob == null
                      ? 'Add your birthday'
                      : DateFormat('d MMMM y').format(dob),
                  showChevron: true,
                  onTap: _pickBirthday,
                ),
              ],
            ),
          ),
          const SizedBox(height: KSpace.section),
          KButton(
            label: 'Save changes',
            expand: true,
            loading: _saving,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}

/// Field-sized blocks while the member's profile loads.
class _FormSkeleton extends StatelessWidget {
  const _FormSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 5; i++) ...[
          if (i > 0) const SizedBox(height: KSpace.gutter),
          const KSkeleton(height: KSize.listRow),
        ],
      ],
    );
  }
}

/// Shown to guests and signed-out sessions: there is no member profile to
/// edit, so offer the way to get one.
class _SignInPrompt extends StatelessWidget {
  const _SignInPrompt();

  @override
  Widget build(BuildContext context) {
    return KEmptyState(
      icon: KIcons.users,
      title: 'Sign in to edit your profile',
      hint: 'Your name, photo and details are saved to your Kharis account.',
      action: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KButton(
            label: 'Sign in',
            expand: true,
            onPressed: () => context.push('/login'),
          ),
          const SizedBox(height: KSpace.md),
          KButton(
            label: 'Create an account',
            variant: KButtonVariant.text,
            expand: true,
            onPressed: () => context.push('/register'),
          ),
        ],
      ),
    );
  }
}
