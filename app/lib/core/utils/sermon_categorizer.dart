/// Topic categorization for sermons.
///
/// Single source of truth for the Messages topic rail, the API and Firestore
/// mappers and the admin category picker. Every sermon lands in exactly one
/// topic: the bucket whose keywords hit the title most often wins, the
/// description breaks ties, and bucket order breaks whatever is left. A sermon
/// that matches nothing goes to [kOtherCategory], so the topic counts always
/// add up to the size of the library.
///
/// The keyword table was tuned against the full public archive (1,489 sermons,
/// 2013 to 2026): about 99% of sermons land in a named topic.
library;

/// Catch-all topic for sermons no keyword matches.
const String kOtherCategory = 'Other';

/// Display order for the topic rail and the admin picker. 'All' first, the
/// catch-all last.
const List<String> kSermonCategories = [
  'All',
  'Prayer & Fasting',
  'Healing & Wholeness',
  'Parenting & Children',
  'Marriage & Family',
  'Holy Spirit',
  'Revival & Anointing',
  'Worship & Presence',
  'Grace & Salvation',
  'Church & Leadership',
  'Purpose & Mission',
  'Giving & Stewardship',
  'Faith & Growth',
  'Seasonal',
  'Testimonies',
  'Bible Study',
  'Knowing God',
  kOtherCategory,
];

/// The topic labels a sermon can carry (everything except 'All').
final Set<String> kTopicCategories = {
  for (final c in kSermonCategories)
    if (c != 'All') c,
};

/// Bucket that only scores on the title. Its words ("God", "Christ") appear
/// in nearly every description, so counting them there would swallow the
/// specific topics.
const String _titleOnlyBucket = 'Knowing God';

