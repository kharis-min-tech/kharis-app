// GENERATED FILE — DO NOT EDIT
// Run `flutterfire configure` to regenerate this file with your Firebase project.
//
// This stub allows the app to compile before Firebase is configured.
// Once you run `flutterfire configure`, this file will be overwritten with
// your actual project configuration.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'run flutterfire configure to generate firebase_options.dart',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // ── Stub values — replaced by flutterfire configure ─────────────────────────

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCSTb4h3uc2tf7-BqU9lKpZUT15OBZlXXQ',
    appId: '1:193550520841:web:869bfc2bb60d69e4689ed8',
    messagingSenderId: '193550520841',
    projectId: 'kharis-church',
    authDomain: 'kharis-church.firebaseapp.com',
    storageBucket: 'kharis-church.firebasestorage.app',
    measurementId: 'G-SXL76TWT0W',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC-BfsQ5dGkmcYVX87QMDz5k0gAxDG9ETQ',
    appId: '1:193550520841:android:6d53c36ad3ddb7a5689ed8',
    messagingSenderId: '193550520841',
    projectId: 'kharis-church',
    storageBucket: 'kharis-church.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyApB73NdGgLA_cHk_DxT9gmSpijuiYuSI8',
    appId: '1:193550520841:ios:9ec20dbafea0225e689ed8',
    messagingSenderId: '193550520841',
    projectId: 'kharis-church',
    storageBucket: 'kharis-church.firebasestorage.app',
    iosBundleId: 'org.kharis.kharisApp',
  );
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyApB73NdGgLA_cHk_DxT9gmSpijuiYuSI8',
    appId: '1:193550520841:ios:9ec20dbafea0225e689ed8',
    messagingSenderId: '193550520841',
    projectId: 'kharis-church',
    storageBucket: 'kharis-church.firebasestorage.app',
    iosBundleId: 'org.kharis.kharisApp',
  );
  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'PLACEHOLDER',
    appId: 'PLACEHOLDER',
    messagingSenderId: 'PLACEHOLDER',
    projectId: 'kharis-church',
    storageBucket: 'kharis-church.appspot.com',
  );
}
