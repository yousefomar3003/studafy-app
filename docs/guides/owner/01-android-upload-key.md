# 01 · Android upload key

Launch plan **C1** (work plan 3.3). Time: 20 minutes.

Google Play needs every app bundle to be signed. You make an **upload
key**. You sign uploads with it. Google then re-signs the app with its own
**app signing key** (Play App Signing). If you lose the upload key, Google
can reset it, but that takes days. If you also lost Play App Signing, you
could never update the app again. So: keep the key safe, and keep Play App
Signing on.

## Before you start

- Your Mac, with `keytool`. Check in Terminal:

  ```sh
  keytool -help >/dev/null 2>&1 && echo ok
  ```

  If it does not print `ok`, use the copy inside Android Studio:
  `"/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool"`.
- The private folder `~/studafy-secrets` from the [README](README.md).
- Apple Passwords, and a USB stick for the backup.

## Steps

1. **Make a password.** In Terminal:

   ```sh
   openssl rand -base64 24 | tr -d '/+='
   ```

   Copy the result. Save it in Apple Passwords as
   "Studafy Android upload key".

2. **Save the password in a file**, for the build. Copy the password from
   Apple Passwords, then run:

   ```sh
   pbpaste > ~/studafy-secrets/studafy-upload-password.txt
   chmod 600 ~/studafy-secrets/studafy-upload-password.txt
   ```

3. **Make the key.** Run this. Change only the company name.

   ```sh
   keytool -genkeypair -v \
     -keystore ~/studafy-secrets/studafy-upload.jks \
     -storetype PKCS12 \
     -alias upload \
     -keyalg RSA -keysize 2048 -validity 10000 \
     -dname "CN=Studafy, O=YOUR COMPANY LEGAL NAME, C=IE"
   ```

   - It asks for the keystore password twice. Paste the password from
     step 1.
   - If it asks for a separate key password, press Enter. (With PKCS12 the
     key password is the same as the keystore password.)
   - `C=IE` is the country of the company (Ireland). Change it if the
     company is elsewhere.

4. **Check the key.**

   ```sh
   chmod 600 ~/studafy-secrets/studafy-upload.jks
   keytool -list -v -keystore ~/studafy-secrets/studafy-upload.jks -alias upload
   ```

   Enter the password. You should see `Alias name: upload` and two lines
   starting `SHA1:` and `SHA256:`. These fingerprints are **not** secret.
   Keep them; Claude compares them later.

5. **Back up.** Copy `~/studafy-secrets/studafy-upload.jks` to the USB
   stick. Keep the stick somewhere safe, away from the Mac. The password
   stays in Apple Passwords (not on the stick next to the file).

6. **Tell Claude** (paths only):

   > C1 done. Keystore `~/studafy-secrets/studafy-upload.jks`, alias
   > `upload`, password file `~/studafy-secrets/studafy-upload-password.txt`.

7. **Play App Signing** is switched on at the first upload, in
   [guide 09, part B](09-play-console-listing.md#part-b-first-internal-testing-release-c4).
   When Play asks about the app signing key, keep the default
   **"Use a Google-generated key"**.

## What Claude does

- Points the release build at your key file and password file. Both stay
  outside the project. Nothing is committed. (The Gradle wiring is in a
  separate PR; today `android/app/build.gradle.kts` still signs release
  builds with the debug key and blocks them.)
- Builds the release bundle (`.aab`) for internal testing.

## How Claude checks it

- `keytool -printcert -jarfile app-release.aab` shows `CN=Studafy` and the
  same SHA-256 as your step 4. It must **not** say `CN=Android Debug`.
- After your first upload, Play Console shows an "Upload key certificate".
  Its SHA-1 must match your step 4.

## Common mistakes

- **Saving the key inside the project folder.** `.gitignore` ignores `*.jks`,
  but keep it in `~/studafy-secrets` anyway.
- **No backup.** If the Mac dies, the key is gone. Make the USB copy today.
- **Pasting the password in chat.** Give the file path instead.
- **Choosing "Export and upload a key" in Play.** Not needed. Keep the
  Google-generated app signing key.
- **Lost upload key later?** Play Console → "App integrity" → "Request
  upload key reset". You make a new key and Google accepts it after a few
  days. This works only because Play App Signing is on.
