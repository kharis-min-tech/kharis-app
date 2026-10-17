/// The one gate every Content Studio image goes through before it reaches a
/// widget.
///
/// Studio rows can hold values the app must never try to load: bundled app
/// paths left over from the old Studio (`assets/design/city-brighton.jpg`),
/// development uploads (`http://localhost:3002/...`) and blanks. Anything that
/// is not an absolute `https://` URL on a real host returns null, and callers
/// hide the image.
String? usableMediaUrl(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;
  final uri = Uri.tryParse(value);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
  final host = uri.host.toLowerCase();
  if (host == 'localhost' ||
      host.endsWith('.localhost') ||
      host == '0.0.0.0' ||
      host == '[::1]' ||
      host == '::1' ||
      host.startsWith('127.')) {
    return null;
  }
  return value;
}
