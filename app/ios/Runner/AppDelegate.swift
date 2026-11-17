import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // With the implicit engine, plugins register after launch, so
    // firebase_messaging never sees UIApplicationDidFinishLaunching and never
    // asks for an APNs token itself (every topic call then fails with
    // apns-token-not-set). Register here; FlutterAppDelegate forwards the
    // token callback to the plugin once it is registered.
    application.registerForRemoteNotifications()
    // Event reminders (flutter_local_notifications) hear about a tapped
    // reminder through this delegate. Set before any plugin registers:
    // firebase_messaging then leaves it in place and receives its own
    // callbacks through FlutterAppDelegate, as the reminders plugin does.
    // FlutterAppDelegate conforms (FlutterAppLifeCycleProvider refines
    // UNUserNotificationCenterDelegate), so no cast: a break won't compile.
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
