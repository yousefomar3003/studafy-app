# 02 · Google sign-in and the release fingerprints

Launch plan **C2** (work plan 3.4). Time: 15 minutes. Do it after the
first upload to Play ([guide 09, part B](09-play-console-listing.md)).

## Read this first: what the code really needs

The plan says "add the release SHA-1 to the Android OAuth client". **The
current code does not need this for sign-in.**

- The app signs in with Google **through Supabase, in the browser**
  (`lib/features/session/data/api_session_repository.dart`,
  `signInWithOAuth`). Google sends the person back to Supabase, and
  Supabase sends them to the app at `io.studafy.app://login-callback`.
- The app has no native Google sign-in package, so Google never checks the
  Android app's SHA-1.

What Google sign-in in the release build **does** need:

1. The Supabase **Google provider** with a **Web application** client. This
   already works on the test copy. For production it is in
   [guide 06](06-production-supabase.md#part-d-google-sign-in).
2. `io.studafy.app://login-callback` in Supabase's "Redirect URLs".
3. The Google sign-in screen ("OAuth consent screen") set to
   **"In production"**. In "Testing", only listed test users can sign in.

The release **SHA-256** is needed later, for Android App Links: the file
`https://app.studafy.com/.well-known/assetlinks.json`
(`docs/release/auth030-site-association.md`; package `com.studafy.light`).
The legal-site Worker serves that file with a placeholder until you have
the fingerprint.

So in this guide you: (A) copy the fingerprints, (B) check the consent
screen. Part C is optional.

## Before you start

- The first build is uploaded to internal testing (guide 09, part B).
- Access to the Google Cloud project that holds the test copy's Google
  sign-in client. It is the client whose redirect URI is
  `https://cyrngoqnhqflzovlybbr.supabase.co/auth/v1/callback`.

## Part A: copy the fingerprints

1. Open [play.google.com/console](https://play.google.com/console) →
   **Studafy**.
2. Left menu: **"Test and release"** → **"App integrity"**. (Older layout:
   "Setup" → "App integrity".)
3. Open the **"App signing"** tab.
4. Under **"App signing key certificate"**, copy the **SHA-1** and the
   **SHA-256**.
5. Under **"Upload key certificate"**, check the SHA-1 matches the one from
   [guide 01](01-android-upload-key.md) step 4.
6. Save them in a note. They are **public**: you can paste them in chat.

## Part B: check the Google consent screen

1. Open [console.cloud.google.com](https://console.cloud.google.com). At the
   top, choose the project with the Supabase sign-in client.
2. Menu → **"Google Auth Platform"** → **"Audience"**. (Older layout:
   "APIs & Services" → "OAuth consent screen".)
3. "User type" must be **"External"**.
4. "Publishing status" must be **"In production"**. If it says "Testing",
   click **"Publish app"** and confirm.
5. Menu → **"Clients"**. Open the Web client. Under "Authorized redirect
   URIs" you should see
   `https://cyrngoqnhqflzovlybbr.supabase.co/auth/v1/callback`. Do not
   change it.

## Part C (optional): Android OAuth client with the SHA-1

Only if Claude asks for it (for example, if native Google sign-in is added
later).

1. Google Cloud → **"Google Auth Platform"** → **"Clients"** →
   **"Create client"**.
2. Application type: **"Android"**.
3. Name: `Studafy Android release`.
4. Package name: `com.studafy.light`.
5. SHA-1 certificate fingerprint: the **App signing key** SHA-1 from part A
   (not the upload key).
6. **"Create"**. Tell Claude the client ID (it is not secret).

## Give Claude

> C2 done. App signing SHA-1 `…`, SHA-256 `…`. Upload key SHA-1 `…`.
> Consent screen is In production.

## How Claude checks it

- Installs the internal-testing build from Play on a phone and signs in
  with Google as a teacher, a student and a parent. The browser must
  return to the app.
- Later, when the domain is ready (C8), publishes `assetlinks.json` with
  the SHA-256 and runs
  `adb shell pm get-app-links com.studafy.light`: the domain must show
  `verified`.

## Common mistakes

- **Using the upload key fingerprint** for App Links or the Android client.
  Phones see the **app signing** key, because Google re-signs the app.
- **Consent screen left in "Testing".** Sign-in then fails for everyone
  not on the test-user list.
- **School Google accounts blocked.** Google Workspace for Education can
  block apps for users under 18 until the school's admin allows them
  ("Admin console" → "Security" → "API controls" → "App access control").
  If a student's school account cannot sign in but a personal Gmail can,
  this is why. The school's admin must allow Studafy.