/// Keyword stems per bucket, in precedence order. Each stem is a regex
/// fragment anchored at a word start; add `\b` for a whole word.
const List<(String, List<String>)> _buckets = [
  (
    'Prayer & Fasting',
    [
      r'pray',
      r'fast(?:ing|ed|s)?\b',
      r'intercess',
      r'supplicat',
      r'tarry',
      r'altar',
      r'watchm[ae]n',
      r'plead',
    ],
  ),
  (
    'Healing & Wholeness',
    [
      r'heal',
      r'wholeness',
      r'deliveran',
      r'deliver',
      r'freedom',
      r'free\b',
      r'depress',
      r'anxi',
      r'broken',
      r'sick',
      r'disease',
      r'miracle',
      r'restor',
      r'health',
      r'infirm',
      r'oppress',
      r'bondage',
      r'yoke',
      r'comfort',
      r'weep',
      r'release',
      r'jubilee',
    ],
  ),
  (
    'Parenting & Children',
    [
      r'parent',
      r'child',
      r'daughter',
      r'youth',
      r'young',
      r'teen',
      r'generation',
      r'dad\b',
      r'fathers? and',
      r'mother',
    ],
  ),
  (
    'Marriage & Family',
    [
      r'marriage',
      r'marri',
      r'wife',
      r'wives',
      r'husband',
      r'famil',
      r'single',
      r'relationship',
      r'fornicat',
      r'sexual',
      r'bride',
    ],
  ),
  (
    'Holy Spirit',
    [
      r'holy spirit',
      r'holy ghost',
      r'spirit',
      r'tongues',
      r'gifts? of',
      r'pentecost',
      r'ruach',
      r'comforter',
      r'impartation',
      r'endowment',
      r'river',
    ],
  ),
  (
    'Revival & Anointing',
    [
      r'revival',
      r'awaken',
      r'anoint',
      r'oil\b',
      r'supernatural',
      r'prophe',
      r'kairos',
      r'fire\b',
      r'power',
      r'open(?:ed)? heaven',
      r'heavens',
      r'rend\b',
      r'accelerat',
      r'apostolic',
      r'signs',
      r'wonders',
      r'strange works?',
      r'divine (?:speed|intervention|direction|visitation)',
      r'visit',
      r'new thing',
      r'speed',
    ],
  ),
  (
    'Worship & Presence',
    [
      r'presence',
      r'worship',
      r'praise',
      r'thank',
      r'sound\b',
      r'priest',
      r'tabernacle',
      r'temple',
      r'veil',
      r'sanctuary',
      r'intimacy',
      r'shout',
      r'hosanna',
      r'communion',
      r'feast',
      r'thirst',
      r'pursu',
      r'with jesus',
      r'with god',
    ],
  ),
  (
    'Grace & Salvation',
    [
      r'grace',
      r'salvation',
      r'saved',
      r'saviou?r',
      r'cross\b',
      r'crucif',
      r'born again',
      r'born of god',
      r'new creation',
      r'resurrect',
      r'risen',
      r'gospel',
      r'blood',
      r'lamb\b',
      r'mercy',
      r'eternal',
      r'redeem',
      r'redempt',
      r'righteous',
      r'justif',
      r'forgiv',
      r'sin',
      r'covenant',
      r'new man',
      r'identity',
      r'in christ',
      r'in him',
      r'sonship',
      r'reconcil',
      r'aton',
      r'law\b',
      r'repent',
      r'hell\b',
      r'wrath',
      r'judge?ment',
      r'second coming',
      r'is coming',
      r'die[ds]? for',
      r'death',
      r'accepted',
      r'chosen',
      r'inheritance',
      r'access',
    ],
  ),
  (
    'Church & Leadership',
    [
      r'church',
      r'leader',
      r'transition',
      r'fellowship',
      r'koinonia',
      r'servant',
      r'serv(?:e|ing)\b',
      r'ministr',
      r'minister',
      r'body of christ',
      r'unity',
      r'elder',
      r'apostle',
      r'pastor',
      r'shepherd',
      r'preach',
      r'teach',
      r'gathering',
      r'house',
      r'household',
      r'build',
      r'honou?r',
      r'members?\b',
      r'kgroup',
      r'cell',
      r'labou?r',
      r'workers?\b',
      r'commission',
      r'reputation',
      r'vessel',
      r'leave',
    ],
  ),
  (
    'Purpose & Mission',
    [
      r'mission',
      r'purpose',
      r'destiny',
      r'calling',
      r'called',
      r'plans?\b',
      r'assignment',
      r'vision',
      r'dream',
      r'possibilit',
      r'evangel',
      r'harvest',
      r'witness',
      r'souls?\b',
      r'advance',
      r'door',
      r'time\b',
      r'timing',
      r'season',
      r'moment',
      r'nations',
      r'diligen',
      r'do the work',
      r'number my days',
      r'decision',
      r'direction',
      r'make it',
      r'continue',
      r'finish',
      r'race\b',
    ],
  ),
  (
    'Giving & Stewardship',
    [
      r'giving',
      r'give',
      r'steward',
      r'tithe',
      r'generos',
      r'money',
      r'prosper',
      r'wealth',
      r'financ',
      r'bless',
      r'sow',
      r'seed',
      r'increase',
      r'abundan',
      r'provision',
      r'supply',
      r'offering',
      r'sacrifice',
      r'economy',
      r'account',
      r'profitable',
      r'insurance',
      r'price',
      r'treasure',
    ],
  ),
  (
    'Faith & Growth',
    [
      r'faith',
      r'grow',
      r'matur',
      r'believ',
      r'trust',
      r'heart',
      r'promise',
      r'favou?r',
      r'victor',
      r'afraid',
      r'fear',
      r'protect',
      r'walk',
      r'love',
      r'life',
      r'living',
      r'overcom',
      r'persever',
      r'endur',
      r'obedien',
      r'patien',
      r'hope',
      r'strength',
      r'strong',
      r'courage',
      r'character',
      r'temptation',
      r'flesh',
      r'holiness',
      r'sanctif',
      r'transform',
      r'discipl',
      r'confess',
      r'speak',
      r'confiden',
      r'rest\b',
      r'peace',
      r'joy',
      r'christian',
      r'virtue',
      r'godliness',
      r'separat',
      r'inner man',
      r'weakness',
      r'rooted',
      r'weeds',
      r'mind',
      r'renew',
      r'wisdom',
      r'stand',
      r'fight',
      r'battle',
      r'warfare',
      r'enem',
      r'help',
      r'pronouncement',
      r'change\b',
      r'entic',
      r'narrow',
    ],
  ),
  (
    'Seasonal',
    [
      r'christmas',
      r'easter',
      r'new year',
      r'good friday',
      r'passover',
      r'advent',
      r'crossover',
      r'birth of (?:christ|jesus)',
      r'nativity',
      r'virgin birth',
      r'immanuel',
    ],
  ),
  ('Testimonies', [r'testimon']),
  (
    'Bible Study',
    [
      r'book of',
      r'acts\b',
      r'ephesians',
      r'colossians',
      r'philippians',
      r'galatians',
      r'romans',
      r'hebrews',
      r'psalms?\b',
      r'genesis',
      r'matthew',
      r'luke\b',
      r'mark\b',
      r'john\b',
      r'corinthians?',
      r'revelation\b',
      r'exodus',
      r'timothy',
      r'titus',
      r'peter\b',
      r'james\b',
      r'jude\b',
      r'isaiah',
      r'daniel',
      r'esther',
      r'ruth\b',
      r'nehemiah',
      r'proverbs',
      r'doctrine',
      r'scripture',
      r'bible',
      r'biblical',
      r'epistle',
      r'abraham',
      r'isaac',
      r'jacob',
      r'joseph',
      r'moses',
      r'elijah',
      r'judas',
      r'stephen',
      r'david\b(?!\s+antwi)',
      r'pergamos',
      r'hiram',
      r'zaphn?ath',
      r'zaphanath',
      r'word of god',
      r'word\b',
      r'theology',
      r'trinity',
      r'insight',
      r'ideology',
      r'homologia',
      r'paralogizomai',
      r'gumnazo',
      r'labash',
    ],
  ),
  (
    _titleOnlyBucket,
    [
      r'god\b',
      r"god['\u2019]s",
      r'christ',
      r'jesus',
      r'lord\b',
      r'father',
      r'knowledge',
      r'know(?:ing)?\b',
      r'mystery',
      r'myst[eé]rion',
      r'name',
      r'nature',
      r'image',
      r'light',
      r'goodness',
      r'glory',
      r'glorified',
      r'majesty',
      r'supremacy',
      r'eminence',
      r'king\b',
      r'lion',
      r'substance',
      r'providence',
      r'seated',
      r'session',
      r'ascension',
      r'voice',
      r'hear',
      r'seek',
      r'encounter',
      r'revelation',
      r'way of',
      r'deep things',
      r'firstborn',
      r'reason',
      r'angels?\b',
    ],
  ),
];

