package com.studafy.light

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.ActivityNotFoundException
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Before the Flutter engine starts Dart, which is what starts Sentry.
        pinCrashReportInstallationId(filesDir)
        super.onCreate(savedInstanceState)
        createNotificationChannel()
    }

    /**
     * The channel push notifications are posted to, named as Firebase's
     * default in the manifest and on every message the worker sends
     * (ANDROID_NOTIFICATION_CHANNEL_ID). Without it Firebase posts to its
     * own "Miscellaneous" channel. Created on every start: that is a no-op
     * for an existing channel apart from renaming it, so the name follows
     * the language Android gives the app (res/values-ar). Importance and
     * sound stay the user's to change once it exists.
     */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            NOTIFICATION_CHANNEL_ID,
            getString(R.string.notification_channel_name),
            NotificationManager.IMPORTANCE_DEFAULT,
        )
        getSystemService(NotificationManager::class.java)?.createNotificationChannel(channel)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ATTACHMENT_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "open") {
                    result.success(
                        openAttachment(call.argument<String>("path"), call.argument<String>("type"))
                    )
                } else {
                    result.notImplemented()
                }
            }
    }

    /**
     * Opens a downloaded attachment in whichever app views its type (a PDF
     * reader, Docs, Slides), as iOS previews it from the share sheet.
     * Only files under cache/attachments, which lib/core/attachment_opener.dart
     * writes and xml/attachment_paths.xml exposes. False when nothing on the
     * phone can open it, and the app offers the share sheet instead.
     */
    private fun openAttachment(path: String?, type: String?): Boolean {
        if (path == null) return false
        val root = File(cacheDir, "attachments").canonicalFile
        val file = File(path).canonicalFile
        if (!file.isFile || !file.path.startsWith(root.path + File.separator)) return false
        val uri = try {
            FileProvider.getUriForFile(this, "$packageName.attachments", file)
        } catch (e: IllegalArgumentException) {
            return false
        }
        val view = Intent(Intent.ACTION_VIEW)
            .setDataAndType(uri, type?.takeIf { it.isNotBlank() } ?: "application/octet-stream")
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        // Not a chooser: Android's own "Open with" appears when several apps
        // can, and this throws when none can.
        return try {
            startActivity(view)
            true
        } catch (e: ActivityNotFoundException) {
            false
        }
    }
}

private const val ATTACHMENT_CHANNEL = "com.studafy.light/attachments"

private const val NOTIFICATION_CHANNEL_ID = "studafy_notifications"

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
