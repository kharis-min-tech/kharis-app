/// Maps human-readable Bible book names to USFM book codes used by the
/// YouVersion Platform passage endpoints (e.g. 'Psalms 23' -> 'PSA.23').
library;

const Map<String, String> _bookToUsfm = {
  'genesis': 'GEN', 'exodus': 'EXO', 'leviticus': 'LEV', 'numbers': 'NUM',
  'deuteronomy': 'DEU', 'joshua': 'JOS', 'judges': 'JDG', 'ruth': 'RUT',
  '1 samuel': '1SA', '2 samuel': '2SA', '1 kings': '1KI', '2 kings': '2KI',
  '1 chronicles': '1CH', '2 chronicles': '2CH', 'ezra': 'EZR',
  'nehemiah': 'NEH', 'esther': 'EST', 'job': 'JOB', 'psalm': 'PSA',
  'psalms': 'PSA', 'proverbs': 'PRO', 'ecclesiastes': 'ECC',
  'song of songs': 'SNG', 'song of solomon': 'SNG', 'isaiah': 'ISA',
  'jeremiah': 'JER', 'lamentations': 'LAM', 'ezekiel': 'EZK',
  'daniel': 'DAN', 'hosea': 'HOS', 'joel': 'JOL', 'amos': 'AMO',
  'obadiah': 'OBA', 'jonah': 'JON', 'micah': 'MIC', 'nahum': 'NAM',
  'habakkuk': 'HAB', 'zephaniah': 'ZEP', 'haggai': 'HAG',
  'zechariah': 'ZEC', 'malachi': 'MAL',
  'matthew': 'MAT', 'mark': 'MRK', 'luke': 'LUK', 'john': 'JHN',
  'acts': 'ACT', 'romans': 'ROM', '1 corinthians': '1CO',
  '2 corinthians': '2CO', 'galatians': 'GAL', 'ephesians': 'EPH',
  'philippians': 'PHP', 'colossians': 'COL', '1 thessalonians': '1TH',
  '2 thessalonians': '2TH', '1 timothy': '1TI', '2 timothy': '2TI',
  'titus': 'TIT', 'philemon': 'PHM', 'hebrews': 'HEB', 'james': 'JAS',
  '1 peter': '1PE', '2 peter': '2PE', '1 john': '1JN', '2 john': '2JN',
  '3 john': '3JN', 'jude': 'JUD', 'revelation': 'REV',
};

/// Converts a human reading reference to a USFM passage id.
///
/// Accepts 'Psalms 23', 'John 10', '1 Corinthians 13', 'Psalm 23:1-6'.
/// Returns null when the book cannot be resolved.
String? usfmPassageId(String book, String chapter, [String? verse]) {
  final code = _bookToUsfm[book.trim().toLowerCase()];
  if (code == null) return null;
  final ch = chapter.trim();
  if (verse != null && verse.trim().isNotEmpty) {
    // Verse ranges keep only the start verse for the passage id.
    final v = verse.split('-').first.trim();
    return '$code.$ch.$v';
  }
  return '$code.$ch';
}
