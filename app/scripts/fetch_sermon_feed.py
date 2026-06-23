#!/usr/bin/env python3
"""Regenerates assets/data/kharis_sermons.json with the FULL catalogue.

Pages the public SoundCloud API for every track on kharismedia
(1,470+ episodes back to Sep 2013) and constructs stable
feeds.soundcloud.com stream URLs, which work for all public tracks
regardless of RSS feed membership (verified on 2013-2026 uploads).

Run before each release so web builds ship the complete catalogue.

    python3 scripts/fetch_sermon_feed.py
"""
import json
import os
import re
import urllib.request
from datetime import date

USER_ID = 58625221
PROFILE = 'https://soundcloud.com/kharismedia'
UA = {'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)'}
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'data',
                   'kharis_sermons.json')


def http_get(url: str) -> bytes:
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=60) as resp:
        return resp.read()


def scrape_client_id() -> str:
    """Pulls a public client_id out of soundcloud.com's JS bundles."""
    home = http_get(PROFILE).decode('utf-8', 'replace')
    scripts = re.findall(
        r'src="(https://a-v2\.sndcdn\.com/assets/[^"]+\.js)"', home)
    for src in reversed(scripts):
        js = http_get(src).decode('utf-8', 'replace')
        m = re.search(r'client_id[=:"]+([A-Za-z0-9]{32})', js)
        if m:
            return m.group(1)
    raise RuntimeError('client_id not found in SoundCloud JS bundles')


def fetch_all_tracks(client_id: str) -> list:
    tracks = []
    url = (f'https://api-v2.soundcloud.com/users/{USER_ID}/tracks'
           f'?client_id={client_id}&limit=200&linked_partitioning=1')
    while url:
        data = json.loads(http_get(url))
        tracks.extend(data['collection'])
        url = data.get('next_href')
        if url and 'client_id' not in url:
            url += f'&client_id={client_id}'
    return tracks


def main() -> None:
    client_id = scrape_client_id()
    tracks = fetch_all_tracks(client_id)

    episodes, seen = [], set()
    for t in tracks:
        url = (f"https://feeds.soundcloud.com/stream/"
               f"{t['id']}-kharismedia-{t['permalink']}.mp3")
        if url in seen:
            continue
        seen.add(url)
        title = (t.get('title') or '').strip()
        desc = re.sub(r'\s+', ' ', (t.get('description') or '')).strip()[:200]
        art = t.get('artwork_url')
        if not art:
            # Tracks without custom art fall back to the uploader's avatar,
            # exactly as SoundCloud does, so every episode shows real imagery.
            art = (t.get('user') or {}).get('avatar_url')
        if art:
            art = art.replace('-large.', '-t500x500.')
        episodes.append({
            'title': title,
            'audioUrl': url,
            'durationSeconds': round((t.get('duration') or 0) / 1000),
            'publishedAt': t.get('created_at', ''),
            'artworkUrl': art,
            'speaker':
                'Awo Antwi' if 'awo' in title.lower() else 'David Antwi',
            'description': desc,
        })

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, 'w') as f:
        json.dump(
            {
                'episodes': episodes,
                'generatedAt': date.today().isoformat(),
                'source': 'soundcloud-api',
            },
            f,
            ensure_ascii=False,
        )
    print(f'{len(episodes)} episodes -> {OUT}')


if __name__ == '__main__':
    main()
