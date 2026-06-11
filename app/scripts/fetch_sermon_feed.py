#!/usr/bin/env python3
"""Regenerates assets/data/kharis_sermons.json from the SoundCloud RSS feed.

Run before each release so web builds ship the complete catalogue
(the feed exposes the newest 500 episodes; mobile also refreshes live
at runtime). Usage:

    python3 scripts/fetch_sermon_feed.py
"""
import json
import os
import re
import urllib.request
import xml.etree.ElementTree as ET
from email.utils import parsedate_to_datetime
from html import unescape

FEED = 'https://feeds.soundcloud.com/users/soundcloud:users:58625221/sounds.rss'
NS = {'itunes': 'http://www.itunes.com/dtds/podcast-1.0.dtd'}
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'data',
                   'kharis_sermons.json')


def parse_duration(raw: str) -> int:
    parts = [int(p) for p in raw.split(':')]
    if len(parts) == 3:
        return parts[0] * 3600 + parts[1] * 60 + parts[2]
    if len(parts) == 2:
        return parts[0] * 60 + parts[1]
    return parts[0]


def main() -> None:
    with urllib.request.urlopen(FEED, timeout=60) as resp:
        root = ET.fromstring(resp.read())

    episodes = []
    for item in root.iter('item'):
        title = unescape((item.findtext('title') or '').strip())
        enclosure = item.find('enclosure')
        url = enclosure.get('url') if enclosure is not None else None
        if not url:
            continue
        desc = item.findtext('description') or \
            item.findtext('itunes:summary', '', NS) or ''
        desc = unescape(re.sub(r'<[^>]+>', '', desc)).strip()
        desc = re.sub(r'\s+', ' ', desc)[:200]
        img = item.find('itunes:image', NS)
        episodes.append({
            'title': title,
            'audioUrl': url,
            'durationSeconds':
                parse_duration(item.findtext('itunes:duration', '0', NS)),
            'publishedAt':
                parsedate_to_datetime(item.findtext('pubDate', '')).isoformat(),
            'artworkUrl': img.get('href') if img is not None else None,
            'speaker': 'Awo Antwi' if 'awo' in title.lower() else 'David Antwi',
            'description': desc,
        })

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    from datetime import date
    with open(OUT, 'w') as f:
        json.dump(
            {
                'episodes': episodes,
                'generatedAt': date.today().isoformat(),
                'source': 'soundcloud-rss',
            },
            f,
            ensure_ascii=False,
        )
    print(f'{len(episodes)} episodes -> {OUT}')


if __name__ == '__main__':
    main()
