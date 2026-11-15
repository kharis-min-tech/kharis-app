import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/features/home/data/bible_reference.dart';
import 'package:kharis_app/features/home/data/bible_repository.dart';
import 'package:kharis_app/shared/providers/bible_provider.dart';
import 'package:kharis_app/ui/components/components.dart';

/// Resolves what the member typed ("John 3:16", "Ps 23") against the reading
/// version's books.
///
/// Never waits on the version's book list: on a slow connection the search
/// would do nothing for up to a minute. The bundled 66-book table covers the
/// canon; the reader re-checks the chapter once the version's list lands.
ReferenceLookup lookUpReference(WidgetRef ref, String input) {
  final version = ref.read(selectedBibleProvider);
  final index =
      ref.read(bibleIndexProvider(version.id)).valueOrNull ??
      BibleIndex.bundled();
  return parseBibleReference(input, index);
}

/// The reader's search: a sheet with a reference field. Resolves to the
/// passage found, or null when the member closes it.
Future<BibleLocation?> showReferenceSearch(BuildContext context) =>
    showKBottomSheet<BibleLocation>(
      context: context,
      title: 'Go to a passage',
      builder: (_) => const ReferenceSearch(),
    );

/// A reference field with Go, explaining anything it cannot find.
class ReferenceSearch extends ConsumerStatefulWidget {
  const ReferenceSearch({super.key});

  @override
  ConsumerState<ReferenceSearch> createState() => _ReferenceSearchState();
}

class _ReferenceSearchState extends ConsumerState<ReferenceSearch> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    switch (lookUpReference(ref, _controller.text)) {
      case ReferenceFound(:final location):
        Navigator.of(context).pop(location);
      case ReferenceError(:final message):
        setState(() => _error = message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          KTextField(
            key: const Key('bible-search-field'),
            label: 'Book, chapter or verse',
            hint: 'John 3:16, Psalm 23, 1 Cor 13:4-7',
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.go,
            onFieldSubmitted: (_) => _submit(),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          if (error != null) ...[
            const SizedBox(height: KSpace.md),
            ReferenceSearchError(message: error),
          ],
          const SizedBox(height: KSpace.xl),
          KButton(
            key: const Key('bible-search-go'),
            label: 'Go to passage',
            expand: true,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

/// Why a reference could not be opened, read out as soon as it shows.
class ReferenceSearchError extends StatelessWidget {
  const ReferenceSearchError({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Text(
        message,
        key: const Key('bible-search-error'),
        style: KharisText.caption.copyWith(color: context.k.error),
      ),
    );
  }
}
