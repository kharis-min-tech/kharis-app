import 'package:flutter/material.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/playlists/data/playlist_repository.dart';

/// Prompts for a playlist name (create or rename). Returns the trimmed name,
/// or null when the member cancels. Enforces the same 1..80 bounds the
/// Firestore rules do, so an accepted name can never be rejected server-side.
Future<String?> showPlaylistNameDialog(
  BuildContext context, {
  required String title,
  String? initialName,
  String confirmLabel = 'Create',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _PlaylistNameDialog(
      title: title,
      initialName: initialName,
      confirmLabel: confirmLabel,
    ),
  );
}

class _PlaylistNameDialog extends StatefulWidget {
  const _PlaylistNameDialog({
    required this.title,
    required this.confirmLabel,
    this.initialName,
  });

  final String title;
  final String confirmLabel;
  final String? initialName;

  @override
  State<_PlaylistNameDialog> createState() => _PlaylistNameDialogState();
}

class _PlaylistNameDialogState extends State<_PlaylistNameDialog> {
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
      setState(() => _error = 'Give your playlist a name');
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.kc.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      title: Text(
        widget.title,
        style: AppTypography.display(
          size: 20,
          weight: FontWeight.w700,
          color: context.kc.onBg,
        ),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: kPlaylistNameMaxLength,
        textCapitalization: TextCapitalization.sentences,
        onSubmitted: (_) => _submit(),
        style: AppTypography.bodyLg.copyWith(color: context.kc.onBg),
        cursorColor: context.kc.accentInk,
        decoration: InputDecoration(
          hintText: 'e.g. Sunday drive, Faith builders…',
          hintStyle: AppTypography.bodySm.copyWith(color: context.kc.muted),
          errorText: _error,
          counterStyle: AppTypography.labelMd.copyWith(color: context.kc.muted),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: context.kc.divider),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: context.kc.accentInk, width: 1.5),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: AppTypography.ui(
              size: 14,
              weight: FontWeight.w600,
              color: context.kc.muted,
            ),
          ),
        ),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(
            backgroundColor: context.kc.accent,
            foregroundColor: context.kc.onAccent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.button),
            ),
          ),
          child: Text(
            widget.confirmLabel,
            style: AppTypography.ui(
              size: 14,
              weight: FontWeight.w700,
              color: context.kc.onAccent,
            ),
          ),
        ),
      ],
    );
  }
}
