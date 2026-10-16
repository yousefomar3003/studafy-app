# 10 · App Store Connect: TestFlight and the listing

Launch plan **C16** (work plan 5.7, part A) and **B12** (work plan 5.5,
parts B to D). Time: part A 30 minutes; parts B to D 1 to 2 hours.

## Before you start

- The app record exists ([guide 07, part C](07-apple.md)).
- For part A: the `.ipa` file Claude builds (Claude gives you its path).
- For parts B to D: the privacy answers in
  [`docs/store/app-store-privacy-labels.md`](../../store/app-store-privacy-labels.md),
  and the listing text and screenshots Claude prepares (A4).

## Exact values

| What | Value |
|---|---|
| Category | **Education** (not the Kids category; DL-056) |
| Privacy policy URL | `https://legal.studafy.com/privacy` |
| Support URL | `https://studafy.com` (or a support page) |
| Contact | `hello@studafy.com` |
| Devices | iPhone and iPad (the app supports both, so iPad screenshots are needed) |

## Part A: TestFlight (C16)

1. Install **Transporter** from the Mac App Store. Sign in with your Apple
   Developer account.
2. Drag the `.ipa` from Claude into Transporter → **"Deliver"**.
3. Wait 10 to 30 minutes. App Store Connect → Studafy → **"TestFlight"**.
   The build appears, first as "Processing".
4. If it says **"Missing Compliance"** → **"Manage"** → the app uses only
   standard encryption (HTTPS) → choose **"None of the algorithms mentioned
   above"** → **"Save"**. (The app's `Info.plist` does not answer this yet,
   so Apple asks for each build.)
5. **"Internal Testing"** → **"+"** → group name `Studafy team` → add
   testers. Internal testers must be users in your App Store Connect team.
6. Add the build to the group.
7. The tester installs **TestFlight** from the App Store, opens the invite,
   and installs Studafy.

External testers (people outside your team) need Apple's beta review.
Start with internal testers.

### Give Claude (C16)

> C16 done. Build `…` installed from TestFlight by `…`.

## Part B: App Privacy

1. Studafy → **"App Privacy"** → **"Privacy Policy URL"**: the link from
   the table.
2. **"Get Started"** / **"Edit"** under "Data Types". Answer exactly as in
   `docs/store/app-store-privacy-labels.md`, step by step.
3. **"Publish"** the answers.

## Part C: App Information

1. **"App Information"**:
   - Category: **Education**. Secondary: optional;
   - **"Age Rating"** → **"Edit"**: answer the questions honestly. Users
     can message each other and share files. Do **not** choose "Made for
     Kids" (DL-056);
   - "Content Rights": answer honestly (teachers and students upload their
     own files);
   - Add **Arabic** as a localization (the "+" next to the language at the
     top right) and fill the name and subtitle in Arabic.
2. **"Pricing and Availability"**: price **Free**; choose the countries.

## Part D: the version page

Studafy → **"iOS App"** → the version (for example 1.0):

| Field | Note |
|---|---|
| Screenshots | iPhone 6.9" (for example 1320 × 2868) and iPad 13"; Claude makes them |
| Promotional text, description, keywords | Claude's text (A4), English and Arabic |
| Support URL, marketing URL | From the table |
| Build | Choose the TestFlight build |
| In-App Purchases and Subscriptions | Add the four subscriptions ([guide 08](08-app-store-products.md)); the first ones must go with a version |
| App Review Information | Contact details, and demo sign-ins |

**Gap:** the reviewer needs to sign in. The app has only Google, Microsoft
and Apple sign-in, and there are no reviewer accounts for them yet. Ask
Claude to prepare reviewer accounts (one per role) before you fill "App
Review Information".

Do not press **"Submit for Review"** until launch day (D1 to D2).

## Give Claude (B12, App Store)

> B12 (App Store): privacy answers published, App Information and version
> page filled, missing: `…`.

## How Claude checks it

- The tester installs from TestFlight and completes the 2.9 flows,
  including Sign in with Apple and a push with the app closed.
- The App Privacy answers match `app-store-privacy-labels.md`,
  `ios/Runner/PrivacyInfo.xcprivacy`, the Play Data safety answers and the
  privacy policy.

## Common mistakes

- **Uploading the same build number twice.** Apple refuses it. Ask Claude
  for a new build.
- **Testers not in your team** added to "Internal Testing". Invite them in
  "Users and Access" first, or use external testing.
- **"Made for Kids" ticked.** Not chosen (DL-056). It adds rules the app
  does not meet.
- **No iPad screenshots.** The app runs on iPad, so Apple requires them.
- **Submitting without the subscriptions attached.** Apple then reviews
  the app without them, and they wait for the next version.
