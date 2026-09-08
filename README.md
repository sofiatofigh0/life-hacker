# Aurelia Wellness

Aurelia is a private, offline-first iPhone fitness and wellness tracker built with SwiftUI, SwiftData,
HealthKit, Swift Charts, PhotosUI, AVFoundation, and local notifications. Its restrained cream, charcoal,
and sage interface is designed as a calm daily command center — not a gamified gym dashboard.

## Status — read this first

| Layer | State | Verified how |
|---|---|---|
| `WellnessCore` business logic | Working | `swift test` — 10/10 pass |
| SwiftUI app sources | Parse clean, Swift 5 mode | `swiftc -parse` on every file |
| Xcode project, scheme, asset catalog | Present and internally consistent | reference-integrity check |
| Full type check against the iOS SDK | **Not yet done** | needs a Mac |
| Running on a simulator or device | **Not yet done** | needs a Mac |

The original MVP commit was written without ever being compiled and contained 18 syntax and type errors.
Those are fixed. What has **not** happened is a real build: type checking against the actual iOS SDK, and a
launch on hardware. Expect to work through some residual diagnostics the first time you press ⌘R, and treat
the feature list below as "implemented in source", not "exercised on a phone".

## What is implemented

- Three-step onboarding with editable evidence-informed calorie/protein suggestions, units, activity, and goals.
- Today checklist and centralized completion score for workouts, calorie consistency (90–110%), protein,
  steps, water, and supplements. Active calories never increase the food target.
- Recurring workout templates with weekday assignment, exercise search/reordering, defaults, immutable
  session copies, editable sets, extra sets/exercises, cardio details, and completion history.
- Meal-grouped food history, cached recent/frequent foods, gram-based macro math, manual foods, USDA proxy
  search, Open Food Facts barcode lookup, and camera scanner.
- Historical calendar/day editing, manual weight and seven-day trend chart, private three-angle photos,
  arbitrary two-date comparison, HealthKit service, and notification service.
- A separate portfolio toggle with seeded history. **MVP limitation:** demo records are tagged by their
  predictable fixtures rather than stored in a second SwiftData file; do not use Reset Demo Data after
  intentionally creating personal records with demo-like values. A separate persistent container is the
  first recommended hardening task.

## Requirements

- **A Mac.** This is a native SwiftUI/SwiftData/HealthKit app. There is no way to install it on an iPhone
  from Windows, Linux, or an iPad — you need macOS with Xcode 16 or newer, or a rented cloud Mac.
- iPhone running iOS 17 or newer for HealthKit and real barcode testing.
- A free Apple developer account is enough for personal installation; a paid membership is not required.
- Optional: a Supabase project and USDA FoodData Central API key for remote food-name search. Manual and
  cached foods and Open Food Facts barcode lookup work without any key.

## Getting it onto your iPhone

1. `open Aurelia.xcodeproj`
2. Select the blue **Aurelia** project → the **Aurelia** app target → **Signing & Capabilities**.
3. Choose your Apple Development **Team**.
4. Change `com.example.Aurelia` to a unique bundle identifier such as `com.yourname.Aurelia`.
5. Confirm **HealthKit** appears under Signing & Capabilities. If Xcode shows it in red, remove it and
   re-add via **+ Capability → HealthKit**; `Aurelia/Aurelia.entitlements` already declares it.
6. Pick an iPhone 15/16 simulator and press **⌘R** for a first smoke test. The camera and HealthKit are
   limited there — use manual foods and sample logs.
7. For the phone: connect it (or enable wireless debugging), unlock it, select it as the run destination,
   press **⌘R**, then on the phone go to **Settings → General → VPN & Device Management** and trust your
   developer certificate.
8. HealthKit: Aurelia Settings → **Connect / refresh Apple Health**, accept the categories, return to Today.
   Health data stays on the device. A simulator will not reproduce Apple Watch workout history reliably.
9. Demo Mode: Settings → **Demo Mode**. Disable it to return to personal presentation. Use
   **Reset Demo Data** only for portfolio fixtures.

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

Deleting the app deletes its local database and private photos. This MVP does not offer backup/sync; export
and encrypted device backup are recommended post-MVP work.

## Tests

Platform-independent business logic is a Swift package that builds anywhere, including Linux:

```bash
swift test
```

Covers conversions, goals, no-eat-back behavior, food-by-weight macro math, completion scoring, template
history snapshots, meal totals, trends, overrides, mocks, and isolation semantics.

On macOS, the app/unit build:

```bash
xcodebuild -project Aurelia.xcodeproj -scheme Aurelia -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build test
```

The `Aurelia` scheme is shared and committed, so this works without opening Xcode first.

## Known limitations / recommended next work

1. Get a real build on a Mac and resolve any remaining SDK-level type errors.
2. Move demo fixtures into a physically separate SwiftData container and add a data-source router.
3. Add background HealthKit observer queries and robust workout de-duplication; the service currently
   implements authorization and daily normalized activity reads, with user-initiated refresh.
4. Add a saved-meal composer UI (the persistent model and total calculation are present) and
   authenticated/rate-limited nutrition requests.
5. Add licensed exercise demonstration media, photo export/deletion controls, and VoiceOver UI tests.
6. Add richer notification preference editors and conditional protein scheduling via a background refresh
   strategy permitted by iOS.
7. Reconsider `SWIFT_VERSION`. The project targets Swift 5 language mode; moving to Swift 6 will surface
   strict-concurrency diagnostics across the SwiftUI, SwiftData, and HealthKit layers.
