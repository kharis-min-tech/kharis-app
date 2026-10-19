# Deploying the Kharis Import Worker

These are the steps to actually put this on Cloudflare. Do these in order,
from inside this `cloudflare-worker/` folder.

## 1. Install the CLI and log in

```
npm install
npx wrangler login
```

This opens a browser window to authorize Wrangler against your Cloudflare
account.

## 2. Create the R2 bucket

```
npx wrangler r2 bucket create kharis-messages
```

Must match the `bucket_name` in `wrangler.toml`. If you want a different
name, change it in both places.

## 3. Set the manual-trigger secret

The Worker exposes `/run-import` so you can test it (or push a backfill
along) without waiting for the cron. The secret goes in an
`Authorization: Bearer <secret>` header, never in the URL, so it doesn't end
up in shell history or request logs. A missing or wrong secret gets a 401,
and so does every request while the secret isn't set:

```
npx wrangler secret put MANUAL_TRIGGER_SECRET
```

It'll prompt you to paste a value — use a long random string, not a real word.

## 4. Seeding the cache (optional)

Each run scrapes at most `SCRAPE_BATCH_LIMIT` sermon pages (150 by default)
and saves the scrape cache every 25 scrapes, so a cold start with an empty
cache simply fills in over several runs. `messages.json` is written on every
run from whatever detail is available, so new sermons appear straight away
and gain tags/related messages/transcripts as their pages are scraped.

You can upload a `.detail-cache.json` from a local `import.js` run to skip
most of that backfill:

```
npx wrangler r2 object put kharis-messages/_cache/detail-cache.json --file="C:\path\to\.detail-cache.json" --remote
```

**`--remote` is not optional** — every `wrangler r2 object` command defaults
to a local simulated bucket that the deployed Worker never sees.

Every run lists `transcripts/` in the bucket and checks each cached
`transcript_url` against it. A cached sermon whose transcript object isn't
there is re-scraped (and its link is left out of `messages.json` until the
transcript has been written), so seeding a cache without the transcripts
folder costs scrape time, not broken links.

## 5. Deploy

```
npx wrangler deploy
```

This uploads the Worker and registers the cron triggers (all UTC, see
`wrangler.toml`):

| Cron | When | Why |
|---|---|---|
| `0 22 * * 0` | Sunday 22:00 | Picks up the Sunday sermon the evening it's published |
| `0 6 * * 1,4` | Monday and Thursday 06:00 | A late Sunday upload, then a midweek sweep |
| `0 18 * * 1` | Monday 18:00 | A Monday upload, and a first chance at its transcript |

A sermon scraped before its transcript exists is re-scraped on every run
until it is 30 days old, so a transcript that's published days later is
still picked up. A failed scrape (error page, timeout, failed transcript
download) is never cached; it's retried on the next run.

### Limits to keep in mind

Each scrape is up to two outbound fetches plus one R2 write, so a 150-sermon
batch is a few hundred subrequests per run. That fits the Paid plan's
default of 1,000 per invocation, not the Free plan's 50. On the Free plan,
set `SCRAPE_BATCH_LIMIT` to around 10 in `wrangler.toml` and expect a cold
backfill to take many runs.

## 6. Test it manually

```
curl -H "Authorization: Bearer <your-secret>" \
  "https://kharis-import-worker.<your-subdomain>.workers.dev/run-import"
```

(The exact `.workers.dev` URL is printed by `wrangler deploy` when it
finishes.) Each call runs a full import but scrapes at most
`MANUAL_SCRAPE_LIMIT` sermon pages (25 by default), so it returns within
seconds with a JSON summary:

- `messagesCount`, `playlistsCount` (`null` when the playlists fetch failed)
- `scrapedThisRun`, `failedThisRun`, `remainingToScrape`, `reusedFromCache`
- `written` and `skipped`: which of `messages.json` / `playlists.json` were
  replaced
- `log`: the log lines

To backfill by hand, repeat the call until `remainingToScrape` is 0 (or
just let the crons work through it). Don't raise `MANUAL_SCRAPE_LIMIT` to
backfill in one go: if the request takes long enough that `curl` gives up,
Cloudflare cancels the run about 30 seconds after the client disconnects.
The cache is saved every 25 scrapes, so a cancelled run loses little.

## 7. Make the catalogue publicly readable

The Flutter app fetches `messages.json` and `transcripts/<id>.txt` over plain
HTTPS. Turning on the bucket's `r2.dev` public access (**R2 →
kharis-messages → Settings → Public Access**) works, but it publishes
everything in the bucket, including the Worker's internal
`_cache/detail-cache.json`, and `r2.dev` URLs are rate-limited and meant for
development.

Recommended setup:

1. **Settings → Custom Domains → Connect Domain** on the bucket, e.g.
   `media.<your-domain>` (the domain must be on the same Cloudflare
   account).
2. Restrict that hostname to the public files with a WAF custom rule on the
   zone (**Security → WAF → Custom rules**), action **Block**:

   ```
   (http.host eq "media.<your-domain>"
     and not (http.request.uri.path in {"/messages.json" "/playlists.json"}
              or starts_with(http.request.uri.path, "/transcripts/")))
   ```

3. Turn the `r2.dev` URL off (**Public Access → R2.dev subdomain →
   Disallow**) once the app reads from the custom domain. Update
   `kR2BucketBaseUrl` / `kR2MessagesUrl` in
   `app/lib/core/constants/http_constants.dart` in the same release, and
   keep `r2.dev` on until that release has reached users.

Either way, confirm it works with:

```
curl -I https://<your-public-url>/messages.json
curl -I https://<your-public-url>/_cache/detail-cache.json
```

The first should be a `200` with `content-type: application/json`; with the
custom-domain setup the second should be a `403`.

## Safety checks on every run

- A failed sermons fetch aborts the run before anything is written.
- `messages.json` and `playlists.json` are never replaced by an empty list
  or by one with under 90% of the existing file's records; the run logs an
  error and keeps the old file. If the catalogue really has shrunk that much,
  delete the object (`npx wrangler r2 object delete kharis-messages/messages.json --remote`)
  and run the import again.
- A failed playlists fetch keeps the existing `playlists.json`; a failed
  series fetch keeps series names from the existing `messages.json`.
- Every fetch times out after 15 seconds. Pagination stops with an error on
  a repeated `next` URL, a page without a `results` array, or more than 200
  pages.
- A failed cron run is logged with `console.error`, so it shows up in
  Workers Logs and can drive an alert.

## Checking on it later

```
npx wrangler tail
```

Streams live logs from the Worker — run this right before/during a cron
firing (or trigger `/run-import` manually) to watch it work.

## Tests

```
npm test
```

Runs the `node --test` suite in `test/` against in-memory fakes for `fetch`
and the R2 bucket. Needs Node 20 or newer.

## Repairing broken transcript links

If `messages.json` lists `transcript_url`s whose objects are missing (404s
in the app), just let the next run happen: it drops those links straight
away and re-scrapes the affected sermons in batches until the transcripts
are back.
