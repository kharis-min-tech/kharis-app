import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/shared/providers/admin_provider.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/notification_provider.dart';

/// Lets a signed-in user edit their display name, home branch and avatar.
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
  String? _branch;
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
    try {
      final photo = _photoController.text.trim();
      // Capture before the write so the FCM topic move knows what to leave.
      final previousBranch = ref.read(currentBranchProvider).valueOrNull;
      await ref.read(firebaseAuthRepositoryProvider).updateProfile(
            displayName: _nameController.text.trim(),
            branch: _branch,
            photoUrl: photo.isEmpty ? null : photo,
            phone: _phoneController.text.trim().isEmpty
                ? null
                : _phoneController.text.trim(),
            dob: _dob,
          );
      // Same shared code path as Switch Branch; a no-change save is a no-op.
      await ref.read(notificationServiceProvider).switchBranchTopic(
            from: previousBranch,
            to: _branch,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated')),
        );
        context.pop();
      }
    } on FirebaseException catch (e) {
      // Surface the real reason instead of a blind generic — a permission or
      // network failure reads very differently to the member.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save: ${e.message ?? e.code}'),
            backgroundColor: AppColors.errorContainer,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save. Please try again.'),
            backgroundColor: AppColors.errorContainer,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final branches = ref.watch(branchesProvider).valueOrNull ?? const [];
    final branchNames = branches.map((b) => b.name).toList();

    if (!_initialized && user != null) {
      _nameController.text = user.displayName;
      _photoController.text = user.photoUrl ?? '';
      _phoneController.text = user.phone ?? '';
      _dob = user.dob;
      _branch = (user.branch != null && branchNames.contains(user.branch))
          ? user.branch
          : null;
      _initialized = true;
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: context.kc.onBg),
        title: Text(
          'Edit Profile',
          style: AppTypography.display(size: 18, weight: FontWeight.w700)
              .copyWith(color: context.kc.onBg),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
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
                _BranchDropdown(
                  value: _branch,
                  names: branchNames,
                  onChanged: (v) => setState(() => _branch = v),
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
                        horizontal: 16, vertical: 15),
                    decoration: BoxDecoration(
                      color: context.kc.surface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      _dob == null
                          ? 'Add your birthday'
                          : '${_dob!.day.toString().padLeft(2, '0')}/'
                              '${_dob!.month.toString().padLeft(2, '0')}/'
                              '${_dob!.year}',
                      style: AppTypography.ui(size: 15).copyWith(
                        color:
                            _dob == null ? context.kc.muted : context.kc.onBg,
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
                      disabledBackgroundColor:
                          context.kc.accent.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
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
                            style: AppTypography.labelMd.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: context.kc.onAccent,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 8),
        child: Text(
          text,
          style: AppTypography.ui(size: 13, weight: FontWeight.w600)
              .copyWith(color: context.kc.onBg),
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
        hintStyle:
            AppTypography.ui(size: 15).copyWith(color: context.kc.muted),
        filled: true,
        fillColor: context.kc.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputBorder,
          borderSide: BorderSide(color: context.kc.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputBorder,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
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

class _BranchDropdown extends StatelessWidget {
  const _BranchDropdown({
    required this.value,
    required this.names,
    required this.onChanged,
  });

  final String? value;
  final List<String> names;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: context.kc.surface,
        borderRadius: AppRadius.inputBorder,
        border: Border.all(color: context.kc.outline),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          isExpanded: true,
          dropdownColor: context.kc.surface,
          hint: Text(
            'Select your branch',
            style: AppTypography.ui(size: 15).copyWith(color: context.kc.muted),
          ),
          icon: Icon(Icons.expand_more, color: context.kc.muted),
          style: AppTypography.ui(size: 15).copyWith(color: context.kc.onBg),
          items: [
            for (final name in names)
              DropdownMenuItem<String?>(value: name, child: Text(name)),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}
