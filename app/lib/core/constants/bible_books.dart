/// The 66-book Protestant canon in order: USFM code (the YouVersion Platform
/// book id), English name and chapter count.
///
/// The one bundled source for book vocabulary: admin bounds (daily readings,
/// reading plans), the reader's offline book list and reference search all
/// read it, so names and chapter counts cannot drift between them.
library;

enum Testament { old, newTestament, other }

class CanonBook {
  const CanonBook(this.usfm, this.name, this.chapters, this.testament);

  final String usfm;
  final String name;
  final int chapters;
  final Testament testament;
}

const _ot = Testament.old;
const _nt = Testament.newTestament;

const kCanonBooks = <CanonBook>[
  CanonBook('GEN', 'Genesis', 50, _ot),
  CanonBook('EXO', 'Exodus', 40, _ot),
  CanonBook('LEV', 'Leviticus', 27, _ot),
  CanonBook('NUM', 'Numbers', 36, _ot),
  CanonBook('DEU', 'Deuteronomy', 34, _ot),
  CanonBook('JOS', 'Joshua', 24, _ot),
  CanonBook('JDG', 'Judges', 21, _ot),
  CanonBook('RUT', 'Ruth', 4, _ot),
  CanonBook('1SA', '1 Samuel', 31, _ot),
  CanonBook('2SA', '2 Samuel', 24, _ot),
  CanonBook('1KI', '1 Kings', 22, _ot),
  CanonBook('2KI', '2 Kings', 25, _ot),
  CanonBook('1CH', '1 Chronicles', 29, _ot),
  CanonBook('2CH', '2 Chronicles', 36, _ot),
  CanonBook('EZR', 'Ezra', 10, _ot),
  CanonBook('NEH', 'Nehemiah', 13, _ot),
  CanonBook('EST', 'Esther', 10, _ot),
  CanonBook('JOB', 'Job', 42, _ot),
  CanonBook('PSA', 'Psalms', 150, _ot),
  CanonBook('PRO', 'Proverbs', 31, _ot),
  CanonBook('ECC', 'Ecclesiastes', 12, _ot),
  CanonBook('SNG', 'Song of Solomon', 8, _ot),
  CanonBook('ISA', 'Isaiah', 66, _ot),
  CanonBook('JER', 'Jeremiah', 52, _ot),
  CanonBook('LAM', 'Lamentations', 5, _ot),
  CanonBook('EZK', 'Ezekiel', 48, _ot),
  CanonBook('DAN', 'Daniel', 12, _ot),
  CanonBook('HOS', 'Hosea', 14, _ot),
  CanonBook('JOL', 'Joel', 3, _ot),
  CanonBook('AMO', 'Amos', 9, _ot),
  CanonBook('OBA', 'Obadiah', 1, _ot),
  CanonBook('JON', 'Jonah', 4, _ot),
  CanonBook('MIC', 'Micah', 7, _ot),
  CanonBook('NAM', 'Nahum', 3, _ot),
  CanonBook('HAB', 'Habakkuk', 3, _ot),
  CanonBook('ZEP', 'Zephaniah', 3, _ot),
  CanonBook('HAG', 'Haggai', 2, _ot),
  CanonBook('ZEC', 'Zechariah', 14, _ot),
  CanonBook('MAL', 'Malachi', 4, _ot),
  CanonBook('MAT', 'Matthew', 28, _nt),
  CanonBook('MRK', 'Mark', 16, _nt),
  CanonBook('LUK', 'Luke', 24, _nt),
  CanonBook('JHN', 'John', 21, _nt),
  CanonBook('ACT', 'Acts', 28, _nt),
  CanonBook('ROM', 'Romans', 16, _nt),
  CanonBook('1CO', '1 Corinthians', 16, _nt),
  CanonBook('2CO', '2 Corinthians', 13, _nt),
  CanonBook('GAL', 'Galatians', 6, _nt),
  CanonBook('EPH', 'Ephesians', 6, _nt),
  CanonBook('PHP', 'Philippians', 4, _nt),
  CanonBook('COL', 'Colossians', 4, _nt),
  CanonBook('1TH', '1 Thessalonians', 5, _nt),
  CanonBook('2TH', '2 Thessalonians', 3, _nt),
  CanonBook('1TI', '1 Timothy', 6, _nt),
  CanonBook('2TI', '2 Timothy', 4, _nt),
  CanonBook('TIT', 'Titus', 3, _nt),
  CanonBook('PHM', 'Philemon', 1, _nt),
  CanonBook('HEB', 'Hebrews', 13, _nt),
  CanonBook('JAS', 'James', 5, _nt),
  CanonBook('1PE', '1 Peter', 5, _nt),
  CanonBook('2PE', '2 Peter', 3, _nt),
  CanonBook('1JN', '1 John', 5, _nt),
  CanonBook('2JN', '2 John', 1, _nt),
  CanonBook('3JN', '3 John', 1, _nt),
  CanonBook('JUD', 'Jude', 1, _nt),
  CanonBook('REV', 'Revelation', 22, _nt),
];

/// Book name -> chapter count, for the admin bounds and daily-reading checks.
final Map<String, int> kBibleBooks = {
  for (final b in kCanonBooks) b.name: b.chapters,
};
