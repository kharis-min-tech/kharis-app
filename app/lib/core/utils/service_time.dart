/// Normalises a service time for display on the 24-hour clock ("09:00",
/// "19:30").
///
/// Times arrive in two shapes: 24-hour `'14:00'` / `'14:00:00'` (the Content
/// Studio's `services.start_time`) and human 12-hour `'2:00 PM'` (older
/// stored values). Both read the same: `'14:00'`. Anything that is not a
/// recognised clock value is passed through untouched — an admin who typed
/// `'Sundays 10am & 6pm'` keeps exactly what they typed.
String? formatServiceTime(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;

  final match = RegExp(
    r'^(\d{1,2}):(\d{2})(?::\d{2})?\s*([AaPp][Mm])?$',
  ).firstMatch(value);
  if (match == null) return value;

  var hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  final half = match.group(3)?.toLowerCase();
  if (minute > 59) return value;
  if (half != null) {
    if (hour < 1 || hour > 12) return value;
    hour = hour % 12 + (half == 'pm' ? 12 : 0);
  } else if (hour > 23) {
    return value;
  }
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(hour)}:${two(minute)}';
}

/// A single line describing when a branch meets, e.g. `Sundays · 14:00`.
/// Returns `null` when neither part is set, so callers can omit the row
/// instead of rendering an empty label.
String? formatServiceSchedule(String? meetingDays, String? meetingTime) {
  final days = meetingDays?.trim();
  final time = formatServiceTime(meetingTime);
  final parts = [if (days != null && days.isNotEmpty) days, ?time];
  return parts.isEmpty ? null : parts.join(' · ');
}
