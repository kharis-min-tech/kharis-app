import 'package:firebase_core/firebase_core.dart';
import '../../../firebase_options.dart';

/// Toggle this to `true` once you've run `flutterfire configure`.
/// When `false` the app runs entirely on mock / local data.
const bool kUseFirebase = true;

class FirebaseService {
  FirebaseService._();

  /// Initialises the Firebase app using FlutterFire CLI generated options.
  /// Run `flutterfire configure` first to generate `lib/firebase_options.dart`.
  static Future<void> init() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}
