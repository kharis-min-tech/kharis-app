// Real Kharis media content - sourced from SoundCloud RSS and YouTube channel.
// 60 newest audio episodes embedded as instant/offline dataset; the runtime
// RSS fetch upgrades to the full 500-episode catalogue when reachable.

const String kharisChannelId = 'UC4l8WmdF9ivMDQHHVOdYKqQ';

/// 60 newest SoundCloud sermons (title, stream URL, duration, artwork, description).
const List<Map<String, dynamic>> kharisAudioSermons = [
  {
    'title': 'Pray Without Ceasing',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2335807979-kharismedia-pray-without-ceasing.mp3',
    'durationSeconds': 1499,
    'publishedAt': '2026-06-08T23:11:44+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/artworks-DVEB05QHmdQYsklr-MBWqmA-t3000x3000.jpg',
    'speaker': 'David Antwi',
    'description':
        'True prayer isn\'t about doing nothing but praying; it\'s about doing nothing without prayer. In this teaching from the June Fast 2026 series, David Antwi distinguishes between prayer as an obligation a',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'The presence of God',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2332916462-kharismedia-the-presence-of-god.mp3',
    'durationSeconds': 1355,
    'publishedAt': '2026-06-03T23:44:35+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/artworks-2nUR5wVudrHrSqUs-MwrxPg-t3000x3000.png',
    'speaker': 'David Antwi',
    'description':
        'If you had one request for God, would you ask for a breakthrough or for His presence? Moses chose the latter, understanding that knowing God’s ways is more vital than merely witnessing His acts. This ',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'Have a Pure Heart Towards God',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2332485497-kharismedia-a-pure-heart-in-prayer.mp3',
    'durationSeconds': 2620,
    'publishedAt': '2026-06-03T23:44:05+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/artworks-2nUR5wVudrHrSqUs-MwrxPg-t3000x3000.png',
    'speaker': 'David Antwi',
    'description':
        'Is your prayer life a ritual or a relationship? In this opening message of the June Fast series, David Antwi breaks down the difference between scheduled and triggered prayer, offering practical ways ',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'Why Fast?',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2332488749-kharismedia-why-fast.mp3',
    'durationSeconds': 2452,
    'publishedAt': '2026-06-03T06:40:59+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/artworks-yVff4ru40AZOT0fX-TnkQeQ-t3000x3000.png',
    'speaker': 'David Antwi',
    'description':
        'Pastor David Antwi explores the biblical mandate for fasting, revealing why it\'s not merely an \'if\' but an \'expected when\' in a believer\'s walk. Discover how this spiritual discipline deepens dependen',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'God Knows How To Protect His People And Agenda',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2323279808-kharismedia-sunday-service-170526.mp3',
    'durationSeconds': 3620,
    'publishedAt': '2026-05-25T08:40:26+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/artworks-xOKw0CQKZbRHkEDg-UcBdlQ-t3000x3000.jpg',
    'speaker': 'David Antwi',
    'description':
        'When your plans for active service are interrupted by conflict, is it a setback or a divine setup? Pastor David Antwi reveals how God orchestrated Paul’s arrest to move him from missionary travel to t',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'Acts 22',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2322422285-kharismedia-acts-22.mp3',
    'durationSeconds': 3009,
    'publishedAt': '2026-05-17T19:12:10+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/artworks-ijRCsXTZASPWbxoS-1oiyrg-t3000x3000.jpg',
    'speaker': 'David Antwi',
    'description':
        'From a zealous persecutor to a prisoner for Christ, Paul’s journey was marked by radical transformation. This sermon explores the moment Paul’s past credentials met his future purpose, highlighting th',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'The Great Power In Little Things | Awo Antwi',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2320101446-kharismedia-the-great-power-in-little.mp3',
    'durationSeconds': 2817,
    'publishedAt': '2026-05-14T05:00:59+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/artworks-dV1SMynqSDiAEm2Z-PDJGXg-t3000x3000.jpg',
    'speaker': 'Awo Antwi',
    'description':
        'From David’s five stones to the persistence of the ant, scripture is filled with instances where small items and minor seasons yielded massive impact. This sermon examines the power of stewardship in ',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'The Will Of The Lord Be Done | Awo Antwi',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2320099262-kharismedia-the-will-of-the-lord-be-done.mp3',
    'durationSeconds': 2260,
    'publishedAt': '2026-05-14T05:00:49+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/avatars-81a4GWtlrNTrNPWg-dSE3pA-original.jpg',
    'speaker': 'Awo Antwi',
    'description':
        'Navigating life\'s big decisions? Uncover the distinct wills of God – sovereign, revealed, and permissive – and learn how cultivating an obedient heart through scripture can unlock His perfect plan for',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'Who Is This? |  Matthew 2:11-11 | David Antwi',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2320093559-kharismedia-who-is-this-matthew-2-11-11.mp3',
    'durationSeconds': 3770,
    'publishedAt': '2026-05-14T05:00:29+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/avatars-81a4GWtlrNTrNPWg-dSE3pA-original.jpg',
    'speaker': 'David Antwi',
    'description':
        'David Antwi delves into the intentionality behind the Triumphant Entry, exploring why Jesus transitioned from a private ministry to a public, prophetic arrival in Jerusalem. This sermon unpacks the la',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'A Mission Worth Dying For',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2315849687-kharismedia-sunday-service-030526-title.mp3',
    'durationSeconds': 2943,
    'publishedAt': '2026-05-12T19:54:37+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/artworks-JaxU0mFCCvJzDhwt-oxNK8g-t3000x3000.jpg',
    'speaker': 'David Antwi',
    'description':
        'Why did Paul persist in going to Jerusalem when the Holy Spirit warned him of impending bonds and afflictions? David Antwi explores the tension between divine guidance and personal safety, revealing w',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'Can Suffering Be Part Of God’s Will?',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2306182988-kharismedia-can-suffering-be-part-of-gods.mp3',
    'durationSeconds': 2429,
    'publishedAt': '2026-04-20T20:09:26+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/artworks-bsKGpzFRm0IG4UB2-KwAHNw-t3000x3000.jpg',
    'speaker': 'David Antwi',
    'description':
        'Paul\'s determination to reach Jerusalem wasn\'t driven by stubbornness, but by a deep commitment to the pure gospel of grace. Discover how to discern the will of God when faced with emotional oppositio',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'I Commend You To God',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2304599723-kharismedia-i-commend-you-to-god-1.mp3',
    'durationSeconds': 2201,
    'publishedAt': '2026-04-17T21:46:51+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/artworks-lKOunVKnIo4HnOvz-pKtrzQ-t3000x3000.jpg',
    'speaker': 'David Antwi',
    'description':
        'I Commend You To God by David Antwi',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'The Implications of the Resurrection | David Antwi',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2299757234-kharismedia-resurrection-sunday-service.mp3',
    'durationSeconds': 2922,
    'publishedAt': '2026-04-09T21:57:11+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/artworks-8yktydndOv3VboNn-yxWHJA-t3000x3000.jpg',
    'speaker': 'David Antwi',
    'description':
        'Understand the transformative power of the resurrection. This message unpacks the historical data and biblical testimonies, showing how the resurrection not only validates Christ\'s claims but also off',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'Believers vs Disciples',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2293654208-kharismedia-midweek-260226_mixdown.mp3',
    'durationSeconds': 1654,
    'publishedAt': '2026-03-31T05:01:05+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/artworks-dV1SMynqSDiAEm2Z-PDJGXg-t3000x3000.jpg',
    'speaker': 'David Antwi',
    'description':
        'Is there a difference between believing in Jesus and following Him? David Antwi explores the critical distinction between the casual believer and the dedicated disciple, calling for a return to a Chri',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'Fresh Oil',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2293653608-kharismedia-fresh-oil.mp3',
    'durationSeconds': 2099,
    'publishedAt': '2026-03-31T05:01:05+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/artworks-dV1SMynqSDiAEm2Z-PDJGXg-t3000x3000.jpg',
    'speaker': 'David Antwi',
    'description':
        'Explore the dual purpose of Jesus\'s coming – not just to redeem, but to baptize us with the Spirit. This message reveals why a continuous \'fresh oil\' anointing is critical for every believer aspiring ',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'It takes the oil',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2293651115-kharismedia-it-takes-the-oil.mp3',
    'durationSeconds': 4001,
    'publishedAt': '2026-03-31T05:00:55+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/artworks-dV1SMynqSDiAEm2Z-PDJGXg-t3000x3000.jpg',
    'speaker': 'David Antwi',
    'description':
        'Every human being is a vessel designed to contain the divine, yet many remain empty. In this message, David Antwi examines the necessity of the \'oil\'—the Holy Spirit—and how it transforms fragile, ear',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'The Authentic Oil',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2293655066-kharismedia-oil-campaign-bristol.mp3',
    'durationSeconds': 4605,
    'publishedAt': '2026-03-31T05:00:35+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/artworks-dV1SMynqSDiAEm2Z-PDJGXg-t3000x3000.jpg',
    'speaker': 'David Antwi',
    'description':
        'Go beyond mere human effort to discover the indispensable anointing of the Holy Spirit, which empowers believers to do God\'s work on earth. Learn why Jesus is the ultimate \'Messiah\' and how His poured',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'Give Glory to God',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2293650359-kharismedia-give-glory-to-god.mp3',
    'durationSeconds': 645,
    'publishedAt': '2026-03-30T23:31:19+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/artworks-dV1SMynqSDiAEm2Z-PDJGXg-t3000x3000.jpg',
    'speaker': 'David Antwi',
    'description':
        'In a world full of distractions and personal crises, it is easy to lose sight of the divine. David Antwi explores why true worship requires us to isolate God from our problems and offer Him the glory ',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'Future-Proofing the Church',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2292442031-kharismedia-the-future-proofing-the-church.mp3',
    'durationSeconds': 2806,
    'publishedAt': '2026-03-28T22:17:28+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/artworks-hzcyOxa6EgKiWe1k-4fs4iA-t3000x3000.jpg',
    'speaker': 'David Antwi',
    'description':
        'In this study of Acts 20, David Antwi explores Paul’s farewell address to the Ephesian elders, focusing on the essential task of "future-proofing" the church. Discover why a true Christian legacy is m',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'Why I Do What I Do For God',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2289815942-kharismedia-why-i-do-what-i-do-for-god.mp3',
    'durationSeconds': 3113,
    'publishedAt': '2026-03-24T20:46:49+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/artworks-QY93jNMytxCVwCWu-G6uI4w-t3000x3000.jpg',
    'speaker': 'David Antwi',
    'description':
        'Delve into Paul\'s profound farewell address to the Ephesian elders, where he reveals the essence of consecrated ministry: counting his life \'disposable\' for Christ. Discover the courage to face trials',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'The blood of the Lamb',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2285185004-kharismedia-the-blood-of-the-lamb.mp3',
    'durationSeconds': 3426,
    'publishedAt': '2026-03-17T06:00:48+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/artworks-ZX4VQWQT0nbqRGe1-un8lLQ-t3000x3000.png',
    'speaker': 'David Antwi',
    'description':
        'The blood of the Lamb by David Antwi',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'The Shoulder, The Cheeks and The Stomach',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2285179949-kharismedia-the-shoulder-cheeks-stomach.mp3',
    'durationSeconds': 1420,
    'publishedAt': '2026-03-17T06:00:18+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/artworks-ZX4VQWQT0nbqRGe1-un8lLQ-t3000x3000.png',
    'speaker': 'David Antwi',
    'description':
        'Explore the profound symbolism behind the \'priest’s due\' in Exodus. David Antwi breaks down how surrendering our burdens, offenses, and appetites—represented by the shoulder, cheeks, and stomach—is th',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'Get the Anointing',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2285186072-kharismedia-get-the-anointing.mp3',
    'durationSeconds': 493,
    'publishedAt': '2026-03-17T06:00:08+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/artworks-ZX4VQWQT0nbqRGe1-un8lLQ-t3000x3000.png',
    'speaker': 'David Antwi',
    'description':
        'Delve into the essential principles for cultivating a life of anointing. Learn how purity of soul and integrity of heart are non-negotiable for walking in sustained spiritual power.',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'Time to Transition',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2285180600-kharismedia-time-to-transition.mp3',
    'durationSeconds': 1848,
    'publishedAt': '2026-03-17T06:00:08+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/artworks-ZX4VQWQT0nbqRGe1-un8lLQ-t3000x3000.png',
    'speaker': 'David Antwi',
    'description':
        'We are in a moment of rapid transition. Drawing from the book of Exodus, Pastor David Antwi explains why readiness is essential when God begins to move. Discover how to disconnect from the weights of ',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'A Special Message For Church Leaders',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2283690965-kharismedia-a-special-message-for-church.mp3',
    'durationSeconds': 3066,
    'publishedAt': '2026-03-17T00:13:04+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/artworks-0eby83lDyr9XqmNX-izsjSA-t3000x3000.jpg',
    'speaker': 'David Antwi',
    'description':
        'A Special Message For Church Leaders by David Antwi',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'Securing The Church\'s Future',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2277903002-kharismedia-sunday-service-010326_mixdown.mp3',
    'durationSeconds': 3494,
    'publishedAt': '2026-03-07T17:59:55+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/artworks-Ao9lopvxdEon0rsF-mIByvw-t3000x3000.jpg',
    'speaker': 'David Antwi',
    'description':
        'Journey with David Antwi through Acts 20 as he reveals Paul\'s unwavering dedication to spiritual growth and strengthening the early church amidst relentless travels and opposition. Discover the intent',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'What To Expect When Revival Comes - Part 3',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2274182591-kharismedia-what-to-expect-when-revival-1.mp3',
    'durationSeconds': 3555,
    'publishedAt': '2026-02-26T22:33:14+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/artworks-ywuU0f6C5kVA0FvV-kV5DWw-t3000x3000.jpg',
    'speaker': 'David Antwi',
    'description':
        'Is your love for God growing or cooling? Pastor David Antwi examines the signs of a true move of God and the necessity of \'gospel-saturated\' living. Learn why the local church must prioritise sound do',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'Relax, Do not be afraid!',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2273148095-kharismedia-relax-do-not-be-afraid.mp3',
    'durationSeconds': 1599,
    'publishedAt': '2026-02-26T06:00:50+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/artworks-ZX4VQWQT0nbqRGe1-un8lLQ-t3000x3000.png',
    'speaker': 'David Antwi',
    'description':
        'Discover why your hunger for God is the most significant breakthrough you can experience. This sermon unpacks how a deep thirst for the Holy Spirit unleashes divine presence and transforms your destin',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'Kairos Moment',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2273154500-kharismedia-kairos-moment.mp3',
    'durationSeconds': 1704,
    'publishedAt': '2026-02-26T06:00:30+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/artworks-ZX4VQWQT0nbqRGe1-un8lLQ-t3000x3000.png',
    'speaker': 'David Antwi',
    'description':
        'Kairos Moment by David Antwi',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'I Am Done With This Place',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2273149682-kharismedia-i-am-done-with-this-place.mp3',
    'durationSeconds': 887,
    'publishedAt': '2026-02-26T06:00:30+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/artworks-ZX4VQWQT0nbqRGe1-un8lLQ-t3000x3000.png',
    'speaker': 'David Antwi',
    'description':
        'Discover the spiritual mechanics of the \'Great Exodus\' as David Antwi explores how to transition from a season of shame into a future of strength. This message breaks down the significance of calling ',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'The Platform of Favour',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2273148959-kharismedia-the-platform-of-favour.mp3',
    'durationSeconds': 1440,
    'publishedAt': '2026-02-26T06:00:10+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/artworks-ZX4VQWQT0nbqRGe1-un8lLQ-t3000x3000.png',
    'speaker': 'David Antwi',
    'description':
        'Favor often bridges the gap where talent and qualification fall short. Using the biblical examples of Esther and Joseph, this message highlights how divine favor can open doors in careers, academics, ',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'What to do to Hear God\'s voice Part 2',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2273143493-kharismedia-what-to-do-to-hear-gods-1.mp3',
    'durationSeconds': 1480,
    'publishedAt': '2026-02-25T13:33:59+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/artworks-GlzYINNMfM2740si-y1tJDA-t3000x3000.jpg',
    'speaker': 'David Antwi',
    'description':
        'Many struggle to hear from God due to past disappointments or a sense of unworthiness. David Antwi addresses these common hurdles, providing a clear framework for discerning the Spirit\'s internal witn',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'What to do to Hear God\'s voice Part 1',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2273140535-kharismedia-what-to-do-to-hear-gods-voice.mp3',
    'durationSeconds': 1934,
    'publishedAt': '2026-02-25T13:22:49+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/artworks-GlzYINNMfM2740si-y1tJDA-t3000x3000.jpg',
    'speaker': 'David Antwi',
    'description':
        'Many struggle to hear from God due to past disappointments or a sense of unworthiness. David Antwi addresses these common hurdles, providing a clear framework for discerning the Spirit\'s internal witn',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'The Gospel of Peace and Shield Of Faith | Ephesians 6:15-16',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2270925068-kharismedia-the-gospel-of-peace-and-shield.mp3',
    'durationSeconds': 3202,
    'publishedAt': '2026-02-23T06:00:45+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/avatars-81a4GWtlrNTrNPWg-dSE3pA-original.jpg',
    'speaker': 'David Antwi',
    'description':
        'Unlock the true measure of your Christian journey. This sermon reveals how a profound, Spirit-imprinted understanding of Jesus Christ—not external displays—is the sole determinant of your spiritual st',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'Honour Your Father and Mother | Ephesians 6:2-4',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2270923886-kharismedia-honour-your-father-and-mother.mp3',
    'durationSeconds': 2756,
    'publishedAt': '2026-02-23T06:00:45+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/avatars-81a4GWtlrNTrNPWg-dSE3pA-original.jpg',
    'speaker': 'David Antwi',
    'description':
        'Explore the profound connection between family dynamics and spiritual success in this teaching on Ephesians 6. David Antwi breaks down the \'first commandment with a promise,\' revealing how the practic',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'Bond Servants and Masters | Ephesians 6:5-9',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2270922674-kharismedia-bond-servants-and-masters.mp3',
    'durationSeconds': 2625,
    'publishedAt': '2026-02-23T06:00:45+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/avatars-81a4GWtlrNTrNPWg-dSE3pA-original.jpg',
    'speaker': 'David Antwi',
    'description':
        'Christianity isn\'t just a Sunday affair—it\'s a lifestyle that reshapes every social hierarchy and relationship. From the home to the workplace, discover how living under the authority of Christ change',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'Fasting 101',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2270920526-kharismedia-fasting-101.mp3',
    'durationSeconds': 3501,
    'publishedAt': '2026-02-23T06:00:35+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/avatars-81a4GWtlrNTrNPWg-dSE3pA-original.jpg',
    'speaker': 'David Antwi',
    'description':
        'Discover how fasting acts as a catalyst for spiritual growth and authority. David Antwi explores how a lifestyle of deliberate abstinence expands your capacity to host God\'s power and provides the cla',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'The Night Is Far Spent | Ephesians 6 v10-12',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2268509972-kharismedia-the-night-is-far-spent.mp3',
    'durationSeconds': 2715,
    'publishedAt': '2026-02-18T06:00:45+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/avatars-81a4GWtlrNTrNPWg-dSE3pA-original.jpg',
    'speaker': 'David Antwi',
    'description':
        'Christianity is more than a set of rules—it is a revolutionary movement that upends social norms and transforms character. Pastor David Antwi breaks down how the church must corporately put on the Lor',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'Biblical Submission | Ephesians 5 v22-25',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2268502394-kharismedia-biblical-submission-ephesians.mp3',
    'durationSeconds': 1219,
    'publishedAt': '2026-02-18T06:00:35+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/avatars-81a4GWtlrNTrNPWg-dSE3pA-original.jpg',
    'speaker': 'David Antwi',
    'description':
        'Explore the profound model of Christ\'s love for the Church as a blueprint for husbands, uncovering the essential link between selfless responsibility, protection, and a thriving marriage. A powerful c',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'Thank You Jesus',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2268501833-kharismedia-thank-you-jesus.mp3',
    'durationSeconds': 996,
    'publishedAt': '2026-02-18T06:00:35+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/avatars-81a4GWtlrNTrNPWg-dSE3pA-original.jpg',
    'speaker': 'David Antwi',
    'description':
        'Are your prayers reaching their full potential? David Antwi explains why \'doxology\'—the expression of praise—is the necessary conclusion to every effective prayer. This message challenges listeners to',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'How To Maximise A Prophetic Encounter',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2268516752-kharismedia-how-to-maximise-a-prophetic.mp3',
    'durationSeconds': 3250,
    'publishedAt': '2026-02-18T06:00:25+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/avatars-81a4GWtlrNTrNPWg-dSE3pA-original.jpg',
    'speaker': 'David Antwi',
    'description':
        'In an era of spiritual indifference, David Antwi calls for an urgent, wild faith. Learn why some destinies are unlocked not through comfort, but through the willingness to \'strike hard,\' move with \'ha',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'The Armour That Strikes Back | Ephesians 6 v17',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2268513323-kharismedia-the-armour-that-strikes-back.mp3',
    'durationSeconds': 1592,
    'publishedAt': '2026-02-18T06:00:25+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/avatars-81a4GWtlrNTrNPWg-dSE3pA-original.jpg',
    'speaker': 'David Antwi',
    'description':
        'Your spiritual future is forged in your present engagement with God\'s Word. Understand why loading your \'spiritual system\' with truth is essential for configuring a life of purpose and overcoming the ',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'The Helmet of Salvation | Ephesians 6 v17',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2268512309-kharismedia-the-helmet-of-salvation.mp3',
    'durationSeconds': 1686,
    'publishedAt': '2026-02-18T06:00:25+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/avatars-81a4GWtlrNTrNPWg-dSE3pA-original.jpg',
    'speaker': 'David Antwi',
    'description':
        'Are you struggling with sin or temptation? David Antwi explains why a Christian without the Word of God is as vulnerable as a blind man in the dark. Find out how to intentionally walk in the light, pr',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'Equipped To Stand | Ephesians 6 v13-14',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2268511631-kharismedia-equipped-to-stand-ephesians-6.mp3',
    'durationSeconds': 1110,
    'publishedAt': '2026-02-18T06:00:25+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/avatars-81a4GWtlrNTrNPWg-dSE3pA-original.jpg',
    'speaker': 'David Antwi',
    'description':
        'What does it truly mean to \'stand\' after weathering every storm? This powerful message explores how to build an unwavering faith that not only withstands the \'evil day\' but ensures you\'re still standi',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'The God Who Reveals Himself | Ephesians 5 v26-33',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2268505145-kharismedia-the-god-who-reveals-himself.mp3',
    'durationSeconds': 4937,
    'publishedAt': '2026-02-18T06:00:25+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/avatars-81a4GWtlrNTrNPWg-dSE3pA-original.jpg',
    'speaker': 'David Antwi',
    'description':
        'Discover the strategic transition from the Old Covenant to the age of grace. David Antwi explores how the Church serves as God’s current representative on earth and how the \'great mystery\' of Ephesian',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'Vision',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2268499598-kharismedia-vision.mp3',
    'durationSeconds': 3455,
    'publishedAt': '2026-02-18T06:00:15+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/avatars-81a4GWtlrNTrNPWg-dSE3pA-original.jpg',
    'speaker': 'David Antwi',
    'description':
        'In a world full of noise, how do you hear the still, small voice of God? Drawing from the prophet Habakkuk’s commitment to "stand the watch," this message explores the necessity of separation, the pow',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'What to Expect When Revival Comes - Part 2',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2268375248-kharismedia-what-to-expect-when-revival.mp3',
    'durationSeconds': 2233,
    'publishedAt': '2026-02-17T19:14:06+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/avatars-81a4GWtlrNTrNPWg-dSE3pA-original.jpg',
    'speaker': 'David Antwi',
    'description':
        'When the Gospel takes root in a city, it doesn\'t just change hearts; it changes habits. This message examines the \'Great Exodus\' of the early church—the moment believers valued their purity more than ',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'The Blessedness of Seeking God',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2267868104-kharismedia-the-blessedness-of-seeking-god.mp3',
    'durationSeconds': 1588,
    'publishedAt': '2026-02-17T06:00:45+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/artworks-FF0zmSnRh6sqNvj3-8qus8A-t3000x3000.jpg',
    'speaker': 'David Antwi',
    'description':
        'What happens to your spiritual momentum once a season of fasting ends? In this insightful message, David Antwi identifies the four key factors that help you maintain a lifestyle of seeking God: the in',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'Entering the Promises of God',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2255406647-kharismedia-entering-the-promises-of-god.mp3',
    'durationSeconds': 2371,
    'publishedAt': '2026-02-16T07:43:21+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/artworks-Rd06Q6QHlgWJJK92-eUu4UA-t3000x3000.jpg',
    'speaker': 'David Antwi',
    'description':
        'Entering the Promises of God by David Antwi',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'What To Expect When Revival Comes',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2260533662-kharismedia-what-to-expect-when-revival-comes.mp3',
    'durationSeconds': 2522,
    'publishedAt': '2026-02-05T23:14:00+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/avatars-81a4GWtlrNTrNPWg-dSE3pA-original.jpg',
    'speaker': 'David Antwi',
    'description':
        'Explore what truly fuels a spiritual awakening in this study of Acts 19. Pastor David Antwi reveals that revival isn\'t born from mere activity, but from persistent, Christ-centered teaching and the un',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'What to do in a Prophetic Atmosphere',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2252069720-kharismedia-what-to-do-in-a-prophetic-atmosphere.mp3',
    'durationSeconds': 878,
    'publishedAt': '2026-01-22T14:01:36+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/artworks-ZX4VQWQT0nbqRGe1-un8lLQ-t3000x3000.png',
    'speaker': 'David Antwi',
    'description':
        'What to do in a Prophetic Atmosphere by David Antwi',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'Deal with the weeds',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2251985609-kharismedia-deal-with-the-weeds.mp3',
    'durationSeconds': 735,
    'publishedAt': '2026-01-22T14:01:36+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/artworks-ZX4VQWQT0nbqRGe1-un8lLQ-t3000x3000.png',
    'speaker': 'David Antwi',
    'description':
        'Deal with the weeds by David Antwi',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'Give your victory a voice',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2251961336-kharismedia-give-your-victory-a-voice.mp3',
    'durationSeconds': 1078,
    'publishedAt': '2026-01-22T14:01:36+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/artworks-ZX4VQWQT0nbqRGe1-un8lLQ-t3000x3000.png',
    'speaker': 'David Antwi',
    'description':
        'Give your victory a voice by David Antwi',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'Fasting Commands Victories',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2249123297-kharismedia-fasting-commands-victories.mp3',
    'durationSeconds': 1408,
    'publishedAt': '2026-01-22T14:01:36+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/artworks-ZX4VQWQT0nbqRGe1-un8lLQ-t3000x3000.png',
    'speaker': 'David Antwi',
    'description':
        'Fasting Commands Victories by David Antwi',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'Strive to pray',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2251976801-kharismedia-strive-to-pray.mp3',
    'durationSeconds': 923,
    'publishedAt': '2026-01-22T12:19:53+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/avatars-81a4GWtlrNTrNPWg-dSE3pA-original.jpg',
    'speaker': 'David Antwi',
    'description':
        'Explore the profound truth that prayer is not merely an option, but a vital spiritual labor. This message unpacks the essence of continual prayer, revealing how it keeps you steadfastly aligned with G',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'Provoking The Supernatural | David Antwi',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2251940609-kharismedia-ea41e753-ef72-4640-811d-0e0c378713ec.mp3',
    'durationSeconds': 3893,
    'publishedAt': '2026-01-22T10:39:23+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/artworks-HLAa6eOBT6n2yHR8-sMTahw-t3000x3000.jpg',
    'speaker': 'David Antwi',
    'description':
        'Discover how to bridge the gap between your natural circumstances and God’s supernatural power. David Antwi explores the biblical principles for provoking divine intervention, teaching you how to take',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'The Glorious Gospel of Christ',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2247819017-kharismedia-the-glorious-gospel-of-christ.mp3',
    'durationSeconds': 2929,
    'publishedAt': '2026-01-15T10:24:11+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/avatars-81a4GWtlrNTrNPWg-dSE3pA-original.jpg',
    'speaker': 'David Antwi',
    'description':
        'In an era of cultural shifts, David Antwi calls for a return to the intensity and purity of Christ’s message. This sermon explains why the gospel remains the only true source of salvation and how its ',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'Great Awakening',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2246260961-kharismedia-sunday-service-110126_mixdown.mp3',
    'durationSeconds': 3166,
    'publishedAt': '2026-01-14T22:13:57+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/artworks-HaORbzVgFNJaD9A1-VyvQ6g-t3000x3000.png',
    'speaker': 'David Antwi',
    'description':
        'Are you active in church but passive in your relationship with God? In this sermon, David Antwi distinguishes between revival and awakening, challenging believers to move past the "sleep of death" and',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'Things that must characterise your fasting',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2246692850-kharismedia-things-that-must-characterise-your-fasting.mp3',
    'durationSeconds': 1710,
    'publishedAt': '2026-01-13T13:12:42+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/artworks-ZX4VQWQT0nbqRGe1-un8lLQ-t3000x3000.png',
    'speaker': 'David Antwi',
    'description':
        'David Antwi explores how fasting serves as a spiritual catalyst for acceleration, turning years of delay into months of progress. This sermon breaks down the practical steps—from deep repentance to Bi',
    'source': 'soundcloud',
    'type': 'audio',
  },
  {
    'title': 'When you fast',
    'audioUrl':
        'http://www.podtrac.com/pts/redirect.mp3/feeds.soundcloud.com/stream/2246685158-kharismedia-fasting-enhances-you.mp3',
    'durationSeconds': 1383,
    'publishedAt': '2026-01-13T13:12:42+00:00',
    'artworkUrl':
        'https://i1.sndcdn.com/artworks-ZX4VQWQT0nbqRGe1-un8lLQ-t3000x3000.png',
    'speaker': 'David Antwi',
    'description':
        'Every major life decision—from career moves to marriage—requires more than just human logic. Pastor David Antwi explores how the \'ordered steps\' of a believer are secured through seeking God\'s face. D',
    'source': 'soundcloud',
    'type': 'audio',
  },
];

