# Deploying the Kharis Import Worker

These are the steps to actually put this on Cloudflare. Nothing has been run
yet — do these in order, from inside this `cloudflare-worker/` folder.

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

The Worker exposes `GET /run-import?secret=...` so you can test it (or force
a backfill) without waiting for the Monday/Thursday cron. Anyone who guesses
this URL without the secret gets a 401, so set a real one:

```
npx wrangler secret put MANUAL_TRIGGER_SECRET
```

It'll prompt you to paste a value — use a long random string, not a real word.

## 4. Seed the cache (important — do this before the first real run)

The very first import has to scrape all ~1,482 sermons' detail pages, which
is a lot for one Worker invocation to do cold. You already have this work
done locally (`Downloads/.detail-cache.json` and `Downloads/transcripts/`,
from testing `import.js`) — upload it so the Worker's first live run only
has to handle sermons that are new since then, same as every run after:

```
npx wrangler r2 object put kharis-messages/_cache/detail-cache.json --file=../.detail-cache.json

for f in ../transcripts/*.txt; do
  id=$(basename "$f")
  npx wrangler r2 object put "kharis-messages/transcripts/$id" --file="$f" --content-type="text/plain; charset=utf-8"
done
```

(Run that loop from Git Bash / WSL — it's a plain shell `for` loop, not a
Wrangler feature. On plain PowerShell you'd write the equivalent
`foreach ($f in Get-ChildItem ../transcripts/*.txt) { ... }`.)

This will take a while (1,477 individual uploads) — that's expected, it's a
one-time seed.

## 5. Deploy

```
npx wrangler deploy
```

This uploads the Worker and registers the cron trigger. From this point on,
it runs automatically every Monday and Thursday at 06:00 UTC — no further
action needed for it to keep working.

## 6. Test it manually

```
curl "https://kharis-import-worker.<your-subdomain>.workers.dev/run-import?secret=<your-secret>"
```

(The exact `.workers.dev` URL is printed by `wrangler deploy` when it
finishes.) This runs the import immediately and returns a JSON summary
(counts, log lines) — use it to confirm everything works before waiting for
the actual cron day.

## 7. Make the bucket publicly readable

The Flutter app needs to fetch `messages.json` over plain HTTPS. In the
Cloudflare dashboard: **R2 → kharis-messages → Settings → Public Access →
Allow Access** (gives you a `pub-xxxx.r2.dev` URL), or attach a custom domain
under the same Settings tab if you'd rather have a branded URL. Either way,
confirm it works with:

```
curl -I https://<your-public-url>/messages.json
```

You should get a `200` with `content-type: application/json`.

## Checking on it later

```
npx wrangler tail
```

Streams live logs from the Worker — run this right before/during a cron
firing (or trigger `/run-import` manually) to watch it work.
