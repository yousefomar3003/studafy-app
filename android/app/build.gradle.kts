import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Push notifications need this project's Firebase config. Until
// google-services.json is added the app builds without it, and push stays
// off (it is also gated by the PUSH_ENABLED dart-define).
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

// SEC-001 containment, narrowed for Android internal testing (ADR-0042,
// launch plan 3.5). A release build is allowed only for the test copy: every
// APP_ENV the Flutter tool passes in its dart-defines must be "development".
// Production, staging, synthetic, a missing APP_ENV (the app reads that as
// synthetic) and a Gradle release task run without Flutter's dart-defines are
// all refused. iOS release stays blocked in the Xcode project, and a
// production app still refuses to start (lib/core/runtime_environment.dart).
// Remove only in the REL-002 cutover (launch plan 7.3).
val sec001ReleaseAppEnv = "development"

// Flutter passes --dart-define and --dart-define-from-file values to Gradle
// as -Pdart-defines: base64("KEY=VALUE") entries joined by commas.
fun dartDefineValues(name: String): List<String> {
    val encoded = project.findProperty("dart-defines")?.toString() ?: return emptyList()
    return encoded.split(",").filter { it.isNotBlank() }.mapNotNull { entry ->
        val define = String(Base64.getDecoder().decode(entry.trim()), Charsets.UTF_8)
        val separator = define.indexOf('=')
        if (separator > 0 && define.substring(0, separator) == name) {
            define.substring(separator + 1)
        } else {
            null
        }
    }
}

// Release signing (launch plan 3.3). The upload keystore and its passwords
// never live in the repository. They are read from a key.properties file named
// by STUDAFY_ANDROID_KEY_PROPERTIES (preferred, kept outside the repository)
// or, failing that, android/key.properties (ignored by git). The file holds
// storeFile, storePassword, keyAlias and keyPassword; a relative storeFile is
// resolved from the file's own folder, and the keystore itself must be
// outside the repository.
//
// With no key configured a release build fails rather than falling back to
// the debug key: Play refuses debug-signed bundles, so a silent fallback
// would only produce an artifact that looks shippable and is not.
// STUDAFY_ALLOW_DEBUG_SIGNED_RELEASE=true signs with the debug key instead,
// for a local check that the release build works; never upload that bundle.
class UploadKey(
    val storeFile: File,
    val storePassword: String,
    val keyAlias: String,
    val keyPassword: String,
)

val repositoryRoot: File = rootProject.projectDir.parentFile.canonicalFile
var uploadKey: UploadKey? = null
var uploadKeyProblem: String? = null
run {
    val fromEnvironment =
        System.getenv("STUDAFY_ANDROID_KEY_PROPERTIES")?.takeIf { it.isNotBlank() }
    val propertiesFile = fromEnvironment?.let { File(it) }
        ?: rootProject.file("key.properties").takeIf { it.exists() }
        ?: return@run
    if (!propertiesFile.isFile) {
        uploadKeyProblem = "the key properties file ${propertiesFile.path} does not exist"
        return@run
    }
    val properties = Properties()
    propertiesFile.inputStream().use { properties.load(it) }
    val missing = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
        .filter { properties.getProperty(it).isNullOrBlank() }
    if (missing.isNotEmpty()) {
        uploadKeyProblem = "${propertiesFile.path} is missing ${missing.joinToString(", ")}"
        return@run
    }
    val storePath = File(properties.getProperty("storeFile"))
    val keystore = (
        if (storePath.isAbsolute) storePath
        else File(propertiesFile.absoluteFile.parentFile, storePath.path)
    ).canonicalFile
    if (!keystore.isFile) {
        uploadKeyProblem =
            "the keystore ${keystore.path} named in ${propertiesFile.path} does not exist"
        return@run
    }
    if (keystore.path.startsWith(repositoryRoot.path + File.separator)) {
        uploadKeyProblem =
            "the keystore ${keystore.path} is inside the repository; keep it outside"
        return@run
    }
    uploadKey = UploadKey(
        storeFile = keystore,
        storePassword = properties.getProperty("storePassword"),
        keyAlias = properties.getProperty("keyAlias"),
        keyPassword = properties.getProperty("keyPassword"),
    )
}
val allowDebugSignedRelease = System.getenv("STUDAFY_ALLOW_DEBUG_SIGNED_RELEASE") == "true"

gradle.taskGraph.whenReady {
    if (allTasks.none { it.name.contains("release", ignoreCase = true) }) {
        return@whenReady
    }
    val appEnvs = dartDefineValues("APP_ENV")
    if (appEnvs.isEmpty() || appEnvs.any { it != sec001ReleaseAppEnv }) {
        val given = if (appEnvs.isEmpty()) "none" else appEnvs.joinToString(", ")
        throw GradleException(
            "SEC-001: Android release builds are blocked except internal-testing builds " +
                "of the test copy (APP_ENV=$sec001ReleaseAppEnv); APP_ENV given: $given. " +
                "Production stays blocked until REL-002."
        )
    }
    uploadKeyProblem?.let { problem ->
        throw GradleException("Release signing: $problem.")
    }
    if (uploadKey == null) {
        if (!allowDebugSignedRelease) {
            throw GradleException(
                "Release signing: no upload key. Set STUDAFY_ANDROID_KEY_PROPERTIES to a " +
                    "key.properties file outside the repository (storeFile, storePassword, " +
                    "keyAlias, keyPassword). For a local check only, " +
                    "STUDAFY_ALLOW_DEBUG_SIGNED_RELEASE=true signs with the debug key; " +
                    "Play refuses that bundle."
            )
        }
        // Error level, because the Flutter tool runs Gradle quietly and would
        // hide a warning.
        logger.error(
            "WARNING: release build signed with the DEBUG key " +
                "(STUDAFY_ALLOW_DEBUG_SIGNED_RELEASE=true). Do not upload it."
        )
    }
}

android {
    namespace = "com.studafy.light"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.studafy.light"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        uploadKey?.let { key ->
            create("upload") {
                storeFile = key.storeFile
                storePassword = key.storePassword
                keyAlias = key.keyAlias
                keyPassword = key.keyPassword
            }
        }
    }

    buildTypes {
        release {
            // The upload key when one is configured; the debug key only on the
            // explicit local opt-in. Otherwise none, and the guard above stops
            // the build before an unsigned bundle is made.
            signingConfig = when {
                uploadKey != null -> signingConfigs.getByName("upload")
                allowDebugSignedRelease -> signingConfigs.getByName("debug")
                else -> null
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
