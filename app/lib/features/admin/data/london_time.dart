/// Europe/London wall-clock arithmetic for Content Studio dates.
///
/// The church schedules in UK time whatever timezone the admin's device is in,
/// so "expires on 12 Oct" means the end of 12 Oct in London and "publish at
/// 09:00" means 09:00 London. The app has no tz database, and the UK rule is
/// fixed: BST (UTC+1) runs from 01:00 UTC on the last Sunday of March to
/// 01:00 UTC on the last Sunday of October; GMT (UTC+0) otherwise.
library;

/// Day of the month of the last Sunday of [month] in [year].
int _lastSunday(int year, int month) {
  final last = DateTime.utc(year, month + 1, 0);
  return last.day - (last.weekday % 7);
}

/// True when the UTC instant [utc] falls inside British Summer Time.
bool isBritishSummerTime(DateTime utc) {
  final at = utc.toUtc();
  final start = DateTime.utc(at.year, 3, _lastSunday(at.year, 3), 1);
  final end = DateTime.utc(at.year, 10, _lastSunday(at.year, 10), 1);
  return !at.isBefore(start) && at.isBefore(end);
}

/// The UTC instant at which London's wall clock reads [date]'s calendar day at
/// [hour]:[minute]:[second].[millisecond]. Only the date part of [date] is used.
///
/// Inside the spring-forward gap (01:00 to 02:00 London on the last Sunday of
/// March) the result lands an hour later, which is the conventional reading.
DateTime londonWallTime(
  DateTime date,
  int hour, [
  int minute = 0,
  int second = 0,
  int millisecond = 0,
]) {
  final asUtc = DateTime.utc(
    date.year,
    date.month,
    date.day,
    hour,
    minute,
    second,
    millisecond,
  );
  // London is UTC or UTC+1, so the true instant is asUtc or an hour earlier.
  final summer = asUtc.subtract(const Duration(hours: 1));
  return isBritishSummerTime(summer) ? summer : asUtc;
}

/// The last millisecond of [date]'s calendar day in London: what an
/// announcement "expires on [date]" means.
DateTime londonEndOfDay(DateTime date) => londonWallTime(date, 23, 59, 59, 999);

/// [utc] as London wall-clock time, returned as a UTC-flagged [DateTime]
/// whose fields read as London's clock (for prefilling pickers).
DateTime toLondonWallClock(DateTime utc) {
  final at = utc.toUtc();
  return isBritishSummerTime(at) ? at.add(const Duration(hours: 1)) : at;
}
