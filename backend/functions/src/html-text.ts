/**
 * Upstream strings (YouTube API, the WordPress site) arrive HTML-entity-encoded
 * (&#39; &amp; &#8211; ...). Decode them once at the boundary so Firestore
 * stores clean text.
 */
export function decodeHtmlEntities(s: string): string {
  return s
    .replace(/&#(\d+);/g, (entity, n) => fromCodePoint(entity, parseInt(n, 10)))
    .replace(/&#x([0-9a-f]+);/gi, (entity, n) => fromCodePoint(entity, parseInt(n, 16)))
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&nbsp;/g, ' ')
    // Last, so an escaped entity (`&amp;lt;`) decodes to its literal text.
    .replace(/&amp;/g, '&');
}

/**
 * The character for a numeric entity, or the entity left as-is when the
 * number is not a code point (`String.fromCodePoint` throws a RangeError
 * above 0x10FFFF, which would abort a whole sync run).
 */
function fromCodePoint(entity: string, code: number): string {
  return Number.isInteger(code) && code >= 0 && code <= 0x10ffff
    ? String.fromCodePoint(code)
    : entity;
}

/** Plain text of an HTML fragment: tags dropped, block breaks kept, decoded. */
export function htmlToText(html: string): string {
  return decodeHtmlEntities(
    html
      .replace(/<(script|style)[^>]*>[\s\S]*?<\/\1>/gi, '')
      .replace(/<br\s*\/?>/gi, '\n')
      .replace(/<\/(p|div|li|h[1-6])>/gi, '\n')
      .replace(/<[^>]+>/g, ''),
  )
    .replace(/[ \t]+/g, ' ')
    .replace(/\s*\n\s*/g, '\n')
    .trim();
}
