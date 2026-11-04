import { parseArgs } from 'node:util';
import { mkdir, readFile, writeFile, open, stat } from 'node:fs/promises';
import { resolve, join } from 'node:path';
import { fileURLToPath } from 'node:url';

export const BUCKET = 'https://pub-1cfba9da59dd4e03b1f867b35e26a1a4.r2.dev';
const API = 'https://api.elevenlabs.io/v1/dubbing/project';

async function json(url, options = {}) {
  const response = await fetch(url, { signal: AbortSignal.timeout(60_000), ...options });
  // Don't log signed URLs, API keys or provider response bodies on failure.
  if (!response.ok) throw new Error(`Request failed (${response.status}). No automatic retry was sent.`);
  return response.json();
}

export function selectSermon(catalogue, id) {
  const sermon = catalogue.messages?.find((m) => String(m.id) === id);
  if (!sermon || !sermon.audio_url?.trim()) throw new Error('Sermon has no original audio in the Kharis catalogue.');
  const url = new URL(sermon.audio_url.trim());
  if (url.protocol !== 'https:') throw new Error('Original audio must use HTTPS.');
  return { sermonId: id, title: sermon.title, sourceAudioUrl: sermon.audio_url.trim(),
    videoUrl: sermon.video_url ?? null, durationSeconds: sermon.duration ?? null };
}

export function makeManifest(job, publicBase, reviewed) {
  if (!reviewed) throw new Error('Review the translation, Scripture references, timing and audio first.');
  const base = new URL(publicBase);
  if (base.protocol !== 'https:' || base.search || base.hash || base.username || base.password) {
    throw new Error('Use a permanent public HTTPS directory, not an expiring signed URL.');
  }
  const root = base.href.replace(/\/$/, '');
  return { schemaVersion: 1, sermonId: job.sermonId, sourceAudioUrl: job.sourceAudioUrl,
    timeline: 'audio', tracks: [{ language: 'fr', label: 'Français',
      audioUrl: `${root}/fr.mp3`, subtitlesUrl: `${root}/fr.vtt`, reviewed: true }] };
}

async function save(path, value) {
  await writeFile(path, JSON.stringify(value, null, 2) + '\n');
}

async function provider(path = '', options = {}) {
  const key = process.env.ELEVENLABS_API_KEY;
  if (!key) throw new Error('Set ELEVENLABS_API_KEY in the operator environment. Never put it in the app.');
  return json(API + path, { ...options, headers: { 'xi-api-key': key, ...options.headers } });
}

async function download(url, path) {
  if (!url || new URL(url).protocol !== 'https:') throw new Error('Provider did not return an HTTPS output URL.');
  const response = await fetch(url, { signal: AbortSignal.timeout(300_000) });
  if (!response.ok) throw new Error(`Download failed (${response.status}). Run collect again; do not recreate the job.`);
  const file = await open(path, 'w');
  try { for await (const chunk of response.body) await file.write(chunk); }
  finally { await file.close(); }
}

