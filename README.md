# Aurelia Wellness

Aurelia is a private, offline-first iPhone fitness and wellness tracker built with SwiftUI, SwiftData,
HealthKit, Swift Charts, PhotosUI, AVFoundation, and local notifications. Its restrained cream, charcoal,
and sage interface is designed as a calm daily command center — not a gamified gym dashboard.

## Status — read this first

| Layer | State | Verified how |
|---|---|---|
| `WellnessCore` business logic, unit handling, export format, catalogs, insights | Working | `swift test` — 49/49 pass |
| SwiftUI app sources | Parse clean, Swift 5 mode | `swiftc -parse` on every file |
| Xcode project, scheme, asset catalog | Present and internally consistent | reference-integrity check |
| Simulator build | Succeeded once (before the audit rewrite) | Xcode 26 on a Mac |
| Audit rewrite type-checked on the iOS SDK | **Not yet** | next ⌘R on the Mac |

The app has been through a full-screen audit and a product-review pass (see
[`KNOWN_ISSUES.md`](KNOWN_ISSUES.md) for the register and [`PRODUCT_REVIEW.md`](PRODUCT_REVIEW.md) for the
walkthrough, the competitive comparison, and the fix list). Both rewrote most of the view layer; the code
parses cleanly but the next ⌘R is its first real type check. Expect a round of diagnostics, as with every
change so far. **This build migrates the data store from schema V1 to V2 on first launch.**

## What is implemented

- Three-step onboarding with editable evidence-informed calorie/protein suggestions, units, activity, and goals.
- Today checklist with a greeting, remaining-calorie framing, progress bars, a streak, and a centralized
  completion score for workouts, calorie consistency (90–110%), protein, steps, water, and supplements.
  Active calories never increase the food target. The screen rolls over at midnight.
- Recurring workout templates with weekday assignment, exercise search/reordering, default sets and rep
  range, and one-tap repeat of any past session.
- Strength sessions the way Strong and Hevy do them: last time's numbers as placeholders, tick a set to
  complete it (adopting those numbers), a rest timer pinned to the bottom that notifies you when the phone is
  locked, PR badges, warm-up and RPE per set, per-exercise notes, and a session summary (volume, sets,
  live elapsed time). Finishing records the duration and tidies untouched sets. Every exercise has a
  history chart and all-time best.
- Meal-grouped food history with remaining-calorie framing, tap-to-edit entries, quick add, saved meals,
  copy yesterday, add-and-log-another, cached recent/frequent foods, gram-based macro math, manual foods,
  USDA proxy search, Open Food Facts barcode lookup, and camera scanner.
- Historical calendar with a month summary, day editing, a week-vs-last-week card, manual weight and
  90-day trend chart with goal line, private three-angle photos with thumbnails, comparison, and deletion.
- Reminders: workout days (derived from the scheduled templates), an evening log check-in, and weekly photos.
- **Apple Health sync**: steps, active and resting energy, and average heart rate are imported for the
  last 14 days on launch, on return to the foreground, and on demand. Weights logged in the app are written
  to Health; weights recorded elsewhere (a scale) are imported for days with no manual entry.
- Full unit awareness: every field and display follows the profile's imperial/metric choice.
- **Demo mode** runs against a separate in-memory store with a generated five-week history. Your own
  records are never modified by it. Settings can also scan for — and remove — fixtures that an earlier
  build's demo mode wrote into the real database.
- Versioned SwiftData schema with a migration plan, a store that never self-deletes on failure, and
  JSON **export and restore** of every record from Settings.
- A ~170-exercise library (grouped by muscle group and equipment, with form cues) and ~130 built-in food
  staples, both kept as code and merged into the store by name on launch — so they can grow in any update
  without touching your data. A Food Library screen lets you edit, favorite, and delete saved foods.

## Keeping your data across updates

Your logs live in one SwiftData database inside the app's container. They survive an update as long as:

1. **The bundle identifier does not change.** iOS keys the container to it. Changing it is a different app
   with an empty database (and the old one stays installed alongside).
2. **You install over the top** — ⌘R from Xcode, or a rebuild after the 7-day free-team expiry. Never
   delete the app to "reinstall cleanly"; that deletes the database and the photos.
3. **Model changes go through the migration plan** in `Aurelia/Persistence.swift`. Schema V1 is frozen
   there and V2 (set completion, warm-up, RPE, exercise notes) migrates from it automatically. Content that
   only needs to grow — the exercise and food catalogs — is code, not schema, precisely so updates don't
   migrate anything. If a store ever fails to open, the orange banner offers **Start fresh**, which erases
   it only after you confirm; the app never deletes data on its own.

Your safety net is Settings → **Export all data (JSON)**. Do it before any update that mentions a schema
change, and occasionally otherwise. **Restore from a backup** puts a file back (replace, not merge).

## Requirements

- **A Mac.** This is a native SwiftUI/SwiftData/HealthKit app. There is no way to install it on an iPhone
  from Windows, Linux, or an iPad — you need macOS with Xcode 16 or newer, or a rented cloud Mac.
- iPhone running iOS 17 or newer for HealthKit and real barcode testing.
- A free Apple developer account is enough for personal installation; a paid membership is not required.
- Optional: a Supabase project and USDA FoodData Central API key for remote food-name search. Manual and
  cached foods and Open Food Facts barcode lookup work without any key.

