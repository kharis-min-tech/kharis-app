import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kharis_app/features/onboarding/data/branch_repository.dart';
import 'package:kharis_app/shared/providers/admin_provider.dart';
import 'package:kharis_app/ui/components/components.dart';

/// The page both connect forms sit on: no app bar and no back button (people
/// swipe back or use the system back), content centred on wide screens.
class ConnectFormPage extends StatelessWidget {
  const ConnectFormPage({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: KSize.maxContentWidth),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A connect form: the screen title, one line under it, then the fields and
/// the submit button in [children], validated together through [formKey].
class ConnectFormBody extends StatelessWidget {
  const ConnectFormBody({
    super.key,
    required this.formKey,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final GlobalKey<FormState> formKey;
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: KSpace.md, bottom: KSpace.section),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KScreenHeader(title: title),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                KSpace.gutter,
                KSpace.xs,
                KSpace.gutter,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    subtitle,
                    style: KharisText.body.copyWith(color: context.k.muted),
                  ),
                  const SizedBox(height: KSpace.gutter),
                  ...children,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What a connect form shows once it has been sent: a tick, a title, one
/// line and a Done button that closes the form.
class ConnectFormSuccess extends StatelessWidget {
  const ConnectFormSuccess({
    super.key,
    required this.title,
    required this.hint,
  });

  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Semantics(
          liveRegion: true,
          child: KEmptyState(
            icon: KIcons.check,
            title: title,
            hint: hint,
            action: KButton(
              label: 'Done',
              expand: true,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      ),
    );
  }
}

/// Branch picker for the connect forms: the Content Studio branches, by name.
class ConnectBranchDropdown extends ConsumerWidget {
  const ConnectBranchDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.validator,
  });

  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final names = [
      for (final b
          in ref.watch(branchesProvider).valueOrNull ?? const <Branch>[])
        b.name,
    ]..sort();
    return KSelectField(
      label: label,
      hint: 'Choose your branch',
      items: names,
      value: value,
      onChanged: onChanged,
      validator: validator,
    );
  }
}
