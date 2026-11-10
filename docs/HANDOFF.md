# Postzera handoff (read with docs/decisions.md and docs/blueprint.md)

Repo: https://github.com/godswisdomv1/Postzera (public, branch `main`). App id `com.zdmgold.postzera`. Support email stmakarios@gmail.com.
Secrets (token, keystore passwords) are NOT in the repo. The user supplies the GitHub token; export it as `GH_TOKEN`.
Test phone: Redmi A5 (arm64). User works on a phone only. No security lectures. Ask, never leave placeholders. Report per batch, say which files to check on the web repo.

## Working method
- Write files in the sandbox, `bash app/tool/check_layers.sh`, commit, push to `main`. `check` runs on push. Read results: `GH_TOKEN=... bash app/tool/ci_wait.sh` (waits and prints) and `app/tool/ci_ann.sh RUN_ID`.
- Flutter cannot run in the sandbox. Analyzer + tests run only in CI. A warning fails CI.
- Bot commits (`ci: finalize`) do not trigger `check`; dispatch it.
- Dispatch workflows: `POST /repos/godswisdomv1/Postzera/actions/workflows/<file>/dispatches {"ref":"main","inputs":{...}}`.
- Workflows: `check` (push), `build_and_deploy` (target, ad_mode, consent_geo, test_device_id), `scaffold` (task: scaffold|finalize|brand|upgrade), `inspect` (package API), `smoke_android` (run_id), `device_test` (api_level). APK artifacts: `postzera-android-apk` (use `app-arm64-v8a-release.apk`).
- Build polls need chunks under 300 s per command.

## Done (CI green)
| Batch | Content |
| --- | --- |
| 0-1 | repo, scaffold, config, utils, l10n base |
| 2-3 | native config, brand assets, CI, icons, splash |
| 4-5 | design tokens, fonts, errors, models, built-in data |
| 6 | 15 ports |
| 7-8 | pure services and tests (template engine, planner, pipeline, reminders, CSV, consent, entitlement) |
| 9-11 | SQLite and file adapters, card renderer, video composer, share, notifications, ads, consent, purchases, CSV picker |
| 12 | 14 providers + settings_sync |
| 13 | foundation widgets (pressable, icons, card, row, chip, buttons, nav bar, empty/error views...) |
| 14 | text field + toolbar, switch, segmented, sheet, dialog, banner host, date-time sheet, page route, back swipe, localized_text |
| 15 | ad slot, badge, swatch, progress bar, variant card/strip, gallery + media lab (`lib/dev/`) |
| 16 | screens I: queue, composer, variants, send, library + `ScreenServices`, routes, `PzScreen`, 80 strings, 24 screen tests |

Tests: ~370 unit/widget tests, gallery smoke sweep (light, dark, 1.0x, 2.0x), emulator `device_test`.

## Checkpoint 1 (waiting for the user's phone retest)
- Latest phone APK: Actions run 42139201636 (`postzera-android-apk`, install `app-arm64-v8a-release.apk`, uninstall the old one first). Entry point is the gallery, not the app.
- Phone (Redmi A5), earlier build: fonts, components, dark theme, sheets, dialogs, date wheels, exact sizes OK; clip reframe verified frame by frame (hook 0-4 s, CTA last 3 s, 9:16 cover crop, audio kept, 20.7 s for a 23 s clip); 5-slide video 16.6 s at 30 fps.
- Fixed since: long-press toolbar (verified on emulator runtime), mid-word breaks at 2.0x, system-bar colors, lab cache false results, lab photo gradient, slide video 24 fps / 4 Mbps.
- Emulator `device_test` (run 42139198646, x86 software, debug, slower than a phone): x 62 ms, instagram 99 ms, pinterest 70 ms (target 150); photo card 522 ms (target 400); 3 slides 10.2 s; 5 slides 18.3 s (target 15 s). Sizes all exact.
- Ask the user for phone numbers from the new APK: auto cards, photo card, 3 and 5 slides, both clips, light-theme status bar, long press chips.
- If 5-slide stays over 15 s on the phone: drop slide fps to 15 or resolution on slow devices (blueprint section 16 fallback), or cap slides.
- Generated slide videos and clips carry a rotate flag of 90 (stored landscape, shown upright). Decide whether to force upright files.

## Remaining batches (file ids from blueprint 19E/19F)
| Batch | Files |
| --- | --- |
| 17 screens II | F174 platforms, F175 template editor, F176 import, F177 settings, F178 paywall, F179 onboarding, F180 licenses |
| 18 shell | F181 app_services, F182 bootstrap, F183 app_routes, F184 app, F185 main, F186 license_registration |
| 19 | F187-F196 ten ARB translations (es fr de pt ar hi ja ko zh he), F197-F199 widget/boot tests. Then Checkpoint 2 (every screen, consent matrix, purchase test) |
| 20 website | F200-F208 (index, privacy, support, style, robots, sitemap, 3 images). User connects Cloudflare |
| 21 | F209-F215 store docs + final README. Then release run (ad_mode prod) |
Rules: screens have no string literals in `Text` (use l10n); screens never import `platform/`; widgets never import `platform/`.

## Carry-forward (must not be forgotten)
- `bootstrap.dart` must call `initializeDateFormatting()` (date wheels, formats) and use `PzSystemUi` in `app.dart`.
- `PzTheme` must sit above the Navigator (overlays read it). `PzBannerHost` offsets by top inset + 56.
- Add Hugeicons licence to the licenses screen (MIT).
- Production ad ids via build defines (D26). Release workflow must set them.
- Move to compileSdk 37 / newer AGP and drop the lifecycle pin (D12). Release logs warn about built-in Kotlin and unobfuscated ELF debug info.
- Smoke-test every release build on the emulator (`smoke_android`).

## Open decisions / inputs from the user
- Hold ads until Pro state is known, or blueprint as written (unanswered; currently as written).
- Apple team ID; AdMob app and banner ids; Codemagic key; domain and Cloudflare URLs; Postzera mark on media (user picks from samples).
- `hugeicons` 4.4.0 evaluation.
