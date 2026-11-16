// Golden and behaviour tests for the form components: KTextField (with
// KFieldLabel, KInlineError) and KSelectField, in light and dark at 100% and
// 200% text size, at the 390 design width. Regenerate after an intended
// visual change:
//
//     flutter test --no-pub --update-goldens test/design_form_fields_goldens_test.dart
//
// As in design_component_goldens_test.dart, pixels are compared on macOS
// only; elsewhere each entry is still built, which catches overflow.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kharis_app/ui/components/components.dart';

import 'support/design_harness.dart';

const _goldenKey = ValueKey('design-golden');

Widget _padded(List<Widget> children) => Padding(
  padding: const EdgeInsets.all(KSpace.gutter),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final (i, child) in children.indexed) ...[
        if (i > 0) const SizedBox(height: KSpace.x3),
        child,
      ],
    ],
  ),
);

Widget _textFields() => Form(
  autovalidateMode: AutovalidateMode.always,
  child: _padded([
    const KTextField(label: 'Email', hint: 'you@example.com'),
    KTextField(
      label: 'Full name',
      controller: TextEditingController(text: 'Ama Mensah'),
    ),
    KTextField(
      label: 'Password',
      password: true,
      controller: TextEditingController(text: 'secret-pass'),
    ),
    KTextField(
      label: 'Confirm password',
      password: true,
      validator: (_) => 'Passwords do not match',
    ),
    const KTextField(
      label: 'Your testimony',
      hint: 'Tell us what God has done',
      maxLines: 4,
      maxLength: 500,
    ),
    const KTextField(
      label: 'Date of visit',
      hint: 'Choose a date',
      readOnly: true,
      trailing: KIcon(KIcons.calendar),
    ),
    const KInlineError('Something went wrong. Please try again.'),
  ]),
);

Widget _selectFields() => Form(
  autovalidateMode: AutovalidateMode.always,
  child: _padded([
    KSelectField(
      label: 'Branch',
      hint: 'Choose your branch',
      items: const ['Bristol', 'London', 'Manchester'],
      value: null,
      onChanged: (_) {},
    ),
    KSelectField(
      label: 'Branch',
      hint: 'Choose your branch',
      items: const ['Bristol', 'London', 'Manchester'],
      value: 'London',
      onChanged: (_) {},
    ),
    KSelectField(
      label: 'Category',
      hint: 'Choose a category',
      items: const ['Healing', 'Provision'],
      value: null,
      onChanged: (_) {},
      validator: (_) => 'Choose a category',
    ),
  ]),
);

void main() {
  setUpAll(loadDesignAssets);

  final entries = <String, Widget Function()>{
    'text_field': _textFields,
    'select_field': _selectFields,
  };

  for (final MapEntry(key: id, value: build) in entries.entries) {
    for (final dark in const [false, true]) {
      for (final scale in const [1.0, 2.0]) {
        final mode = dark ? 'dark' : 'light';
        final percent = (scale * 100).round();

        testWidgets('$id · $mode · $percent%', (tester) async {
          debugDisableShadows = false;
          try {
            await pumpDesign(
              tester,
              RepaintBoundary(
                key: _goldenKey,
                child: Builder(
                  builder: (context) =>
                      ColoredBox(color: context.k.bg, child: build()),
                ),
              ),
              dark: dark,
              textScale: scale,
            );

            // Let validation errors finish fading in.
            await tester.pump(const Duration(milliseconds: 400));
            expect(tester.takeException(), isNull);
            if (Platform.isMacOS) {
              await expectLater(
                find.byKey(_goldenKey),
                matchesGoldenFile('goldens/${id}_${mode}_$percent.png'),
              );
            }
          } finally {
            debugDisableShadows = true;
          }
        });
      }
    }
  }

  testWidgets('a text field is at least 44 tall and announces its label', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpDesign(
      tester,
      _padded([const KTextField(label: 'Email', hint: 'you@example.com')]),
      dark: false,
    );

    expect(
      tester.getSize(find.byType(TextFormField)).height,
      greaterThanOrEqualTo(KSize.row),
    );
    expect(find.bySemanticsLabel(RegExp('Email')), findsOneWidget);
    handle.dispose();
  });

  testWidgets('a password field hides its text until Show is tapped', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpDesign(
      tester,
      _padded([const KTextField(label: 'Password', password: true)]),
      dark: false,
    );
    bool hidden() =>
        tester.widget<EditableText>(find.byType(EditableText)).obscureText;

    expect(hidden(), isTrue);
    expect(
      tester.getSize(find.bySemanticsLabel('Show password')).height,
      greaterThanOrEqualTo(KSize.touchMin),
    );

    await tester.tap(find.bySemanticsLabel('Show password'));
    await tester.pump();
    expect(hidden(), isFalse);

    await tester.tap(find.bySemanticsLabel('Hide password'));
    await tester.pump();
    expect(hidden(), isTrue);
    handle.dispose();
  });

  testWidgets('a field shows its validation error on one line', (tester) async {
    final formKey = GlobalKey<FormState>();
    await pumpDesign(
      tester,
      Form(
        key: formKey,
        child: _padded([
          KTextField(
            label: 'Email',
            validator: (v) => (v ?? '').isEmpty ? 'Email is required' : null,
          ),
        ]),
      ),
      dark: true,
    );

    expect(formKey.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Email is required'), findsOneWidget);
  });

  testWidgets('a select field reports the chosen item', (tester) async {
    String? chosen;
    await pumpDesign(
      tester,
      _padded([
        KSelectField(
          label: 'Branch',
          hint: 'Choose your branch',
          items: const ['Bristol', 'London'],
          value: null,
          onChanged: (v) => chosen = v,
        ),
      ]),
      dark: false,
    );

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('London').last);
    await tester.pumpAndSettle();
    expect(chosen, 'London');
  });
}
