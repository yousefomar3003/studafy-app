# 09 · Google Play Console: app, internal testing and listing

Launch plan **C4** (work plan 3.7, parts A and B) and **B12** (work plan
3.6, parts C to F). Time: parts A and B 30 minutes; parts C to F 1 to 2
hours.

## Before you start

- The Play Console developer account, verified.
- For part B: the upload key ([guide 01](01-android-upload-key.md)) and the
  `.aab` file Claude builds (Claude gives you its path).
- For parts C to F: the Data safety answers in
  [`docs/store/google-play-data-safety.md`](../../store/google-play-data-safety.md),
  and the listing text and screenshots Claude prepares (A4).

## Exact values

| What | Value |
|---|---|
| App name | `Studafy` |
| Package name | `com.studafy.light` (set by the first upload; permanent) |
| Default language | English (United States), `en-US` |
| App or game | App |
| Free or paid | **Free** (subscriptions are inside the app) |
| Category | Education |
| Contact email | `hello@studafy.com` |
| Privacy policy | `https://legal.studafy.com/privacy` |
| Delete account page | `https://legal.studafy.com/delete-account` |

The two links change when the legal pages move to the domain (C8).

## Part A: create the app

1. [play.google.com/console](https://play.google.com/console) → **"Create
   app"**.
2. Fill the values from the table.
3. Tick the declarations ("Developer Program Policies", "US export laws").
4. **"Create app"**.

## Part B: first internal testing release (C4)

1. Left menu: **"Test and release"** → **"Testing"** → **"Internal
   testing"**.
2. **"Testers"** tab → **"Create email list"** → name `Studafy internal` →
   add the testers' Gmail addresses → **"Save"**. Tick the list.
3. **"Releases"** tab → **"Create new release"**.
4. The first time, Play asks about **app signing**. Keep **"Use a
   Google-generated key"** (Play App Signing). Do not export or upload your
   own app signing key.
5. "App bundles": **"Upload"** → the `.aab` from Claude.
6. "Release name": keep the default. "Release notes": `First internal test.`
7. **"Next"** → **"Save"** → **"Start rollout to Internal testing"** (or
   "Send changes for review", then publish).
8. **"Testers"** tab → **"Copy link"**. Open it on the phone, **signed in
   to Play with a tester's Gmail** → **"Accept invite"** → install from
   Play.
9. Now do [guide 02](02-google-signin-sha1.md) (the fingerprints).

If Play refuses to roll out, the **"Dashboard"** lists what is missing. Do
those items from part C first.

**Closed test rule:** if the Dashboard shows a task like "Run a closed test
with at least 12 testers for 14 days", the account is treated as personal.
Organisation accounts normally do not have this rule. If you see it, plan
the 14 days now.

## Part C: App content

Left menu: **"Policy and programs"** → **"App content"**. Do each card.

1. **"Privacy policy"**: the link from the table.
2. **"App access"**: **"All or some functionality is restricted"**. Add
   instructions and demo sign-ins for the reviewer. **Gap:** the app has
   only Google, Microsoft and Apple sign-in, and there are no reviewer
   accounts that work with them yet. Ask Claude to prepare reviewer
   accounts (one per role) before you fill this.
3. **"Ads"**: **"No, my app does not contain ads"**.
4. **"Content rating"**: start the questionnaire. Email
   `hello@studafy.com`. Category: the educational/reference one. Answer
   honestly: users **can** interact and exchange content (messages,
   homework files); the app **has** digital purchases; it does not share
   location.
5. **"Target audience and content"** (decision DL-056): tick the age groups
   that cover **students aged 5 to 17, and adults (18+)**. Deciding whether
   "5 and under" is needed (for age 5) is yours. Say the app **does**
   appeal to children. The **Families policy** then applies. Optional:
   "Teacher Approved".
6. **"Data safety"**: copy the answers from
   `docs/store/google-play-data-safety.md`, section by section. The "Delete
   account URL" is in the table above.
7. **"Advertising ID"**: **No** (the app uses no advertising ID). If Play
   says the build has the `AD_ID` permission, tell Claude.
8. **"Government apps"**: No. **"Financial features"**: "My app doesn't
   provide any financial features". **"Health"**: No (see decision 6 in the
   Data safety doc). **"News apps"**: No.

## Part D: store settings

**"Grow users"** → **"Store presence"** → **"Store settings"** (older:
"Store presence" → "Store settings"):

- App category: **Education**;
- Email: `hello@studafy.com`; website: `https://studafy.com`.

## Part E: main store listing

**"Store presence"** → **"Main store listing"**:

| Field | Limit |
|---|---|
| App name | `Studafy` (30 characters) |
| Short description | 80 characters |
| Full description | 4000 characters |
| App icon | 512 × 512 PNG |
| Feature graphic | 1024 × 500 PNG or JPG |
| Phone screenshots | 2 to 8; for example 1080 × 1920 |
| Tablet screenshots | Optional |

Claude gives you the text and screenshots (A4). Then **"Manage
translations"** → **"Add your own translation text"** → **Arabic** → paste
the Arabic text.

## Part F: countries (at launch)

**"Test and release"** → **"Production"** → **"Countries / regions"** → add
Jordan and the others you choose. Do this only when you are ready for
production.

## Give Claude

> C4 done: build installed from Play by `…` testers. B12 (Play): App content
> done, Dashboard shows nothing missing / shows: `…`.

## How Claude checks it

- The tester installs from Play, signs in, and completes the 2.9 flows.
- The Play **"Dashboard"** and **"Publishing overview"** show no missing
  items.
- The Data safety answers match `google-play-data-safety.md` and the App
  Store labels (`docs/store/app-store-privacy-labels.md`).

## Common mistakes

- **"Paid" instead of "Free".** A free app with subscriptions is "Free".
  Paid can never become free.
- **Uploading with the debug key.** Play refuses it. Claude builds with
  your upload key.
- **The tester is signed in to Play with another Google account.** The
  invite link then says the app is not available.
- **Data safety "No data collected".** The app collects data. Saying no is
  an automatic rejection.
- **Answers that differ** between Data safety, the App Store labels and the
  privacy policy. Keep them the same; change all three together.
