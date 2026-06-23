import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Fetches [url] as plain text using the browser Fetch API.
///
/// `fetch` is invoked through [globalContext] so it keeps `globalThis` as its
/// receiver (a bare binding throws "Illegal invocation"). Cross-origin feeds
/// that omit CORS headers throw here; callers fall back to bundled content.
Future<String> fetchFeed(String url) async {
  final response = await globalContext
      .callMethod<JSPromise<JSObject>>('fetch'.toJS, url.toJS)
      .toDart;
  final text =
      await response.callMethod<JSPromise<JSString>>('text'.toJS).toDart;
  return text.toDart;
}