export async function main(argv) {
  const { values: args, positionals } = parseArgs({ args: argv, allowPositionals: true, options: {
    'sermon-id': { type: 'string' }, out: { type: 'string', default: 'localization-work' },
    'public-base': { type: 'string' }, reviewed: { type: 'boolean' },
    'allow-paid': { type: 'boolean' }, 'voice-permission': { type: 'boolean' },
    'max-source-minutes': { type: 'string', default: '3' },
  } });
  const command = positionals[0];
  if (command === 'discover') {
    // Cataloguing only: this never downloads YouTube audio or changes the channel.
    process.env.API_ANYTHING_HOME ??= resolve(args.out, '.api-anything');
    const { Agent, setGlobalDispatcher } = await import('undici');
    // YouTube responses exceeded Node's default response-header limit in testing.
    setGlobalDispatcher(new Agent({ maxHeaderSize: 128 * 1024 }));
    const { call } = await import('api-anything');
    const result = await call('youtube', 'listChannelVideos', { handle: 'davidantwi' }, { maxTier: 1 });
    if (!result.ok) throw new Error(`api-anything: ${result.class}: ${result.reason}. ${result.next ?? ''}`);
    console.log(JSON.stringify(result.data, null, 2));
    return;
  }
  if (!['prepare', 'create', 'collect', 'manifest'].includes(command)) {
    throw new Error('Commands: discover | prepare --sermon-id ID --out DIR | create --out DIR --allow-paid --voice-permission --max-source-minutes N | collect --out DIR | manifest --out DIR --public-base HTTPS_DIRECTORY --reviewed');
  }
  const dir = resolve(args.out);
  await mkdir(dir, { recursive: true });
  const jobFile = join(dir, 'job.json');
  if (command === 'prepare') {
    if (!args['sermon-id']) throw new Error('Pass --sermon-id from the Kharis messages catalogue.');
    const source = selectSermon(await json(`${BUCKET}/messages.json`), args['sermon-id']);
    // Refuse overwrites: a paid request with an uncertain outcome must not be repeated.
    const file = await open(jobFile, 'wx');
    try { await file.writeFile(JSON.stringify({ ...source, language: 'fr' }, null, 2) + '\n'); }
    finally { await file.close(); }
    console.log(`Prepared ${source.sermonId}: ${source.title}. No generation or publishing has run.`);
    return;
  }
  const job = JSON.parse(await readFile(jobFile, 'utf8'));
  if (command === 'create') {
    if (!args['allow-paid'] || !args['voice-permission']) {
      throw new Error('ElevenLabs dubbing can charge credits and preserve the speaker’s voice. --allow-paid and --voice-permission are required. Use local-dub.py for a stock French narrator without API fees.');
    }
    const limit = Number(args['max-source-minutes']);
    if (!(limit > 0) || !(job.durationSeconds > 0) || job.durationSeconds > limit * 60) {
      throw new Error('Unknown duration or source exceeds --max-source-minutes. Verify source duration before creating a paid job.');
    }
    if (job.projectId) throw new Error('This job already has a project. Use collect.');
    if (!process.env.ELEVENLABS_API_KEY) throw new Error('Set ELEVENLABS_API_KEY first.');
    // Exclusive marker survives timeout/crash. POST has no documented idempotency
    // guarantee: never retry it automatically, even after an uncertain response.
    const marker = await open(join(dir, 'create-requested.json'), 'wx');
    await marker.writeFile(JSON.stringify({ requestedAt: new Date().toISOString(), reference: `kharis:${job.sermonId}:fr` }));
    await marker.close();
    const form = new FormData();
    form.set('source_url', job.sourceAudioUrl);
    form.set('source_language', 'en');
    form.set('target_language', 'fr');
    form.set('model_id', 'dubbing_v2');
    form.set('reference', `kharis:${job.sermonId}:fr`);
    for (const term of ['Kharis', 'David Antwi', 'Jesus Christ']) form.append('keyterms', term);
    const project = await provider('', { method: 'POST', body: form });
    if (!project.project_id) throw new Error('Provider did not return a project ID. Check its dashboard before doing anything else.');
    await save(jobFile, { ...job, projectId: project.project_id });
    console.log(`Project recorded. Run collect later to check progress; do not run create again.`);
  } else if (command === 'collect') {
    if (!job.projectId) throw new Error('No project ID. If create-requested.json exists, reconcile the request in ElevenLabs before retrying.');
    const path = `/${encodeURIComponent(job.projectId)}`;
    const project = await provider(path);
    if (project.status === 'failed') throw new Error('Source preparation failed. Check the ElevenLabs dashboard.');
    if (project.status !== 'ready') { console.log(`Source: ${project.status}. Check again later.`); return; }
    const languages = await provider(path + '/language');
    const language = languages.languages?.find((l) => l.target_language === 'fr');
    if (!language) throw new Error('No French target returned. Check the project dashboard; do not recreate it.');
    const target = await provider(path + '/language/' + encodeURIComponent(language.language_id));
    if (target.status !== 'completed') { console.log(`French: ${target.status}. Check again later.`); return; }
    if (target.stale || target.output_revision !== target.revision) throw new Error('Output is stale. Review the project in ElevenLabs.');
    const outputUrl = (item) => typeof item === 'string' ? item : item?.url;
    // Re-fetching the target refreshes its short-lived signed output URLs.
    await download(outputUrl(target.outputs?.lossless_audio), join(dir, 'fr-source.wav'));
    await download(outputUrl(target.outputs?.subtitles), join(dir, 'fr.vtt'));
    console.log('Downloaded fr-source.wav and fr.vtt. Convert audio to fr.mp3 with FFmpeg, then review both before manifest.');
  } else {
    for (const file of ['fr.mp3', 'fr.vtt']) {
      if (!(await stat(join(dir, file))).size) throw new Error(`${file} is empty.`);
    }
    const manifest = makeManifest(job, args['public-base'], args.reviewed);
    if (!(await readFile(join(dir, 'fr.vtt'), 'utf8')).replace(/^\uFEFF/, '').startsWith('WEBVTT')) {
      throw new Error('fr.vtt is not WebVTT.');
    }
    await save(join(dir, `${encodeURIComponent(job.sermonId)}.json`), manifest);
    console.log('Manifest written locally. Upload media first; publish the manifest last. No remote files were changed.');
  }
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main(process.argv.slice(2)).catch((error) => { console.error(error.message); process.exitCode = 1; });
}
