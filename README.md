# Aurelia Wellness

Aurelia is a private, offline-first iPhone fitness and wellness tracker built with SwiftUI, SwiftData, HealthKit, Swift Charts, PhotosUI, AVFoundation, and local notifications. Its restrained cream, charcoal, and sage interface is designed as a calm daily command center—not a gamified gym dashboard.

## What works

- Three-step onboarding with editable evidence-informed calorie/protein suggestions, units, activity, and goals.
- Today checklist and centralized completion score for workouts, calorie consistency (90–110%), protein, steps, water, and supplements. Active calories never increase the food target.
- Recurring workout templates with weekday assignment, exercise search/reordering, defaults, immutable session copies, editable sets, extra sets/exercises, cardio details, and completion history.
- Meal-grouped food history, cached recent/frequent foods, gram-based macro math, manual foods, USDA proxy search, Open Food Facts barcode lookup, and camera scanner.
- Historical calendar/day editing, manual weight and seven-day trend chart, private three-angle photos, arbitrary two-date comparison, HealthKit service, and notification service.
- A separate portfolio toggle with believable seeded history. **MVP limitation:** demo records are tagged by their predictable fixtures rather than stored in a second SwiftData file; do not use Reset Demo Data after intentionally creating personal records with demo-like values. A separate persistent container is the first recommended hardening task.

## Requirements

- macOS with Xcode 16 or newer.
- iPhone running iOS 17 or newer for HealthKit and real barcode testing.
- Free Apple developer account for your device; paid membership is not required for basic personal installation.
- Optional Supabase project and USDA FoodData Central API key for remote food-name search. Manual/cached foods and Open Food Facts barcode lookup do not require a USDA key.

## First local verification

Open Terminal in this repository and run:

```bash
open Aurelia.xcodeproj
```

Then choose an iPhone 15+ simulator and press **⌘R**. On Linux, only the platform-independent suite can run: `swift test`.

## Xcode setup (exact steps)

1. Double-click `Aurelia.xcodeproj` (or use the command above).
2. Select the blue **Aurelia** project, then the **Aurelia** app target.
3. In **Signing & Capabilities**, choose your Apple Development **Team**.
4. Change `com.example.Aurelia` to a unique bundle identifier such as `com.yourname.Aurelia`.
5. Confirm **HealthKit** is present under Signing & Capabilities. If Xcode shows it in red, remove it and use **+ Capability → HealthKit**. The repository already includes `Aurelia.entitlements`.
6. In **Info**, confirm the camera and HealthKit privacy strings. They are already supplied by `Aurelia/Info.plist`.
7. Notifications require no Xcode capability for local alerts; iOS asks permission when you enable the weekly reminder in Settings.
8. Select a simulator and press **⌘R**. Camera and HealthKit are limited there; use manual foods and sample logs.
9. For an iPhone, connect it (or enable wireless debugging), unlock it, select it in the scheme destination, press **⌘R**, trust the developer profile if prompted, and complete onboarding.
10. HealthKit: open Aurelia Settings → **Connect / refresh Apple Health**, accept the requested categories, then return to Today. Health data is device-only. A simulator will not reproduce Apple Watch workout history reliably.
11. Demo Mode: Settings → **Demo Mode**. Disable it to return to personal presentation. Use **Reset Demo Data** only for portfolio fixtures.

## Supabase + USDA setup

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
   The function is intentionally public because it accepts only food search text, holds no user data, and lets a single-user app work without authentication. Before a public launch, add rate limiting and authenticated requests.
6. Copy `Config/Secrets.xcconfig.example` to `Config/Secrets.xcconfig` and replace the URL:
   ```text
   NUTRITION_PROXY_URL = https://YOUR_PROJECT_REF.supabase.co/functions/v1/nutrition-proxy
   SUPABASE_ANON_KEY = YOUR_PUBLISHABLE_ANON_KEY
   ```
7. In Xcode select the project → **Info** → Configurations and attach `Config/Secrets.xcconfig` to the Aurelia Debug and Release configurations, or add `NUTRITION_PROXY_URL` directly under the target's **Build Settings → User-Defined** settings. The current app does not need the anon key because the function is deployed with `--no-verify-jwt`.

## Privacy and offline behavior

SwiftData stores personal logs locally. Progress images are copied to the app's private Documents directory. Health information and photos never enter nutrition requests. Workouts, manual/cached food, water, supplements, weight, calendar, and photos remain useful offline. New USDA searches and uncached barcodes need connectivity.

Deleting the app deletes its local database and private photos. This MVP does not offer backup/sync; export and encrypted device backup are recommended post-MVP work.

## Tests

Platform-independent business logic is a Swift package:

```bash
swift test
```

On macOS, run the app/unit build with:

```bash
xcodebuild -project Aurelia.xcodeproj -scheme Aurelia -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build test
```

Tests cover conversions, goals, no-eat-back behavior, food-by-weight macro math, completion, template history snapshots, meal totals, trends, overrides, mocks, and isolation semantics.

## Known MVP limitations / recommended next work

1. Move demo fixtures into a physically separate SwiftData container and add a data-source router.
2. Add background HealthKit observer queries and robust workout de-duplication; the service currently implements authorization and daily normalized activity reads, while refresh is user initiated.
3. Add a saved-meal composer UI (the persistent model and total calculation are present) and authenticated/rate-limited nutrition requests.
4. Add licensed exercise demonstration media, an app icon asset catalog, photo export/deletion controls, and VoiceOver UI tests.
5. Add richer notification preference editors and conditional protein scheduling via a background refresh strategy permitted by iOS.

No credentials are committed. `.env`, local xcconfig secrets, build output, and Xcode user data are ignored.
