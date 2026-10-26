// The 66-book Protestant canon with chapter counts, and a check that a
// Content Studio reading names only real books and chapters. Mirrors the
// app's `kCanonBooks` (app/lib/core/constants/bible_books.dart) and its
// reading parser (`parseReadingReferences` in bible_reference.dart), so a
// reference the backend accepts is one the app can open. Pure: no Firebase.

/** Canon name -> chapter count, in canonical order. */
export const BIBLE_CHAPTERS: ReadonlyArray<readonly [string, number]> = [
  ['Genesis', 50], ['Exodus', 40], ['Leviticus', 27], ['Numbers', 36],
  ['Deuteronomy', 34], ['Joshua', 24], ['Judges', 21], ['Ruth', 4],
  ['1 Samuel', 31], ['2 Samuel', 24], ['1 Kings', 22], ['2 Kings', 25],
  ['1 Chronicles', 29], ['2 Chronicles', 36], ['Ezra', 10], ['Nehemiah', 13],
  ['Esther', 10], ['Job', 42], ['Psalms', 150], ['Proverbs', 31],
  ['Ecclesiastes', 12], ['Song of Solomon', 8], ['Isaiah', 66], ['Jeremiah', 52],
  ['Lamentations', 5], ['Ezekiel', 48], ['Daniel', 12], ['Hosea', 14],
  ['Joel', 3], ['Amos', 9], ['Obadiah', 1], ['Jonah', 4], ['Micah', 7],
  ['Nahum', 3], ['Habakkuk', 3], ['Zephaniah', 3], ['Haggai', 2],
  ['Zechariah', 14], ['Malachi', 4],
  ['Matthew', 28], ['Mark', 16], ['Luke', 24], ['John', 21], ['Acts', 28],
  ['Romans', 16], ['1 Corinthians', 16], ['2 Corinthians', 13], ['Galatians', 6],
  ['Ephesians', 6], ['Philippians', 4], ['Colossians', 4],
  ['1 Thessalonians', 5], ['2 Thessalonians', 3], ['1 Timothy', 6],
  ['2 Timothy', 4], ['Titus', 3], ['Philemon', 1], ['Hebrews', 13], ['James', 5],
  ['1 Peter', 5], ['2 Peter', 3], ['1 John', 5], ['2 John', 1], ['3 John', 1],
  ['Jude', 1], ['Revelation', 22],
];

/** Other spellings of a canon name, written as normalised lookup keys. */
const ALIASES: Record<string, string> = {
  'psalm': 'Psalms',
  'ps': 'Psalms',
  'song of songs': 'Song of Solomon',
  'song': 'Song of Solomon',
  'canticles': 'Song of Solomon',
  'revelations': 'Revelation',
  'acts of the apostles': 'Acts',
};

/**
 * Lower case; "I Cor", "II Kings", "First John" become "1 cor", "2 kings",
 * "1 john"; "3.16" becomes "3:16"; dashes become '-'; spaces collapse and hug
 * ':' and '-'. The same steps as the app's `_normalize`.
 */
function normalize(input: string): string {
  let s = input.toLowerCase().trim();
  s = s.replace(/[\u2013\u2014]/g, '-');
  s = s.replace(/(\d)\s*\.\s*(\d)/g, '$1:$2');
  s = s.replace(/\./g, ' ');
  s = s.replace(/^(iii|3rd|third)\s+(?=[a-z])/, '3 ');
  s = s.replace(/^(ii|2nd|second)\s+(?=[a-z])/, '2 ');
  s = s.replace(/^(i|1st|first)\s+(?=[a-z])/, '1 ');
  s = s.replace(/(?<=[a-z])(?=\d)/g, ' ');
  s = s.replace(/(?<=\d)(?=[a-z])/g, ' ');
  s = s.replace(/\s+/g, ' ');
  s = s.replace(/\s*([:-])\s*/g, '$1');
  return s.trim();
}

const CHAPTERS_BY_KEY: ReadonlyMap<string, number> = (() => {
  const counts = new Map(BIBLE_CHAPTERS);
  const byKey = new Map<string, number>();
  for (const [name, chapters] of BIBLE_CHAPTERS) byKey.set(normalize(name), chapters);
  for (const [alias, name] of Object.entries(ALIASES)) byKey.set(alias, counts.get(name)!);
  return byKey;
})();

/** Chapter count of [book] ("Psalm", "II Corinthians", "Song of Songs"), or null. */
export function chapterCount(book: string): number | null {
  return CHAPTERS_BY_KEY.get(normalize(book)) ?? null;
}

const REFERENCE = /^((?:[1-3] )?[a-z][a-z ]*?)(?: ?(\d+)(?::(\d+)(?:-(\d+))?)?)?$/;
const BARE_NUMBERS = /^\d+(\s*[:.]\s*\d+(\s*[-\u2013]\s*\d+)?)?$/;

/** Why one passage of a reading is not a real place in the Bible, or null. */
function passageProblem(passage: string): string | null {
  const m = REFERENCE.exec(normalize(passage));
  if (!m) return `"${passage}" is not a reference`;
  const chapters = CHAPTERS_BY_KEY.get(m[1].trim());
  if (chapters === undefined) return `unknown book in "${passage}"`;
  if (m[2] === undefined) return null;
  const chapter = Number(m[2]);
  // "Jude 3": verse 3 of a one-chapter book, as the app reads it.
  if (chapters === 1 && m[3] === undefined && chapter >= 1) return null;
  if (chapter < 1 || chapter > chapters) {
    return `"${passage}": chapter ${chapter} is outside 1-${chapters}`;
  }
  if (m[3] !== undefined && Number(m[3]) < 1) return `"${passage}": no verse ${m[3]}`;
  if (m[4] !== undefined && Number(m[4]) < Number(m[3])) {
    return `"${passage}": the verse range runs backwards`;
  }
  return null;
}

/**
 * Why [reference] is not a list of real Bible passages, or null when every
 * passage names a canon book and a chapter that book has. Passages are split
 * like the app splits them (`;`, line breaks, " and "); a part that is only
 * numbers ("9:1-5") continues the previous passage's book.
 */
export function referenceProblem(reference: string): string | null {
  const parts = reference
    .split(/;|\n|\s+and\s+/i)
    .map((p) => p.trim())
    .filter((p) => p.length > 0);
  if (parts.length === 0) return 'no reference';
  let lastBook: string | null = null;
  for (const raw of parts) {
    const part: string = lastBook !== null && BARE_NUMBERS.test(raw) ? `${lastBook} ${raw}` : raw;
    const problem = passageProblem(part);
    if (problem) return problem;
    lastBook = /^(.*?)\s*\d+\s*([:.].*)?$/.exec(part)?.[1] ?? part;
  }
  return null;
}
