import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/kharis_theme.dart';
import 'k_layout.dart';

/// The look every form input shares: surface fill, 1px border, button
/// corners, at least 44 tall, a one-line error in the error role.
InputDecoration kFieldDecoration(
  BuildContext context, {
  String? hint,
  Widget? suffix,
}) {
  final k = context.k;
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(KRadius.button)),
        borderSide: BorderSide(color: color, width: width),
      );

  return InputDecoration(
    isDense: true,
    filled: true,
    fillColor: k.surface,
    hoverColor: kClear(k.surface),
    hintText: hint,
    hintStyle: KharisText.body.copyWith(color: k.muted),
    errorStyle: KharisText.caption.copyWith(color: k.error),
    errorMaxLines: 1,
    counterStyle: KharisText.caption.copyWith(color: k.muted),
    suffixIcon: suffix,
    suffixIconConstraints: const BoxConstraints(
      minWidth: KSize.touchMin,
      minHeight: KSize.touchMin,
    ),
    constraints: const BoxConstraints(minHeight: KSize.row),
    contentPadding: const EdgeInsets.symmetric(
      horizontal: KSpace.x3,
      vertical: KSpace.xl,
    ),
    border: border(k.border),
    enabledBorder: border(k.border),
    disabledBorder: border(k.border),
    focusedBorder: border(k.primaryText, KSize.outline),
    errorBorder: border(k.error),
    focusedErrorBorder: border(k.error, KSize.outline),
  );
}

/// A visible label above a form control. Screen readers get the label from
/// the control itself, so the text here is hidden from them.
class KFieldLabel extends StatelessWidget {
  const KFieldLabel({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Text(
            label,
            style: KharisText.itemTitle.copyWith(color: context.k.text),
          ),
        ),
        const SizedBox(height: KSpace.sm),
        Semantics(label: label, child: child),
      ],
    );
  }
}

/// A labelled text input validated with its [Form]. With [password] the text
/// is hidden and a Show / Hide control sits at the end of the field. With
/// [readOnly] and [onTap] it is a picker field (a date) that looks like the
/// others.
class KTextField extends StatefulWidget {
  const KTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.inputFormatters,
    this.onChanged,
    this.onFieldSubmitted,
    this.onTap,
    this.password = false,
    this.readOnly = false,
    this.autofocus = false,
    this.enabled = true,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.trailing,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final VoidCallback? onTap;
  final bool password;
  final bool readOnly;
  final bool autofocus;
  final bool enabled;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;

  /// Shown at the end of the field, for example a calendar [KIcon] on a date
  /// field. Ignored when [password] is set.
  final Widget? trailing;

  @override
  State<KTextField> createState() => _KTextFieldState();
}

class _KTextFieldState extends State<KTextField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final suffix = widget.password
        ? _RevealButton(
            hidden: _hidden,
            onTap: () => setState(() => _hidden = !_hidden),
          )
        : widget.trailing == null
        ? null
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: KSpace.xl),
            child: Center(widthFactor: 1, child: widget.trailing),
          );

    return KFieldLabel(
      label: widget.label,
      child: TextFormField(
        controller: widget.controller,
        validator: widget.validator,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        textCapitalization: widget.textCapitalization,
        autofillHints: widget.autofillHints,
        inputFormatters: widget.inputFormatters,
        onChanged: widget.onChanged,
        onFieldSubmitted: widget.onFieldSubmitted,
        onTap: widget.onTap,
        obscureText: widget.password && _hidden,
        readOnly: widget.readOnly,
        autofocus: widget.autofocus,
        enabled: widget.enabled,
        maxLines: widget.password ? 1 : widget.maxLines,
        minLines: widget.minLines,
        maxLength: widget.maxLength,
        cursorColor: k.primaryText,
        style: KharisText.body.copyWith(color: k.text),
        decoration: kFieldDecoration(
          context,
          hint: widget.hint,
          suffix: suffix,
        ),
      ),
    );
  }
}

class _RevealButton extends StatelessWidget {
  const _RevealButton({required this.hidden, required this.onTap});

  final bool hidden;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: hidden ? 'Show password' : 'Hide password',
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(KRadius.button)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: KSize.touchMin,
            minHeight: KSize.touchMin,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: KSpace.xl),
            child: Center(
              widthFactor: 1,
              child: Text(
                hidden ? 'Show' : 'Hide',
                style: KharisText.link.copyWith(color: context.k.primaryText),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One line saying what went wrong with a form and what to do, in the error
/// role. Announced when it appears.
class KInlineError extends StatelessWidget {
  const KInlineError(this.message, {super.key, this.textAlign});

  final String message;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Text(
        message,
        textAlign: textAlign,
        style: KharisText.meta.copyWith(color: context.k.error),
      ),
    );
  }
}
