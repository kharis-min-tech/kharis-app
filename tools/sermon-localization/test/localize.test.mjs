import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, writeFile, readFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { main, makeManifest, selectSermon } from '../localize.mjs';

const job = { sermonId: '123', title: 'Message', sourceAudioUrl: 'https://cdn.example/original.mp3', durationSeconds: 90 };

test('manifest binds reviewed French media to the exact original MP3', () => {
  const result = makeManifest(job, 'https://cdn.example/123/fr-v1', true);
  assert.equal(result.sourceAudioUrl, job.sourceAudioUrl);
  assert.equal(result.timeline, 'audio');
  assert.equal(result.tracks[0].audioUrl, 'https://cdn.example/123/fr-v1/fr.mp3');
  assert.equal(result.tracks[0].reviewed, true);
  assert.throws(() => makeManifest(job, 'https://cdn.example', false), /Review/);
  for (const base of ['http://cdn.example', 'https://cdn.example/?signature=expiring', 'https://user:secret@cdn.example']) {
    assert.throws(() => makeManifest(job, base, true), /HTTPS/);
  }
});

test('catalogue source is the sermon audio, not the full YouTube service', () => {
  const source = selectSermon({ messages: [{ id: 123, audio_url: job.sourceAudioUrl,
    video_url: 'https://youtube.com/watch?v=test&t=200', title: 'Message' }] }, '123');
  assert.equal(source.sourceAudioUrl, job.sourceAudioUrl);
  assert.throws(() => selectSermon({ messages: [] }, 'missing'), /no original audio/);
});

test('paid create never runs without explicit flags and never repeats an uncertain POST', async () => {
  const dir = await mkdtemp(join(tmpdir(), 'kharis-dub-'));
  const originalFetch = globalThis.fetch;
  const oldKey = process.env.ELEVENLABS_API_KEY;
  let posts = 0;
  try {
    await writeFile(join(dir, 'job.json'), JSON.stringify(job));
    process.env.ELEVENLABS_API_KEY = 'test-not-a-real-key';
    globalThis.fetch = async (_url, options) => {
      assert.equal(options.method, 'POST');
      assert.equal(options.body.get('target_language'), 'fr');
      assert.equal(options.body.get('source_url'), job.sourceAudioUrl);
      posts++;
      throw new Error('Connection lost after sending request');
    };
    await assert.rejects(main(['create', '--out', dir]), /required/);
    await assert.rejects(main(['create', '--out', dir, '--allow-paid', '--voice-permission', '--max-source-minutes', '1']), /exceeds/);
    assert.equal(posts, 0);
    const args = ['create', '--out', dir, '--allow-paid', '--voice-permission'];
    await assert.rejects(main(args), /Connection lost/);
    await assert.rejects(main(args), /EEXIST/);
    assert.equal(posts, 1);
    const marker = JSON.parse(await readFile(join(dir, 'create-requested.json'), 'utf8'));
    assert.equal(marker.reference, 'kharis:123:fr');
  } finally {
    globalThis.fetch = originalFetch;
    if (oldKey === undefined) delete process.env.ELEVENLABS_API_KEY;
    else process.env.ELEVENLABS_API_KEY = oldKey;
    await rm(dir, { recursive: true, force: true });
  }
});
