import 'package:kharis_app/core/constants/bible_books.dart';
import 'package:kharis_app/features/home/data/bible_repository.dart';

/// Result of [parseBibleReference]: a place to go, or why there is none.
sealed class ReferenceLookup {
  const ReferenceLookup();
}

class ReferenceFound extends ReferenceLookup {
  const ReferenceFound(this.location);

  final BibleLocation location;
}

class ReferenceError extends ReferenceLookup {
  const ReferenceError(this.message);

  /// Member-facing explanation, e.g. "John has 21 chapters."
  final String message;
}

/// Common abbreviations on top of each canon name and USFM code (which are
/// always accepted). Keys are normalised: lower case, no full stops.
const Map<String, List<String>> _aliases = {
  'GEN': ['gen', 'ge', 'gn'],
  'EXO': ['ex', 'exod'],
  'LEV': ['le', 'lv'],
  'NUM': ['nu', 'nm', 'nb'],
  'DEU': ['deut', 'de', 'dt'],
  'JOS': ['josh', 'jsh'],
  'JDG': ['judg', 'jg', 'jdgs'],
  'RUT': ['rth', 'ru'],
  'EST': ['esth', 'es'],
  'JOB': ['jb'],
  'PSA': ['ps', 'psalm', 'pss', 'psm', 'pslm'],
  'PRO': ['prov', 'prv', 'pr'],
  'ECC': ['eccl', 'eccles', 'ec', 'qoh'],
  'SNG': ['song', 'song of songs', 'songs', 'sos', 'ss', 'canticles'],
  'ISA': ['is'],
  'JER': ['je', 'jr'],
  'LAM': ['la'],
  'EZK': ['ezek', 'eze'],
  'DAN': ['da', 'dn'],
  'HOS': ['ho'],
  'JOL': ['jl'],
  'AMO': ['am'],
  'OBA': ['obad', 'ob'],
  'JON': ['jnh'],
  'MIC': ['mc'],
  'NAM': ['nah', 'na'],
  'HAB': ['hb'],
  'ZEP': ['zeph', 'zp'],
  'HAG': ['hg'],
  'ZEC': ['zech', 'zc'],
  'MAL': ['ml'],
  'MAT': ['matt', 'mt'],
  'MRK': ['mk', 'mr'],
  'LUK': ['lk'],
  'JHN': ['jn', 'joh'],
  'ACT': ['ac'],
  'ROM': ['ro', 'rm'],
  'GAL': ['ga'],
  'EPH': ['ephes'],
  'PHP': ['phil', 'pp'],
  'COL': <String>[],
  'TIT': ['ti'],
  'PHM': ['philem', 'phlm', 'pm'],
  'HEB': <String>[],
  'JAS': ['jm', 'jms'],
  'JUD': ['jd'],
  'REV': ['re', 'rv', 'revelations', 'apocalypse'],
};

/// Short forms of the numbered books' names, prefixed with 1/2/3 at lookup.
const Map<String, List<String>> _numberedAliases = {
  'samuel': ['sam', 'sa', 'sm'],
  'kings': ['kgs', 'ki', 'kin'],
  'chronicles': ['chr', 'chron', 'ch'],
  'corinthians': ['cor', 'co'],
  'thessalonians': ['thess', 'thes', 'th'],
  'timothy': ['tim', 'ti', 'tm'],
  'peter': ['pet', 'pe', 'pt'],
  'john': ['jn', 'jhn', 'jo', 'joh'],
};

final Map<String, String> _canonLookup = _buildCanonLookup();

Map<String, String> _buildCanonLookup() {
  final lookup = <String, String>{};
  for (final b in kCanonBooks) {
    lookup[_normalize(b.name)] = b.usfm;
    lookup[_normalize(b.usfm)] = b.usfm;
    for (final a in _aliases[b.usfm] ?? const <String>[]) {
      lookup[a] = b.usfm;
    }
    final numbered = RegExp(r'^([1-3]) (.+)$').firstMatch(b.name);
    if (numbered != null) {
      final base = numbered.group(2)!.toLowerCase();
      for (final a in _numberedAliases[base] ?? const <String>[]) {
        lookup['${numbered.group(1)} $a'] = b.usfm;
      }
    }
  }
  return lookup;
}

