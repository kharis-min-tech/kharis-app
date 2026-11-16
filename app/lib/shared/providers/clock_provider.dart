import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The device clock. Everything that keeps a local calendar day (streaks,
/// reminders, saved dates) reads the time through this, so tests can set it.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
