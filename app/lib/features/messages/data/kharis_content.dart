// Real Kharis media content — sourced from SoundCloud RSS and YouTube channel.
// Sermons: audio only (SoundCloud). Videos: full-length uploads (shorts excluded).

const String kharisChannelId = 'UC4l8WmdF9ivMDQHHVOdYKqQ';

/// 12 real SoundCloud sermons.
///
/// Fields:
///   title       – original title from SoundCloud
///   audioUrl    – feeds.soundcloud.com enclosure URL (podtrac redirect)
///   durationSeconds – HH:MM:SS parsed to total seconds
///   publishedAt – ISO-8601 UTC string
///   artworkUrl  – sndcdn artwork image
///   speaker     – resolved from title ('Awo Antwi' when indicated, else 'David Antwi')
///   source      – 'soundcloud'
///   type        – 'audio'
const List<Map<String, dynamic>> kharisAudioSermons = [
  {
    'title': 'Pray Without Ceasing',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2335807979-kharismedia-pray-without-ceasing.mp3',
    'durationSeconds': 1499, // 00:24:59
    'publishedAt': '2026-06-08T23:11:44+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/artworks-DVEB05QHmdQYsklr-MBWqmA-t3000x3000.jpg',
    'speaker': 'David Antwi',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'The presence of God',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2332916462-kharismedia-the-presence-of-god.mp3',
    'durationSeconds': 1355, // 00:22:35
    'publishedAt': '2026-06-03T23:44:35+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/artworks-2nUR5wVudrHrSqUs-MwrxPg-t3000x3000.png',
    'speaker': 'David Antwi',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'Have a Pure Heart Towards God',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2332485497-kharismedia-a-pure-heart-in-prayer.mp3',
    'durationSeconds': 2620, // 00:43:40
    'publishedAt': '2026-06-03T23:44:05+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/artworks-2nUR5wVudrHrSqUs-MwrxPg-t3000x3000.png',
    'speaker': 'David Antwi',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'Why Fast?',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2332488749-kharismedia-why-fast.mp3',
    'durationSeconds': 2452, // 00:40:52
    'publishedAt': '2026-06-03T06:40:59+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/artworks-yVff4ru40AZOT0fX-TnkQeQ-t3000x3000.png',
    'speaker': 'David Antwi',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'God Knows How To Protect His People And Agenda',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2323279808-kharismedia-sunday-service-170526.mp3',
    'durationSeconds': 3620, // 01:00:20
    'publishedAt': '2026-05-25T08:40:26+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/artworks-xOKw0CQKZbRHkEDg-UcBdlQ-t3000x3000.jpg',
    'speaker': 'David Antwi',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'Acts 22',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2322422285-kharismedia-acts-22.mp3',
    'durationSeconds': 3009, // 00:50:09
    'publishedAt': '2026-05-17T19:12:10+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/artworks-ijRCsXTZASPWbxoS-1oiyrg-t3000x3000.jpg',
    'speaker': 'David Antwi',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'The Great Power In Little Things | Awo Antwi',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2320101446-kharismedia-the-great-power-in-little.mp3',
    'durationSeconds': 2817, // 00:46:57
    'publishedAt': '2026-05-14T05:00:59+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/artworks-dV1SMynqSDiAEm2Z-PDJGXg-t3000x3000.jpg',
    'speaker': 'Awo Antwi',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'The Will Of The Lord Be Done | Awo Antwi',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2320099262-kharismedia-the-will-of-the-lord-be-done.mp3',
    'durationSeconds': 2260, // 00:37:40
    'publishedAt': '2026-05-14T05:00:49+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/avatars-81a4GWtlrNTrNPWg-dSE3pA-original.jpg',
    'speaker': 'Awo Antwi',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'Who Is This? | Matthew 2:11-11 | David Antwi',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2320093559-kharismedia-who-is-this-matthew-2-11-11.mp3',
    'durationSeconds': 3770, // 01:02:50
    'publishedAt': '2026-05-14T05:00:29+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/avatars-81a4GWtlrNTrNPWg-dSE3pA-original.jpg',
    'speaker': 'David Antwi',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'A Mission Worth Dying For',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2315849687-kharismedia-sunday-service-030526-title.mp3',
    'durationSeconds': 2943, // 00:49:03
    'publishedAt': '2026-05-12T19:54:37+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/artworks-JaxU0mFCCvJzDhwt-oxNK8g-t3000x3000.jpg',
    'speaker': 'David Antwi',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': "Can Suffering Be Part Of God\u2019s Will?",
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2306182988-kharismedia-can-suffering-be-part-of-gods.mp3',
    'durationSeconds': 2429, // 00:40:29
    'publishedAt': '2026-04-20T20:09:26+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/artworks-bsKGpzFRm0IG4UB2-KwAHNw-t3000x3000.jpg',
    'speaker': 'David Antwi',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'I Commend You To God',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2304599723-kharismedia-i-commend-you-to-god-1.mp3',
    'durationSeconds': 2201, // 00:36:41
    'publishedAt': '2026-04-17T21:46:51+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/artworks-lKOunVKnIo4HnOvz-pKtrzQ-t3000x3000.jpg',
    'speaker': 'David Antwi',
    'source': 'soundcloud',
    'type': 'audio',
  },
];

/// YouTube full-length uploads — shorts (titles containing '#shorts' or '#short') excluded.
///
/// Fields:
///   videoId     – YouTube video ID
///   title       – video title
///   publishedAt – ISO-8601 string
///   thumbnailUrl – hqdefault always exists (maxresdefault sometimes 404s)
///   source      – 'youtube'
///   type        – 'video'
const List<Map<String, dynamic>> kharisVideos = [
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
    'videoId': '6t8e9cabDRE',
    'title':
        "We don't just ATTEND church, we SERVE at church! #churchlife #kharischurch #davidantwi #serving",
    'publishedAt': '2026-06-09T11:30:01+00:00',
    'thumbnailUrl': 'https://img.youtube.com/vi/6t8e9cabDRE/hqdefault.jpg',
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
    'videoId': '3gKNZ104LY4',
    'title': 'The Fragrance - SATISFIED | S1 E10 | Kharis Church',
    'publishedAt': '2026-05-24T19:00:06+00:00',
    'thumbnailUrl': 'https://img.youtube.com/vi/3gKNZ104LY4/hqdefault.jpg',
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
