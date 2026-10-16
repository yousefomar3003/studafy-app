import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Before the Flutter engine starts Dart, which is what starts Sentry.
    CrashReportPrivacy.pinInstallationId()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}

/// Crash reports must not carry a per-install identifier: most people using
/// Studafy are children (lib/core/crash_reports.dart). Sentry's Cocoa SDK reads
/// its "installation id" from Caches/INSTALLATION and uses it as `user.id`
/// on a crash report that has no user, and as every session's `did`; crash
/// reports never pass through the Dart beforeSend. Writing one shared value
/// before Sentry starts makes that id the same for everyone. Checked against
/// sentry-cocoa 8.58.4 (sentry_flutter 9.30.1): SentryInstallation,
/// SentryClient setUserIdIfNoUserSet and SentryHub startSession; a test in
/// test/core/crash_reports_test.dart flags an upgrade for a re-check.
/// Kept in this file so the Xcode project needs no new source file.
enum CrashReportPrivacy {
  /// The same value on every install, so it identifies no one.
  static let sharedInstallationId = "00000000-0000-0000-0000-000000000000"

  static func pinInstallationId() {
    guard
      let caches = NSSearchPathForDirectoriesInDomains(
        .cachesDirectory, .userDomainMask, true
      ).first
    else { return }
    let path = (caches as NSString).appendingPathComponent("INSTALLATION")
    if (try? String(contentsOfFile: path, encoding: .utf8)) == sharedInstallationId {
      return
    }
    // Reports still carry the constant user set from Dart if this fails.
    try? sharedInstallationId.write(toFile: path, atomically: true, encoding: .utf8)
  }
}
