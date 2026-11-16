import 'package:flutter/material.dart';

import 'package:kharis_app/features/playlists/data/playlist_repository.dart';
import 'package:kharis_app/ui/components/components.dart';

/// Asks for a collection name (create or rename) in a bottom sheet. Returns
/// the trimmed name, or null when the member cancels. Enforces the same
/// 1..80 bounds the Firestore rules do, so an accepted name can never be
/// rejected server-side.
Future<String?> showPlaylistNameDialog(
  BuildContext context, {
  required String title,
  String? initialName,
  String confirmLabel = 'Create',
}) {
  return showKBottomSheet<String>(
    context: context,
    title: title,
    builder: (_) =>
        PlaylistNameSheet(initialName: initialName, confirmLabel: confirmLabel),
  );
}

/// The content of the name sheet: one field and one primary button.
class PlaylistNameSheet extends StatefulWidget {
  const PlaylistNameSheet({
    super.key,
    required this.confirmLabel,
    this.initialName,
  });

  final String confirmLabel;
  final String? initialName;

  @override
  State<PlaylistNameSheet> createState() => _PlaylistNameSheetState();
}

class _PlaylistNameSheetState extends State<PlaylistNameSheet> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give your collection a name');
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(KRadius.tile)),
          borderSide: BorderSide(color: color, width: width),
        );

    return Padding(
      // Lift the field and the button over the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              maxLength: kPlaylistNameMaxLength,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              style: KharisText.body.copyWith(color: k.text),
              cursorColor: k.primaryText,
              decoration: InputDecoration(
                hintText: 'Collection name',
                hintStyle: KharisText.body.copyWith(color: k.muted),
                errorText: _error,
                errorStyle: KharisText.caption.copyWith(color: k.error),
                counterStyle: KharisText.caption.copyWith(color: k.muted),
                filled: true,
                fillColor: k.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: KSpace.x3,
                  vertical: KSpace.xl,
                ),
                enabledBorder: border(k.line),
                focusedBorder: border(k.primaryText, KSize.outline),
                errorBorder: border(k.error),
                focusedErrorBorder: border(k.error, KSize.outline),
              ),
            ),
            const SizedBox(height: KSpace.xl),
            KButton(
              label: widget.confirmLabel,
              expand: true,
              onPressed: _submit,
            ),
            const SizedBox(height: KSpace.md),
            KButton(
              label: 'Cancel',
              variant: KButtonVariant.text,
              expand: true,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
