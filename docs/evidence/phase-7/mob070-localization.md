# MOB-070 — Arabic as a switchable language

Date: 2026-09-20. Decision: ADR-0028, DL-055.

Covers the bilingual half of MOB-070's acceptance criteria. Accessibility
(screen readers, font scale) and the remaining offline/device work stay open.

## What a user can now do

| Behaviour | Before | Now |
|---|---|---|
| Switch to Arabic | Picker existed, choice lost on every restart | Persists at device scope, survives sign-out |
| Open the app on an Arabic phone | Always English | Opens in Arabic; "System default" is reachable again in the picker |
| Read the language picker in Arabic | Its own chrome was hardcoded English | Translated |
| Receive Arabic email and push | Profile locale never written, so always English | Written on change, retried next launch if it fails |
| Sign in on a new phone | Language not carried | Profile seeds it, unless this device already has its own choice |
| See the interface laid out RTL | Ambient only; padding and chevrons did not mirror | 10 `fromLTRB` and 4 one-way chevrons converted, guarded by a source test |

## Verification performed

All local. Commands run from the repository root.

| Check | Result |
|---|---|
| `flutter analyze --no-pub` | No issues |
| `flutter test --no-pub --concurrency=1` | 220 pass, 0 fail (was 150 before this change) |
| `dart run tools/check_dart_bounds.dart` | 83 feature files, 0 violations |
| `bun run check:bounds` | 128 source files, 0 violations |
| `dart format --set-exit-if-changed lib test tools` | 204 files, 0 changed |
| `flutter gen-l10n` then `git diff --exit-code lib/l10n/` | No drift; wired into CI |
| `flutter build apk --debug --dart-define=APP_ENV=synthetic` | Builds, including the new Android locale resource |
| `lib/l10n/untranslated.json` | `{}` — every English key has Arabic |

### Tests added

| File | Proves |
|---|---|
| `mob070_locale_controller_test.dart` | Resolution order, persistence across restart, system-language change, publish/retry, profile seeding never overriding the device |
| `mob070_language_switch_test.dart` | The real picker end to end, including the RTL flip and the picker being Arabic once Arabic is chosen |
| `mob070_localization_parity_test.dart` | Key parity both ways, no Arabic value left as its English original, and both platforms declaring every shipped locale |
| `mob070_formatting_test.dart` | Western digits under `ar`, Arabic month and weekday names, and user content keeping its own direction in either interface |
| `mob070_arabic_screens_test.dart` | Translated screens render Arabic, lay out RTL, and leave no English behind — with the English mirror case |
| `mob070_rtl_source_test.dart` | Source ratchet: no direction-pinning padding, alignment or chevron on any reachable screen; no copy lookup keyed on a runtime value |

`test/support/localized_app.dart` replaces the `MaterialApp` scaffold that six
test files had each hand-copied.

## Platform declarations

Flutter's `supportedLocales` is not what the operating systems read.

- `ios/Runner/Info.plist` — `CFBundleLocalizations` now lists `en` and `ar`.
  Without it iOS reports the app as English-only and device detection cannot
  work, whatever Dart says.
- `android/app/src/main/res/xml/locales_config.xml` — new, referenced from the
  manifest, so Android 13+ offers the per-app language picker.

`mob070_localization_parity_test.dart` fails if either drifts from the `.arb`
files.

## Open — not covered by anything above

Do not read the green run as covering these. Each needs a physical device.

1. **Arabic font shaping and fallback.** `flutter test` renders with a test
   font, so no test here proves Arabic *renders* — only that the right strings
   and directions are chosen.
2. **Clipping.** Arabic runs taller and ~20-25% longer than English. Fixed
   heights (the synthetic banner's `SizedBox(height: 30)`, chip labels, list
   densities) may clip on a real screen.
3. **VoiceOver and TalkBack in Arabic**, including reading order in an RTL
   tree. Required for MOB-070 sign-off.
4. **Font scale at 200% in Arabic.**
5. **Real device-locale configurations** — `ar-SA`, `ar-EG`, `ar` with an
   English region, and the iOS per-app language override.
6. **Arabic email and push delivery.** The copy selection is tested; delivery
   needs Firebase and a verified sending domain, which do not exist (DL-053).

## Copy review status

**The Arabic in this change has not been reviewed by a native speaker.** It is
fit for development and review, not for launch. School vocabulary —
assignment, attendance, guardian, term — has conventional Arabic that a
grammatically correct translation can still get wrong for schools.

The placeholder privacy and terms bodies in `login_page.dart` additionally
carry legal text counsel has not reviewed in either language. REL-002 §21.6
replaces both with hosted documents; the Arabic there exists so the screen is
readable, not because it is approved.

## Deliberately still English

`lib/legacy/teacher`, `lib/legacy/student` and the synthetic-path
`lib/features/parent/presentation` screens — about 180 strings. Reachable only
when `RuntimePolicy.requiresRemoteBackend` is false, always shown under the
`SYNTHETIC DATA — NOT FOR REAL SCHOOL USE` banner, and scheduled for removal
by MOB-070 itself. Recorded as a bounded decision in DL-055 with that removal
as the trigger, so it cannot quietly become permanent.
