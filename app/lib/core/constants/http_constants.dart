/// Browser-like User-Agent required for `yetanothersermon.host`.
///
/// The host (public sermon API + the `/media/mp3/*` redirect) sits behind
/// Cloudflare bot protection that returns **403** to non-browser agents such as
/// Dio's default `Dio/x.y.z`. Send this on every API call and on the audio
/// request so the request is allowed and the mp3 endpoint can 302-redirect to
/// its signed CDN URL.
const String kBrowserUserAgent =
    'Mozilla/5.0 (iPhone; CPU iPhone OS 18_6 like Mac OS X) '
    'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 '
    'Safari/604.1';

/// The public R2 bucket the Cloudflare import Worker
/// (`backend/cloudflare-worker/`) writes to. If this ever needs to move
/// (custom domain, bucket rename), this is the only line that has to change.
const String kR2BucketBaseUrl = 'https://pub-1cfba9da59dd4e03b1f867b35e26a1a4.r2.dev';

/// Where the sermon catalogue lives. [R2MessagesRepository] falls back to the
/// existing Kharis API repository automatically if it's ever unreachable.
const String kR2MessagesUrl = '$kR2BucketBaseUrl/messages.json';