## Getting it onto your iPhone

1. `open Aurelia.xcodeproj`
2. Copy `Config/Secrets.xcconfig.example` to `Config/Secrets.xcconfig` and set `DEVELOPMENT_TEAM` (your
   10-character Team ID from Xcode → Settings → Accounts) and a unique `PRODUCT_BUNDLE_IDENTIFIER` such as
   `com.yourname.Aurelia`. The file is git-ignored, so `git pull` never conflicts with your signing.
3. Select the blue **Aurelia** project → the **Aurelia** app target → **Signing & Capabilities** and confirm
   the Team shows as selected. (If you set it in the UI instead, Xcode writes it into `project.pbxproj` and
   the next pull will complain — see step 2.)
4. Apple rejects `com.example.*`, so step 2's bundle identifier is required for a device build.
5. Confirm **HealthKit** appears under Signing & Capabilities. If Xcode shows it in red, remove it and
   re-add via **+ Capability → HealthKit**; `Aurelia/Aurelia.entitlements` already declares it.
6. Pick an iPhone 15/16 simulator and press **⌘R** for a first smoke test. The camera and HealthKit are
   limited there — use manual foods and sample logs.
7. For the phone: connect it (or enable wireless debugging), unlock it, select it as the run destination,
   press **⌘R**, then on the phone go to **Settings → General → VPN & Device Management** and trust your
   developer certificate.
8. HealthKit: Aurelia Settings → **Connect / refresh Apple Health**, accept the categories, return to Today.
   Health data stays on the device. A simulator will not reproduce Apple Watch workout history reliably.
9. Demo mode: Settings → **Portfolio → Demo mode**. It switches the whole app to a throwaway store;
   turning it off returns to your data untouched. **Regenerate demo data** rebuilds the sample history.
10. If you turned on demo mode in a build before September 2026, run Settings → **Your data →
    Check for old demo data** once. It finds the fixtures that build wrote into your real records and
    removes them on confirmation.

### Free Apple ID caveats

- Apps signed with a free personal team **expire after 7 days**. Re-run from Xcode to renew; the icon goes
  dead otherwise.
- A free account is limited to 3 apps installed per device and 10 new app IDs per 7 days.
- If Xcode refuses to create a provisioning profile, the HealthKit entitlement is the first thing to check.

## Supabase + USDA setup (optional)

The Edge Function is the only component that sees the USDA secret. No HealthKit data or photos are sent to it.

1. Install the [Supabase CLI](https://supabase.com/docs/guides/local-development/cli/getting-started).
2. Authenticate and connect this directory:
   ```bash
   supabase login
   supabase link --project-ref YOUR_PROJECT_REF
   ```
3. Obtain a USDA FoodData Central API key at `fdc.nal.usda.gov/api-key-signup.html`.
4. Store it remotely (never in the app):
   ```bash
   supabase secrets set USDA_API_KEY=YOUR_REAL_KEY
   ```
5. Deploy the proxy:
   ```bash
   supabase functions deploy nutrition-proxy --no-verify-jwt
   ```
   The function is intentionally public because it accepts only food search text, holds no user data, and
   lets a single-user app work without authentication. Before a public launch, add rate limiting and
   authenticated requests.
6. Copy the example config and fill in your project ref:
   ```bash
   cp Config/Secrets.xcconfig.example Config/Secrets.xcconfig
   ```
   `Config/Base.xcconfig` is already attached to both build configurations and pulls `Secrets.xcconfig` in
   with `#include?`, so no Xcode wiring is needed. The file is git-ignored, and the build still succeeds
   when it is absent — food *search* simply reports itself unavailable while manual foods, cached foods,
   and barcode lookup keep working.

## Privacy and offline behavior

SwiftData stores personal logs locally. Progress images are copied to the app's private Documents directory.
Health information and photos never enter nutrition requests. Workouts, manual/cached food, water,
supplements, weight, calendar, and photos remain useful offline. New USDA searches and uncached barcodes
need connectivity.

Deleting the app deletes its local database and private photos. There is no cloud sync. Use Settings →
**Export all data (JSON)** for a backup you control, and an encrypted iPhone backup for the photos.

## Tests

Platform-independent business logic is a Swift package that builds anywhere, including Linux:

```bash
swift test
```

Covers conversions, goals, no-eat-back behavior, food-by-weight macro math, completion scoring, template
history snapshots, meal totals, trends, overrides, mocks, unit-aware display, meal inference, the JSON
export format, the legacy demo-fixture matching, the exercise and food catalogs, and the insight helpers
(streaks, week windows, daily score index, pace, volume, greeting).

On macOS, the app/unit build:

```bash
xcodebuild -project Aurelia.xcodeproj -scheme Aurelia -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build test
```

The `Aurelia` scheme is shared and committed, so this works without opening Xcode first.

## Known limitations / next work

See [`KNOWN_ISSUES.md`](KNOWN_ISSUES.md) — it lists what each pass fixed, what is deliberately deferred,
and why — and [`PRODUCT_REVIEW.md`](PRODUCT_REVIEW.md) for the comparison against MyFitnessPal, Strong,
Hevy, MacroFactor and others. The short version of what is still missing: a dark-mode palette, an
accessibility pass with VoiceOver, Apple Watch workout import, supersets, adaptive calorie targets,
background Health delivery, and the Swift 6 migration.
