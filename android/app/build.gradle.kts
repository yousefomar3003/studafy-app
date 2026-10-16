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

// Release builds (REL-002 cutover, ADR-0044; formerly the SEC-001 block,
// narrowed by ADR-0042). A release task runs only when every APP_ENV the
// Flutter tool passes in its dart-defines is the same allowed value:
// - "production", the store build, and then only when the dart-defines match
//   the production contract (lib/core/production_contract.dart, run through
//   tools/check_release_defines.dart): the production API, Supabase project
//   and legal pages, a publishable key, Turnstile on, no unknown defines, a
//   build number above 1. It must be signed with the upload key; the
//   debug-key opt-in below is refused for it;
// - "development", the test copy for internal testing (ADR-0042).
// Staging, synthetic, a missing APP_ENV (the app reads that as synthetic), a
// mix of values, and a Gradle release task run without Flutter's
// dart-defines are all refused. The app also refuses to start in production
// without the contract (lib/core/runtime_environment.dart).
val releaseAppEnvs = setOf("production", "development")

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

// Runs the production defines contract on exactly the dart-defines Flutter
// passed to this build. The contract lives in Dart, shared with the Xcode
// check and the app, so it runs on the Flutter SDK's Dart. Anything but a
// clean pass, including Dart failing to start, stops the build.
fun checkProductionDefines(repositoryRoot: File) {
    val localProperties = Properties()
    rootProject.file("local.properties").takeIf { it.isFile }?.inputStream()?.use {
        localProperties.load(it)
    }
    val flutterSdk = localProperties.getProperty("flutter.sdk")
        ?: throw GradleException("REL-002: flutter.sdk is not set in local.properties.")
    val windows = System.getProperty("os.name").lowercase().contains("windows")
    val dart = File(flutterSdk, if (windows) "bin/dart.bat" else "bin/dart").path
    val output: String
    val exitCode: Int
    try {
        val process = ProcessBuilder(
            dart,
            "tools/check_release_defines.dart",
            "--platform", "android",
            "--encoded", project.findProperty("dart-defines")?.toString() ?: "",
        ).directory(repositoryRoot).redirectErrorStream(true).start()
        output = process.inputStream.bufferedReader().readText()
        exitCode = process.waitFor()
    } catch (error: java.io.IOException) {
        throw GradleException("REL-002: the production defines check could not run: ${error.message}")
    }
    if (exitCode != 0) {
        throw GradleException(
            "REL-002: production defines check failed.\n" +
                output.trim().replace("error: ", "")
        )
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
// for a local check that a development release build works; never upload
// that bundle. A production build refuses it.
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
    if (appEnvs.isEmpty() || appEnvs.distinct().size != 1 || appEnvs[0] !in releaseAppEnvs) {
        val given = if (appEnvs.isEmpty()) "none" else appEnvs.joinToString(", ")
        throw GradleException(
            "REL-002: Android release builds must be APP_ENV=production (store) or " +
                "APP_ENV=development (internal testing of the test copy); APP_ENV given: $given."
        )
    }
    if (appEnvs[0] == "production") {
        if (allowDebugSignedRelease) {
            throw GradleException(
                "Release signing: STUDAFY_ALLOW_DEBUG_SIGNED_RELEASE is for the development " +
                    "test copy only; a production build is signed with the upload key."
            )
        }
        checkProductionDefines(repositoryRoot)
    }
    uploadKeyProblem?.let { problem ->
        throw GradleException("Release signing: $problem.")
    }
    if (uploadKey == null) {
        if (!allowDebugSignedRelease) {
            throw GradleException(
                "Release signing: no upload key. Set STUDAFY_ANDROID_KEY_PROPERTIES to a " +
                    "key.properties file outside the repository (storeFile, storePassword, " +
                    "keyAlias, keyPassword). For a local check of a development build only, " +
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
        // Store builds take the version code from --build-number
        // (scripts/release/build-store.sh; in CI .github/scripts/build-number.sh);
        // a production build with the pubspec.yaml baseline (1) is refused by
        // the defines check above. When using split APKs, 1000 * ABI_VERSION
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
