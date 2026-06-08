import 'package:firebase_core/firebase_core.dart';

/// Toggle this to `true` once `google-services.json` (Android) and
/// `GoogleService-Info.plist` (iOS) are in place.  When `false` the app runs
/// entirely on mock / local data and no Firebase SDK calls are made.
const bool kUseFirebase = false;

class FirebaseService {
  FirebaseService._();

  /// Initialises the Firebase app.  Must be called before any Firebase usage.
  /// Requires platform config files to be present; will throw otherwise.
  static Future<void> init() async {
    await Firebase.initializeApp();
  }
}