/// Compiled once: one case-insensitive matcher per keyword stem.
final List<(String, List<RegExp>)> _compiled = [
  for (final (label, stems) in _buckets)
    (label, [for (final s in stems) RegExp('\\b$s', caseSensitive: false)]),
];

/// Returns the topic for a sermon from its [title] and optional
/// [description]. Never returns 'All'; returns [kOtherCategory] when nothing
/// matches.
String sermonCategory(String title, {String? description}) {
  final desc = _usefulDescription(title, description);
  String? best;
  var bestTitle = 0;
  var bestDesc = 0;
  for (final (label, patterns) in _compiled) {
    var t = 0;
    var d = 0;
    for (final p in patterns) {
      if (p.hasMatch(title)) t++;
      if (desc != null && label != _titleOnlyBucket && p.hasMatch(desc)) d++;
    }
    if (t == 0 && d == 0) continue;
    // Title hits dominate; description hits only break title ties. Strict
    // comparison keeps the earlier bucket on a full tie.
    if (t > bestTitle || (t == bestTitle && d > bestDesc)) {
      best = label;
      bestTitle = t;
      bestDesc = d;
    }
  }
  return best ?? kOtherCategory;
}

/// The description, unless it is a placeholder ("#Podcast") or a copy of the
/// title, which would double-count the title's keywords.
String? _usefulDescription(String title, String? description) {
  final d = description?.trim();
  if (d == null || d.isEmpty) return null;
  final lower = d.toLowerCase();
  if (lower.replaceFirst('#', '') == 'podcast') return null;
  if (lower == title.trim().toLowerCase()) return null;
  return d;
}

/// The topic a sermon is filed under. An explicit topic (for example one an
/// admin picked in the Studio) is kept when it is a known topic; anything
/// else, including legacy labels and series names, is derived from the title
/// and description.
String topicOf({required String title, String? description, String? category}) {
  if (category != null && kTopicCategories.contains(category)) return category;
  return sermonCategory(title, description: description);
}
