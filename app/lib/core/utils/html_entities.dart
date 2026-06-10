/// Decodes the handful of HTML entities that appear in RSS/YouTube titles.
///
/// Covers named and numeric forms seen in SoundCloud and YouTube feeds
/// (`&#39;`, `&amp;`, `&quot;`, …) without pulling in a full HTML parser.
String decodeHtmlEntities(String input) {
  if (!input.contains('&')) return input;
  var out = input
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&nbsp;', ' ');
  // Numeric character references, e.g. &#39; or &#x27;
  out = out.replaceAllMapped(RegExp(r'&#(x?)([0-9A-Fa-f]+);'), (m) {
    final isHex = m.group(1)!.isNotEmpty;
    final code = int.tryParse(m.group(2)!, radix: isHex ? 16 : 10);
    return code == null ? m.group(0)! : String.fromCharCode(code);
  });
  return out;
}
