/// Purpose-based categorization for sermon titles.
///
/// Single source of truth used by the RSS parser, the embedded dataset
/// mapping, and the Firestore document mapper. First matching bucket wins,
/// so order encodes precedence. Buckets were mined from the full
/// 500-episode SoundCloud catalogue (Nov 2022 - Jun 2026).
library;

/// Display order for the filter sheet. 'All' first, catch-all last.
const List<String> kSermonCategories = [
  'All',
  'Prayer & Fasting',
  'Bible Study',
  'Grace & Salvation',
  'Faith & Growth',
  'Holy Spirit',
  'Revival & Anointing',
  'Church & Leadership',
  'Worship & Presence',
  'Seeking God',
  'Parenting & Children',
  'Marriage & Family',
  'Healing & Wholeness',
  'Purpose & Mission',
  'Giving & Stewardship',
  'Testimonies',
  'Seasonal',
  'Messages',
];

const List<(String, List<String>)> _buckets = [
  ('Prayer & Fasting', ['pray', 'fast', 'intercess', 'ceasing']),
  (
    'Healing & Wholeness',
    ['heal', 'wholeness', 'deliver', 'freedom', 'depress', 'anxiety', 'broken']
  ),
  (
    'Parenting & Children',
    ['parent', 'child', 'children', 'daughter', 'youth', 'young']
  ),
  ('Marriage & Family', ['marriage', 'wife', 'husband', 'family', 'single']),
  (
    'Bible Study',
    [
      'acts', 'ephesians', 'john', 'roman', 'hebrew', 'psalm', 'genesis',
      'matthew', 'luke', 'mark ', 'corinthian', 'revelation', 'exodus',
      'timothy', 'doctrine', 'scripture', 'word of god',
    ]
  ),
  (
    'Revival & Anointing',
    [
      'revival', 'awakening', 'anoint', 'oil', 'supernatural', 'prophetic',
      'kairos', 'fire',
    ]
  ),
  (
    'Worship & Presence',
    ['presence', 'worship', 'praise', 'glory', 'thank you', 'sound']
  ),
  ('Holy Spirit', ['spirit', 'gifts', 'tongues']),
  (
    'Grace & Salvation',
    [
      'grace', 'salvation', 'cross', 'born again', 'saved', 'resurrection',
      'gospel', 'blood', 'lamb', 'mercy', 'eternal', 'christ', 'jesus',
    ]
  ),
  ('Church & Leadership', ['church', 'leader', 'transition', 'fellowship']),
  (
    'Purpose & Mission',
    ['mission', 'purpose', 'destiny', 'call', 'plan', 'assignment']
  ),
  ('Seeking God', ['voice', 'hear', 'seek', 'encounter', 'knowing god']),
  ('Seasonal', ['christmas', 'easter', 'new year', 'thanksgiving']),
  ('Testimonies', ['testimon']),
  (
    'Giving & Stewardship',
    ['giving', 'give', 'steward', 'tithe', 'generos', 'money']
  ),
  (
    'Faith & Growth',
    [
      'faith', 'grow', 'matur', 'believ', 'trust', 'heart', 'promise',
      'favour', 'victory', 'afraid', 'protect', 'walk', 'love', 'life',
    ]
  ),
];

/// Returns the purpose bucket for a sermon [title]. Defaults to 'Messages'.
String sermonCategory(String title) {
  final t = title.toLowerCase();
  for (final (label, keywords) in _buckets) {
    if (keywords.any(t.contains)) return label;
  }
  return 'Messages';
}
