/// Normalises the `meetingTime` field on a branch for display.
///
/// Two admin surfaces write the same Firestore field in different shapes and
/// neither can be retired without breaking the other:
///
/// * `admin/index.html` uses `<input type="time">`, which yields 24-hour
///   `'14:00'` (or `'14:00:00'` in some browsers).
/// * The Flutter admin panel and the bundled seed data use human 12-hour
///   `'2:00 PM'`.
///
/// Reading either shape must produce the same member-facing string, so the
/// read side normalises to 12-hour form. Anything that is not a recognised
/// 24-hour clock value is passed through untouched — an admin who typed
/// `'Sundays 10am & 6pm'` keeps exactly what they typed.
String? formatServiceTime(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;

  final match = RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2})?$').firstMatch(value);
  if (match == null) return value;

  final hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  if (hour > 23 || minute > 59) return value;

  final suffix = hour < 12 ? 'AM' : 'PM';
  final hour12 = hour % 12 == 0 ? 12 : hour % 12;
  return '$hour12:${minute.toString().padLeft(2, '0')} $suffix';
}

/// A single line describing when a branch meets, e.g. `Sundays · 2:00 PM`.
/// Returns `null` when neither part is set, so callers can omit the row
/// instead of rendering an empty label.
String? formatServiceSchedule(String? meetingDays, String? meetingTime) {
  final days = meetingDays?.trim();
  final time = formatServiceTime(meetingTime);
  final parts = [
    if (days != null && days.isNotEmpty) days,
    ?time,
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}