/// Lower case; "1Cor", "I Cor", "First Corinthians" all become "1 cor";
/// "3.16" becomes "3:16"; spaces collapse and hug ':' and '-'.
String _normalize(String input) {
  var s = input.toLowerCase().trim();
  s = s.replaceAll(RegExp('[\u2013\u2014]'), '-');
  s = s.replaceAllMapped(RegExp(r'(\d)\s*\.\s*(\d)'), (m) => '${m[1]}:${m[2]}');
  s = s.replaceAll('.', ' ');
  s = s.replaceFirst(RegExp(r'^(iii|3rd|third)\s+(?=[a-z])'), '3 ');
  s = s.replaceFirst(RegExp(r'^(ii|2nd|second)\s+(?=[a-z])'), '2 ');
  s = s.replaceFirst(RegExp(r'^(i|1st|first)\s+(?=[a-z])'), '1 ');
  s = s.replaceAll(RegExp(r'(?<=[a-z])(?=\d)'), ' ');
  s = s.replaceAll(RegExp(r'(?<=\d)(?=[a-z])'), ' ');
  s = s.replaceAll(RegExp(r'\s+'), ' ');
  s = s.replaceAllMapped(RegExp(r'\s*([:\-])\s*'), (m) => m[1]!);
  return s.trim();
}

final _referenceRe = RegExp(
  r'^((?:[1-3] )?[a-z][a-z ]*?)(?: ?(\d+)(?::(\d+)(?:-(\d+))?)?)?$',
);

/// Outcome of matching a typed book name.
sealed class _BookMatch {}

class _Book extends _BookMatch {
  _Book(this.usfm);
  final String usfm;
}

class _Ambiguous extends _BookMatch {
  _Ambiguous(this.names);
  final List<String> names;
}

class _Unknown extends _BookMatch {}

_BookMatch _matchBook(String query, BibleIndex? index) {
  final canon = _canonLookup[query];
  if (canon != null) return _Book(canon);

  // The version's own titles for its books ("Psalm" in some versions).
  final extra = index?.books ?? const <BibleBook>[];
  for (final b in extra) {
    if (_normalize(b.title) == query || _normalize(b.usfm) == query) {
      return _Book(b.usfm);
    }
  }

  // A unique start of a name: "deu", "phili", "1 corin".
  final names = <String, String>{
    for (final b in kCanonBooks) _normalize(b.name): b.usfm,
    for (final b in extra) _normalize(b.title): b.usfm,
  };
  final hits = <String, String>{};
  for (final e in names.entries) {
    if (e.key.startsWith(query)) hits[e.value] = e.key;
  }
  if (hits.length == 1) return _Book(hits.keys.single);
  if (hits.length > 1) {
    return _Ambiguous([
      for (final usfm in hits.keys)
        index?.book(usfm)?.title ??
            kCanonBooks.firstWhere((b) => b.usfm == usfm).name,
    ]);
  }
  return _Unknown();
}

/// Resolves a book name as written in a daily reading or by a member
/// ("Psalms", "Psalm", "Song of Songs", "1 Cor") to its USFM code, or null.
String? resolveBookUsfm(String book, [BibleIndex? index]) {
  final match = _matchBook(_normalize(book), index);
  return match is _Book ? match.usfm : null;
}

/// Parses a typed reference: a book name or abbreviation, then optionally
/// `chapter`, `chapter:verse` or `chapter:verse-verse`.
///
/// Accepts "John 3:16", "Jn 3", "Psalm 23", "1 Cor 13:4-7", "1cor13",
/// "2 Corinthians 13", "Jude 3" (verse 3 of the only chapter). Checks the
/// book, chapter and verse against [index] (the selected version).
ReferenceLookup parseBibleReference(String input, BibleIndex index) {
  final text = _normalize(input);
  if (text.isEmpty) {
    return const ReferenceError('Type a reference, like John 3:16.');
  }
  final m = _referenceRe.firstMatch(text);
  if (m == null) {
    return ReferenceError(
      'We couldn\u2019t read \u201c${input.trim()}\u201d. '
      'Try a reference like John 3:16 or Psalm 23.',
    );
  }

  final bookText = m[1]!.trim();
  final match = _matchBook(bookText, index);
  switch (match) {
    case _Book(:final usfm):
      final book = index.book(usfm);
      if (book == null) {
        final name = kCanonBooks
            .where((b) => b.usfm == usfm)
            .map((b) => b.name)
            .firstOrNull;
        return ReferenceError(
          '${name ?? usfm} isn\u2019t in this translation. '
          'Try another version.',
        );
      }
      return _resolve(book, m[2], m[3], m[4]);
    case _Ambiguous(:final names):
      final shown = names.length > 5
          ? '${names.take(5).join(', ')} or another book'
          : '${names.take(names.length - 1).join(', ')} or ${names.last}';
      return ReferenceError(
        '\u201c${_display(input, bookText)}\u201d could be $shown. '
        'Type a little more of the name.',
      );
    case _Unknown():
      return ReferenceError(
        'We couldn\u2019t find a book called '
        '\u201c${_display(input, bookText)}\u201d.',
      );
  }
}

