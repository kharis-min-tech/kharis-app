import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';

/// The OS rating card (SKStoreReviewController / Play In-App Review).
///
/// Only ever called from an engagement moment, never from a button: both
/// stores forbid wiring it to a user action, and iOS may show nothing.
class StoreReview {
  const StoreReview();

  /// False on web and on devices without a store, so callers can fall back.
  Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    try {
      return await InAppReview.instance.isAvailable();
    } catch (e) {
      debugPrint('StoreReview: availability check failed: $e');
      return false;
    }
  }

  /// Asks the OS to show its rating card. Whether it actually appears is the
  /// platform's call; there is no result to read back.
  Future<void> request() async {
    try {
      await InAppReview.instance.requestReview();
    } catch (e) {
      debugPrint('StoreReview: request failed: $e');
    }
  }
}
