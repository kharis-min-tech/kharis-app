import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

/// Backend Cloud Functions configuration.
///
/// Every `getX` endpoint lives in ONE Firebase project. Keep that project name
/// here rather than repeating the host in each repository — commit e91366f
/// re-pointed the app's Firebase SDK at a different project while these URLs
/// stayed behind, which split the data layer in two: HTTP reads came from one
/// project while Firestore reads, auth and FCM came from another. The symptom
/// was content appearing briefly (API) and then being replaced by empty or
/// stale data (Firestore), plus push notifications that could never arrive.
abstract final class ApiConfig {
  /// Firebase project that hosts the Cloud Functions and Firestore data.
  static const String backendProjectId = 'kharis-church';

  static const String region = 'us-central1';

  static const String _base =
      'https://$region-$backendProjectId.cloudfunctions.net';

  static const String getSermons = '$_base/getSermons';
  static const String getAnnouncements = '$_base/getAnnouncements';
  static const String getBranches = '$_base/getBranches';
  static const String getEvents = '$_base/getEvents';
  static const String getDailyReading = '$_base/getDailyReading';

  /// True when the Firebase SDK is configured against a different project than
  /// the one serving the HTTP API. In that state Firestore, Auth and FCM all
  /// talk to a project that holds none of the content, and FCM topics resolve
  /// in the wrong namespace so pushes are silently undeliverable.
  static bool get isProjectSplit =>
      DefaultFirebaseOptions.currentPlatform.projectId != backendProjectId;

  /// Logs a prominent startup banner when the SDK project and the API project
  /// disagree.
  ///
  /// Deliberately does NOT throw: the original failure mode was silence, not
  /// insufficient severity, and asserting here would abort startup before
  /// `runApp` and brick the app for anyone doing unrelated UI work.
  static void warnIfProjectSplit() {
    if (!isProjectSplit) return;
    final sdk = DefaultFirebaseOptions.currentPlatform.projectId;
    debugPrint(
      '\n'
      '========================= FIREBASE PROJECT SPLIT =========================\n'
      ' Firebase SDK project : $sdk\n'
      ' Cloud Functions API  : $backendProjectId\n'
      '\n'
      ' Firestore, Auth and FCM are talking to "$sdk", which holds none of the\n'
      ' content the API returns. Expect content to appear then vanish, admin\n'
      ' writes to go missing, and push notifications never to arrive.\n'
      '\n'
      ' Fix: run `flutterfire configure --project=$backendProjectId` in app/\n'
      '==========================================================================\n',
    );
  }
}