/// Full-length Kharis YouTube uploads (shorts excluded). Newest first.
const List<Map<String, dynamic>> kharisVideos = [
  {
    'videoId': 'Q5UKIwmy16k',
    'title': 'The LOGOS Became Flesh | John 1:14 | David Antwi | Kharis Phase Two',
    'publishedAt': '2026-06-09T11:31:40+00:00',
    'thumbnailUrl': 'https://img.youtube.com/vi/Q5UKIwmy16k/hqdefault.jpg',
    'source': 'youtube',
    'type': 'video',
  },
  {
    'videoId': '6t8e9cabDRE',
    'title': 'We don\'t just ATTEND church, we SERVE at church! #churchlife #kharischurch #davidantwi #serving',
    'publishedAt': '2026-06-09T11:30:01+00:00',
    'thumbnailUrl': 'https://img.youtube.com/vi/6t8e9cabDRE/hqdefault.jpg',
    'source': 'youtube',
    'type': 'video',
  },
  {
    'videoId': 'rrgDXcKD1rc',
    'title': 'The Importance Of Praying In The Morning | Archbishop Nicholas Duncan-Williams',
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
    'title': 'The Fragrance - The Sweet  One | S1 E11 | Kharis Church',
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
    'title': 'Righteousness, Self-control and the Judgement to come | Acts 24 |David Antwi',
    'publishedAt': '2026-05-24T13:40:59+00:00',
    'thumbnailUrl': 'https://img.youtube.com/vi/mAIYDzd8GRk/hqdefault.jpg',
    'source': 'youtube',
    'type': 'video',
  },
];
