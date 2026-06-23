// Real Kharis YouTube content. Audio episodes live in
// assets/data/kharis_sermons.json (full 500-episode catalogue).

const String kharisChannelId = 'UC4l8WmdF9ivMDQHHVOdYKqQ';

/// Full-length Kharis YouTube uploads (Shorts excluded), newest first.
///
/// Used as the offline / web fallback when the live Atom feed is unreachable
/// (web cross-origin CORS). Mobile fetches the live feed directly. Refreshed
/// 2026-06-18.
const List<Map<String, dynamic>> kharisVideos = [
  {
    'videoId': 'DVmHLO1-23s',
    'title': 'Minister Joe Mettle at Kharis Church',
    'publishedAt': '2026-06-15T09:58:40+00:00',
    'thumbnailUrl': 'https://img.youtube.com/vi/DVmHLO1-23s/hqdefault.jpg',
    'source': 'youtube',
    'type': 'video',
  },
  {
    'videoId': 'z7COOD_kFH4',
    'title': 'Acts Series | David Antwi',
    'publishedAt': '2026-06-14T13:22:31+00:00',
    'thumbnailUrl': 'https://img.youtube.com/vi/z7COOD_kFH4/hqdefault.jpg',
    'source': 'youtube',
    'type': 'video',
  },
  {
    'videoId': 'MqImw7f3ZxY',
    'title':
        'Special Evening With His Eminence Archbishop Nicholas Duncan-Williams | Kharis Church',
    'publishedAt': '2026-06-13T01:18:57+00:00',
    'thumbnailUrl': 'https://img.youtube.com/vi/MqImw7f3ZxY/hqdefault.jpg',
    'source': 'youtube',
    'type': 'video',
  },
  {
    'videoId': 'Q5UKIwmy16k',
    'title':
        'The LOGOS Became Flesh | John 1:14 | David Antwi | Kharis Phase Two',
    'publishedAt': '2026-06-09T11:31:40+00:00',
    'thumbnailUrl': 'https://img.youtube.com/vi/Q5UKIwmy16k/hqdefault.jpg',
    'source': 'youtube',
    'type': 'video',
  },
  {
    'videoId': 'rrgDXcKD1rc',
    'title':
        'The Importance Of Praying In The Morning | Archbishop Nicholas Duncan-Williams',
    'publishedAt': '2026-06-07T13:48:00+00:00',
    'thumbnailUrl': 'https://img.youtube.com/vi/rrgDXcKD1rc/hqdefault.jpg',
    'source': 'youtube',
    'type': 'video',
  },
  {
    'videoId': '0P-9BuD_oHs',
    'title': 'Join Us This Evening For An Encounter | David Antwi',
    'publishedAt': '2026-06-06T03:30:06+00:00',
    'thumbnailUrl': 'https://img.youtube.com/vi/0P-9BuD_oHs/hqdefault.jpg',
    'source': 'youtube',
    'type': 'video',
  },
  {
    'videoId': '5MkfCRyuyl8',
    'title': 'The Fragrance - The Sweet One | S1 E11 | Kharis Church',
    'publishedAt': '2026-05-31T19:00:06+00:00',
    'thumbnailUrl': 'https://img.youtube.com/vi/5MkfCRyuyl8/hqdefault.jpg',
    'source': 'youtube',
    'type': 'video',
  },
  {
    'videoId': 'gjA44zkruZE',
    'title': 'WHY FAST? | David Antwi',
    'publishedAt': '2026-05-31T12:09:45+00:00',
    'thumbnailUrl': 'https://img.youtube.com/vi/gjA44zkruZE/hqdefault.jpg',
    'source': 'youtube',
    'type': 'video',
  },
  {
    'videoId': 'mAIYDzd8GRk',
    'title':
        'Righteousness, Self-control and the Judgement to come | Acts 24 | David Antwi',
    'publishedAt': '2026-05-24T13:40:59+00:00',
    'thumbnailUrl': 'https://img.youtube.com/vi/mAIYDzd8GRk/hqdefault.jpg',
    'source': 'youtube',
    'type': 'video',
  },
];
