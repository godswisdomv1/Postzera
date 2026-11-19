# Outstanding work

Updated 2026-11-19. Read with `docs/HANDOFF.md` (method, workflows, state) and `docs/decisions.md` (pivots, D01 onward). The blueprint has 22 batches (0 to 21). Batches 0 to 18 are done and green. Three remain, one of them mostly done early.

## Batch 19: in progress (F187 to F199)
Translations and widget tests, then Checkpoint 2.

Translations (F187 to F196): ten ARB files of 250 strings each, translated by hand with a fixed glossary per language and checked by a script for keys, placeholders and plural forms.
- Written and passing the checker, NOT yet pushed (they exist only in the working sandbox): es, fr, de, pt.
- Still to write: ar, hi, ja, ko, zh, he.
- Plural categories required: ar zero/one/two/few/many/other; he one/two/other; es, fr, de, pt, hi one/other; ja, ko, zh other only.

After the translations:
- Regenerate and commit the localization files (scaffold workflow, task `finalize`).
- Permanent test: every language file has every key with the same placeholders.
- Locale sweep test: key screens in all 11 languages at 2.0x text, checking overflow, and right-to-left layout in Arabic and Hebrew.
- iPhone: add `CFBundleLocalizations` to `Info.plist` (without it iPhones report only English).
- Widget tests F197 and F198: compare the existing tests (`test/widgets/*`) with the blueprint list and add only what is missing. F199 (boot test) was written in Batch 18.
- Checkpoint 2 (user on the phone): every screen in both themes, the consent cases per region, purchase and restore, reminders.

## Batch 20: website (F200 to F208), mostly done
Live at https://postzera.godswisdomv1.workers.dev (/, /support, /privacy, /terms).
- Open: the user's website revisit.
- Open: the logo choice (see below), then regenerate favicon, app icon and share image.
- Open: link the Google Play and App Store badges once the store listings exist.

## Batch 21: store documents and README (F209 to F215), not started
- `ASO_METADATA.md`: titles, descriptions, keywords per store and language.
- `DATA_BACKING.md`: evidence behind every store declaration. Must match the privacy page on facts.
- `SCREENSHOT_STRATEGY.md`.
- `IAP_SETUP.md`: the $41.99 purchase, AdMob units, consent messages.
- `CONSENT_TEST_PLAN.md`.
- `RELEASE_RUNBOOK.md`.
- Final `README.md`.
- Then the release run: production ad ids, a registered test device, no forced consent region.

## Outside the batches
User testing
- Checkpoint 1 phone results (media lab numbers, gallery APK run 42139201636).
- Feedback on the real-app APK (run 44206572388, install `app-arm64-v8a-release.apk`).

Decisions and inputs from the user
- Logo / app icon: not chosen. The teardrop is only a draft. Eight candidates were shown (Seed, Fan, Stack, P, Branch, Z, Echo, Stamp); recommendation was Stamp, runner-up Fan. The choice changes the launcher icon, splash, notification icon and website images.
- Store listing URLs (for the badges).
- Apple team ID (`ios/ExportOptions.plist`).
- AdMob production app ids and banner unit ids (build settings `ADMOB_ANDROID_BANNER`, `ADMOB_IOS_BANNER`).
- Codemagic app and App Store Connect API key.
- Whether generated media ever carries a Postzera mark (decide after seeing samples).
- Review of the privacy page and terms text, and of the ten first-pass translations by native speakers before each listing goes live.

Technical
- Android: move compile SDK and the Android Gradle plugin to 37 and drop the `androidx.lifecycle` 2.10.0 pin before the release run.
- Known gap: the blueprint's "delete generated media 7 days after a post is marked sent" is not implemented (the file store takes one age; the shell sweeps at 14 days on every launch). Needs a decision.
- Evaluate hugeicons 4.4.0 (currently 1.2.0).
- Confirm on a device that the Hugeicons licence appears on the licenses screen.
- Videos are stored with a rotate-by-90 flag; decide whether to store them upright.
- First real-phone proof still missing for: video overlay layers with exact canvas size, reminder delivery, the consent form, real purchases, the iPhone back swipe, the long-press toolbar on a phone.

## Decided (do not reopen)
- Ads while Pro status is unknown: do not hold ads, blueprint as written (D59).
- Contact email is printed only on the support page; Settings has Contact support (opens the support page) and Report a problem (emails the last 20 log lines).