/// The book part as the member typed it, for error messages.
String _display(String input, String normalizedBook) {
  final typed = RegExp(r'^\s*(.*?)\s*\d*\s*([:.]\s*\d.*)?$').firstMatch(input);
  final raw = typed?.group(1)?.trim() ?? '';
  return raw.isEmpty ? normalizedBook : raw;
}

ReferenceLookup _resolve(
  BibleBook book,
  String? chapterText,
  String? verseText,
  String? verseEndText,
) {
  // Digits too long for an int name no chapter or verse in any book; the
  // checks below then explain the reference instead of the parse throwing.
  int number(String text) => int.tryParse(text) ?? 1 << 30;
  var chapter = chapterText == null ? book.chapters.first : number(chapterText);
  int? verseStart = verseText == null ? null : number(verseText);
  int? verseEnd = verseEndText == null ? null : number(verseEndText);

  // "Jude 3" means verse 3 of the only chapter.
  if (book.chapters.length == 1 &&
      verseStart == null &&
      chapter > 1 &&
      chapterText != null) {
    verseStart = chapter;
    chapter = book.chapters.single;
  }

  if (!book.hasChapter(chapter)) {
    final count = book.chapters.length;
    return ReferenceError(
      '${book.title} has $count chapter${count == 1 ? '' : 's'}.',
    );
  }
  if (verseStart == null) {
    return ReferenceFound(BibleLocation(book.usfm, chapter));
  }

  final last = book.verseCounts[chapter];
  if (verseStart < 1 || (last != null && verseStart > last)) {
    return ReferenceError(
      last == null
          ? 'There is no verse $verseStart in ${book.title} $chapter.'
          : '${book.title} $chapter has $last verses.',
    );
  }
  verseEnd ??= verseStart;
  if (verseEnd < verseStart) {
    return const ReferenceError(
      'That verse range runs backwards. Try something like John 3:16-18.',
    );
  }
  if (last != null && verseEnd > last) verseEnd = last;
  return ReferenceFound(
    BibleLocation(
      book.usfm,
      chapter,
      verseStart: verseStart,
      verseEnd: verseEnd,
    ),
  );
}

/// Every passage a Studio reading names, in order: "Romans 8:1-11; Psalm 23"
/// is two. Parts are split on `;`, line breaks and " and "; a part that is
/// only numbers ("9:1-5") continues the previous part's book. Parts that do
/// not parse are skipped.
List<BibleLocation> parseReadingReferences(String text, BibleIndex index) => [
  for (final part in _readingParts(text, index))
    if (part case ReferenceFound(:final location)) location,
];

/// Whether [text] names at least one passage and every passage it names is a
/// real book of [index] with a chapter (and verse) that book has. One bad
/// part ("Romans 8; 2 Corinthians 40") makes the whole reading invalid.
bool isValidReading(String text, BibleIndex index) {
  final parts = _readingParts(text, index);
  return parts.isNotEmpty && parts.every((p) => p is ReferenceFound);
}

/// [text]'s non-empty parts, each looked up in [index].
List<ReferenceLookup> _readingParts(String text, BibleIndex index) {
  final out = <ReferenceLookup>[];
  String? lastBook;
  for (final raw in text.split(
    RegExp(r';|\n|\s+and\s+', caseSensitive: false),
  )) {
    var part = raw.trim();
    if (part.isEmpty) continue;
    if (RegExp(r'^\d+(\s*[:.]\s*\d+(\s*[-–]\s*\d+)?)?$').hasMatch(part) &&
        lastBook != null) {
      part = '$lastBook $part';
    }
    final found = parseBibleReference(part, index);
    out.add(found);
    if (found is ReferenceFound) {
      lastBook = RegExp(
        r'^(.*?)\s*\d+\s*([:.].*)?$',
      ).firstMatch(part)?.group(1);
    }
  }
  return out;
}
