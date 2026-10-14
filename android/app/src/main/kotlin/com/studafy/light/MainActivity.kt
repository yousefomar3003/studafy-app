package com.studafy.light

import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import java.io.File
import java.io.IOException

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Before the Flutter engine starts Dart, which is what starts Sentry.
        pinCrashReportInstallationId(filesDir)
        super.onCreate(savedInstanceState)
    }
}

/** The same value on every install, so it identifies no one. */
private const val SHARED_INSTALLATION_ID = "00000000-0000-0000-0000-000000000000"

/**
 * Crash reports must not carry a per-install identifier: most people using
 * Studafy are children (lib/core/crash_reports.dart). Sentry's Android SDK
 * reads its "installation id" from files/INSTALLATION and puts it in
 * `user.id` when no user is set, in `device.id`, and in every session's
 * `did`, including on NDK crashes, ANRs and tombstones, which never pass
 * through the Dart beforeSend. Writing one shared value before Sentry starts
 * makes that id the same for everyone. Checked against sentry-android 8.56.0
 * (sentry_flutter 9.30.1): Installation.id, DeviceInfoUtil, the
 * DefaultAndroidEventProcessor and AndroidOptionsInitializer; a test in
 * test/core/crash_reports_test.dart flags an upgrade for a re-check.
 */
private fun pinCrashReportInstallationId(filesDir: File) {
    val file = File(filesDir, "INSTALLATION")
    try {
        if (!file.exists() || file.readText() != SHARED_INSTALLATION_ID) {
            file.writeText(SHARED_INSTALLATION_ID)
        }
    } catch (e: IOException) {
        // Reports still carry the constant user set from Dart; never stop the
        // app over this.
        Log.w("Studafy", "Could not pin the crash report installation id", e)
    }
}
