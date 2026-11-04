# French sermon audio and subtitles

The Flutter audio player now has **Audio & subtitles** below its transport.
Members can select English (original) or a published French dub, and choose
French subtitles independently. Switching audio preserves the queue, position,
playback speed and pause state. A failed dub restores the previous recording.
Language selection lasts for the audio service's lifetime; subtitles start off.

This is an operator workflow: translations are generated once and hosted as media,
not regenerated for each listener. No provider key belongs in the Flutter app.
Until media is generated and published, the app reports that French is unavailable.

## 1. Identify the recording

Use Node 22.13+ and install the dependencies in this directory:

```sh
npm ci
node localize.mjs discover
```

`discover` uses the requested [api-anything repository](https://github.com/goodnight000/api-anything)
at a pinned commit to read `@davidantwi` uploads. The npm 0.3.2 release only bundled
YouTube search, so this tool pins the repository version with channel operations.
Discovery runs anonymously over HTTP and stops if YouTube refuses or changes its
page. It does not download YouTube audio. Its local state stays under `--out`.

During verification, YouTube's response exceeded Node's default header size;
raising that limit resolved the transport error, but the channel operation then
reported `drift: embedded data not found`. Discovery therefore remains dependent
on api-anything's YouTube operation being repaired. Generation can use the app's
working [messages catalogue](https://pub-1cfba9da59dd4e03b1f867b35e26a1a4.r2.dev/messages.json)
without channel discovery. Match a video's ID against `video_url`, then use that
record's `id`:

```sh
node localize.mjs prepare --sermon-id 103367 --out localization-work/103367
```

This example is **The Portraits Of Christ - Part 1** (46m42s in the catalogue).
`prepare` records the original MP3 URL, sermon ID and duration in `job.json`.
It never creates a paid job. Existing jobs cannot be overwritten.

Use the sermon MP3 rather than an entire YouTube service: this app's video can
start far into the service, while the audio, notes and dub use the sermon timeline.

## 2A. Local generation without API fees

This route uses an ordinary French narrator. It does not reproduce David Antwi's
voice or preserve the congregation/background mix. Compute, model downloads,
media storage and bandwidth still have costs. Translation quality needs review.

Install Python 3.11/3.12, FFmpeg and FFprobe (both on PATH), then:

```sh
python -m venv .venv
# Activate .venv (Windows: .venv\Scripts\activate; macOS/Linux: source .venv/bin/activate)
pip install -r requirements.txt
argospm update
argospm install translate-en_fr
python -m piper.download_voices fr_FR-siwis-medium --download-dir models
python local-dub.py --out localization-work/103367 --voice models/fr_FR-siwis-medium.onnx
```

Check the chosen Piper voice's model card/license before publishing. The Whisper
model downloads on first use. Later runs can work locally with models installed.
The script transcribes English, translates to French, synthesizes each segment,
and preserves the source timing and silences in `fr.mp3` and `fr.vtt` (WebVTT).
It refuses overlapping segments or a dub needing more than 1.8x speech speed,
instead of dropping words. It saves `segments.json` for corrections:

```sh
python local-dub.py --out localization-work/103367 --voice models/fr_FR-siwis-medium.onnx --segments localization-work/103367/segments.json
```

`--input /path/to/original.mp3` can supply the exact original recording when the
sermon host refuses automated downloads. A mismatched catalogue duration is
rejected. Keep model files, recordings and operator outputs out of Git.

## 2B. ElevenLabs dubbing

Use this when the church wants a dub preserving the source speaker's delivery
and has permission to use that voice. Set `ELEVENLABS_API_KEY` only in the operator
environment. The create command requires explicit paid-operation and voice-use
flags, plus a duration ceiling. The default ceiling is three minutes, so the
full-length example below needs an intentional increase:

```sh
node localize.mjs create --out localization-work/103367 --allow-paid --voice-permission --max-source-minutes 47
node localize.mjs collect --out localization-work/103367
```

`create` submits one English-to-French `dubbing_v2` project. Creation itself is
chargeable. At verification, the [official API pricing](https://elevenlabs.io/pricing/api)
listed v2 at $2.20/source minute: roughly $103 for a 46m42s message in one language,
before tax and plan-specific allowances. This is not an unlimited free service.

`collect` checks status once and downloads completed French WAV and WebVTT
outputs. Run it later if processing is still in progress. It never submits another
generation request. Convert the WAV for the app:

```sh
ffmpeg -i localization-work/103367/fr-source.wav -c:a libmp3lame -b:a 128k localization-work/103367/fr.mp3
```

Do not delete `create-requested.json` to retry an uncertain create. If a connection
fails after submission, check ElevenLabs for reference `kharis:103367:fr`, recover
its project ID into `job.json` as `projectId`, then use `collect`. There is no
documented POST idempotency guarantee; the marker prevents accidental rebilling.

## 3. Review and publish

A French-speaking reviewer should check the recording, Bible references, names,
meaning and timing before setting `--reviewed`. Use a versioned public directory:

```sh
node localize.mjs manifest --out localization-work/103367 --public-base https://pub-1cfba9da59dd4e03b1f867b35e26a1a4.r2.dev/dubs/103367/v1 --reviewed
```

This writes `103367.json` locally. Upload `fr.mp3` and `fr.vtt` to that directory
first, then publish `103367.json` to `localizations/103367.json` in the existing
`kharis-messages` R2 bucket. For example, from `backend/cloudflare-worker` with an
authorized Wrangler session:

```sh
npx wrangler r2 object put kharis-messages/dubs/103367/v1/fr.mp3 --file=../../tools/sermon-localization/localization-work/103367/fr.mp3 --content-type=audio/mpeg --remote
npx wrangler r2 object put kharis-messages/dubs/103367/v1/fr.vtt --file=../../tools/sermon-localization/localization-work/103367/fr.vtt --content-type=text/vtt --remote
npx wrangler r2 object put kharis-messages/localizations/103367.json --file=../../tools/sermon-localization/localization-work/103367/103367.json --content-type=application/json --remote
```

Configure bucket CORS to allow GET/HEAD from the deployed Flutter web origin,
including the subtitle and manifest objects. MP3 responses must support byte-range
requests for seeking. Native apps also need the published media to be accessible.
The existing catalogue importer never writes `localizations/` or `dubs/`.

The player accepts only reviewed HTTPS tracks whose manifest matches the exact
original audio URL and declares the audio timeline. A missing manifest means no
published translations. A network failure offers Retry rather than claiming that
no translation exists. Republishing a versioned track avoids stale media caches.
Unpublish by removing the manifest (currently playing audio can finish).

## YouTube video language tracks

This change adds independent language controls to the app's **audio** player.
Video remains in YouTube's player with its native controls; the app does not play
a second audio engine over the embedded video. To offer the same Netflix-style
choice directly on the channel, its owner must publish French audio/subtitles
through YouTube Studio, or enable automatic dubbing if eligible.
[YouTube supports English-to-French automatic dubbing](https://support.google.com/youtube/answer/15569972?hl=en),
with eligibility limits including videos over 120 minutes. Availability for this
specific channel has not been verified. For manually uploaded full-service
tracks, adjust the sermon-only output to the full video timeline first; do not
upload a shortened sermon dub as if it were aligned to the entire service.

## Verification

```sh
npm test
python -m unittest discover -s test -p 'test_*.py'
# From app/:
flutter analyze
flutter test test/sermon_localization_test.dart test/player_ui_test.dart
```

Tests cover reviewed-manifest validation, VTT timing/escaping, same-position
audio switching, rollback after a failed French stream, independent captions,
and refusing duplicate/uncertain paid requests. Live ElevenLabs generation and
local model inference require provider credentials/model installation and are
not exercised by the unit tests. No media has been published by this change.
