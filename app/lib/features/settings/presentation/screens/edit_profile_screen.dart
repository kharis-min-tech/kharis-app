import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/shared/models/user.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/widgets/branch_picker_sheet.dart';

/// Whether [user] has an editable member profile. Guests (anonymous
/// sessions) and signed-out sessions do not.
bool hasMemberProfile(User? user) =>
    user != null && user.role != 'guest' && user.email.isNotEmpty;

/// Lets a signed-in member edit their display name, avatar, phone and
/// birthday. The campus row opens the shared branch sheet, which persists
/// through [setActiveBranch] like every other campus change. Guests see a
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
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not save: ${e.message ?? e.code}'),
          backgroundColor: AppColors.errorContainer,
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not save. Please try again.'),
          backgroundColor: AppColors.errorContainer,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.valueOrNull;
    final branch = ref.watch(currentBranchProvider).valueOrNull;

    final Widget body;
    if (userAsync.isLoading && user == null) {
      body = Center(
        child: CircularProgressIndicator(
          color: context.kc.accentInk,
          strokeWidth: 2.4,
        ),
      );
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: context.kc.onBg),
        title: Text(
          'Edit profile',
          style: AppTypography.display(
            size: 18,
            weight: FontWeight.w700,
          ).copyWith(color: context.kc.onBg),
        ),
      ),
      body: SafeArea(top: false, child: body),
    );
  }

  Widget _form(String? branch) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Display name'),
            _field(
              controller: _nameController,
              hint: 'Your name',
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 20),
            _label('Home branch'),
            _CampusRow(
              label: branch ?? kAllCampusesLabel,
              onTap: () => pickActiveBranch(context, ref),
            ),
            const SizedBox(height: 20),
            _label('Avatar image URL (optional)'),
            _field(
              controller: _photoController,
              hint: 'https://...',
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 20),
            _label('Phone (optional)'),
            _field(
              controller: _phoneController,
              hint: '+44 ...',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 20),
            _label('Birthday (optional)'),
            GestureDetector(
              onTap: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate:
                      _dob ?? DateTime(now.year - 25, now.month, now.day),
                  firstDate: DateTime(1920),
                  lastDate: now,
                  helpText: 'Date of birth',
                );
                if (picked != null) setState(() => _dob = picked);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 15,
                ),
                decoration: BoxDecoration(
                  color: context.kc.surface,
                  borderRadius: AppRadius.inputBorder,
                  border: Border.all(color: context.kc.outline),
                ),
                child: Text(
                  _dob == null
                      ? 'Add your birthday'
                      : '${_dob!.day.toString().padLeft(2, '0')}/'
                            '${_dob!.month.toString().padLeft(2, '0')}/'
                            '${_dob!.year}',
                  style: AppTypography.ui(size: 15).copyWith(
                    color: _dob == null ? context.kc.muted : context.kc.onBg,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.kc.accent,
                  foregroundColor: context.kc.onAccent,
                  disabledBackgroundColor: context.kc.accent.withValues(
                    alpha: 0.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.pillBorder,
                  ),
                ),
                child: _saving
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: context.kc.onAccent,
                        ),
                      )
                    : Text(
                        'Save changes',
                        style: AppTypography.ui(
                          size: 15,
                          weight: FontWeight.w700,
                          color: context.kc.onAccent,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(left: 2, bottom: 8),
    child: Text(
      text,
      style: AppTypography.ui(
        size: 13,
        weight: FontWeight.w600,
      ).copyWith(color: context.kc.onBg),
    ),
  );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      style: AppTypography.ui(size: 15).copyWith(color: context.kc.onBg),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTypography.ui(size: 15).copyWith(color: context.kc.muted),
        filled: true,
        fillColor: context.kc.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputBorder,
          borderSide: BorderSide(color: context.kc.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputBorder,
          borderSide: BorderSide(color: context.kc.accentInk, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputBorder,
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputBorder,
          borderSide: const BorderSide(color: AppColors.danger, width: 1.4),
        ),
      ),
    );
  }
}

/// Campus row: shows the active campus and opens the shared branch sheet.
class _CampusRow extends StatelessWidget {
  const _CampusRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    return GestureDetector(
      key: const ValueKey('profile-campus-row'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: kc.surface,
          borderRadius: AppRadius.inputBorder,
          border: Border.all(color: kc.outline),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTypography.ui(size: 15).copyWith(color: kc.onBg),
              ),
            ),
            Text(
              'Change',
              style: AppTypography.ui(
                size: 13,
                weight: FontWeight.w600,
              ).copyWith(color: kc.onChip),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown to guests and signed-out sessions: there is no member profile to
/// edit, so offer the way to get one.
class _SignInPrompt extends StatelessWidget {
  const _SignInPrompt();

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_outline_rounded, size: 48, color: kc.muted),
            const SizedBox(height: 14),
            Text(
              'Sign in to edit your profile',
              textAlign: TextAlign.center,
              style: AppTypography.display(
                size: 20,
                weight: FontWeight.w700,
              ).copyWith(color: kc.onBg),
            ),
            const SizedBox(height: 8),
            Text(
              'Your name, photo and details are saved to your Kharis account.',
              textAlign: TextAlign.center,
              style: AppTypography.ui(
                size: 14,
                height: 1.45,
              ).copyWith(color: kc.muted),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => context.push('/login'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kc.accent,
                  foregroundColor: kc.onAccent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.pillBorder,
                  ),
                ),
                child: Text(
                  'Sign in',
                  style: AppTypography.ui(
                    size: 15,
                    weight: FontWeight.w700,
                    color: kc.onAccent,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.push('/register'),
              child: Text(
                'Create an account',
                style: AppTypography.ui(
                  size: 14,
                  weight: FontWeight.w600,
                ).copyWith(color: kc.accentInk),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
