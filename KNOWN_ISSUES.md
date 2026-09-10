# Known issues and deferred work

This is the register from the full-app audit. Everything here was found by reading every screen and
tracing every data flow; the items marked **fixed** shipped in the audit commit, and the rest are
deliberately deferred with the reason. Severity is about impact on a person using the app daily.

Status of verification: every Swift file parses cleanly in Swift 5 mode and the pure-logic layer passes
49 tests on Linux. Changes have **not** been type-checked against the iOS SDK or run on a device — that
happens on the Mac. Expect a round of compiler diagnostics on the first ⌘R, as with every previous change.

The product-review pass (see [`PRODUCT_REVIEW.md`](PRODUCT_REVIEW.md)) is the most recent set of changes
and includes the first real schema migration (V1 → V2).

---

## Added in the product-review pass

| # | Item |
|---|---|
| R1 | **Schema V2.** `SetEntity` gains `completed`, `isWarmup`, `rpe`; `SessionExerciseEntity` gains `notes`; explicit inverse relationships; `AppProfile.demoMode` dropped. V1 is frozen in `Persistence.swift` and a lightweight stage migrates on first launch. Closes X14. |
| R2 | Strength sessions: set completion, rest timer with notification, previous-performance placeholders, PR badge, warm-up/RPE, per-exercise notes, session summary, finish that records duration and prunes empty sets, repeat any workout, exercise history chart. |
| R3 | Food: edit a logged entry (closes X8), quick add, add-and-log-another, copy yesterday, saved meals (closes X7). |
| R4 | Today: greeting, remaining framing, streak, progress bars, midnight rollover (closes X16). |
| R5 | Progress: week-vs-last-week card; photo set management with file deletion (closes X9). |
| R6 | Settings: workout-day and evening reminders, rest-timer defaults, supplement reorder (closes X12), version footer. Store-failure banner gains "Start fresh". |
| R7 | `DailyScoreIndex` in WellnessCore buckets logs by day once; Today and the calendar score days from it (closes X15 for the two screens that mattered). |

## Added after the audit

| # | Item |
|---|---|
| A1 | Exercise library grown from 13 to ~170 entries across 12 muscle groups and 8 equipment types, with form cues. Kept as code (`ExerciseCatalog`) and upserted by name on launch — no schema change, custom exercises untouched. Picker groups by muscle group with an equipment filter. |
| A2 | Built-in food staples (~130 whole foods and common items, per 100 g with typical servings) seeded insert-only, so "chicken" or "rice" works offline. Browse by category from Add Food. |
| A3 | Food Library screen: browse, search (name, brand, barcode), favorite, edit, delete every saved food. Scanned products accumulate here and the scanner checks it before going online. |
| A4 | Barcode lookup falls back to USDA branded foods via the nutrition proxy (`/barcode`) when Open Food Facts has no nutrition data. Optional; needs the proxy configured. |
| A5 | **Restore from backup** (Settings → Your data). Replace-only, with a count-and-date confirmation. Custom exercises are now included in exports. |

## Fixed in the audit

### Data sync (the "not syncing" report)

| # | Severity | Issue | Fix |
|---|---|---|---|
| S1 | **Critical** | `HealthKitService.snapshot(for:)` existed but was never called. Steps and active calories were always 0 outside demo mode; the completion ring could never pass 85% for a real user. | New `HealthSync` coordinator imports the last 14 days on launch, on return to foreground, on tapping the Steps card, and from Settings. One `ActivityEntity` per day, updated in place. |
| S2 | High | Weight was never written to Apple Health despite requesting share permission. | `WeightEntryView` writes a body-mass sample after saving (best effort, never blocks). |
| S3 | High | Weight from Health (a scale, another app) was never read. | Sync imports the latest body-mass sample per day as source "Apple Health", only for days with no manual entry. Samples the app wrote itself are excluded so they are not read back as a scale reading. |
| S4 | Medium | Heart rate authorization was requested but never read. | Daily average heart rate now stored on `ActivityEntity` and shown on the day view. |
| S5 | Medium | Several mutations relied on SwiftData autosave with no explicit save (set/exercise edits, template create/delete, supplement edits, food-log delete). | Explicit `save()` at every mutation. |

### Demo mode

| # | Severity | Issue | Fix |
|---|---|---|---|
| D1 | **Critical** | Demo fixtures were written into the *real* database. Toggling demo off left all 36 days of fake weights, workouts, foods, water, and activity mixed into personal history permanently. Toggling on twice doubled them. | Demo mode now runs against a separate in-memory container. Turning it off simply switches back; personal data is never touched. The setting lives in UserDefaults, not on the profile. |
| D2 | **Critical** | "Reset Demo Data" deleted every `ActivityEntity` with ≥ 7000 steps — including real Health days. | Reset now rebuilds the throwaway demo container. |
| D3 | High | No way to recover a database contaminated by D1. | Settings → **Check for old demo data** scans for the exact fixture signatures the old seeder wrote (full-row match, never a single field), reports counts, and removes them only on confirmation. The matching is unit-tested. |
| D4 | Low | Demo data was one yogurt bowl a day and one exercise per workout. | Five weeks with templates, meal variety, cardio, supplements, and a plausible weight trend. Deterministic, so it looks the same every launch. |

### Units

The profile has always stored metric and had a units picker, but almost no screen honoured it.

| # | Severity | Issue | Fix |
|---|---|---|---|
| U1 | High | Onboarding asked an imperial user (the default) for height in cm and weight in kg, with the units picker *after* those fields. | Units are chosen first; every field is unit-aware; a Back button was added. |
| U2 | High | Strength sets labelled "kg" regardless of units. | Weight fields convert to and from the profile's unit. |
| U3 | High | Cardio distance/speed always km and km/h. | Unit-aware. |
| U4 | Medium | Day detail showed weight in kg and water in mL always. | Unit-aware. |
| U5 | Medium | Water quick-adds showed "+237 mL / +355 mL / +473 mL" to metric users. | Metric users get 250 / 350 / 500 mL; imperial 8 / 12 / 16 oz. |
| U6 | Medium | Weight chart in kg for imperial users. | Converted for display, axis labelled. |
| U7 | Medium | Activity level rendered as `veryActive`. | Proper labels and descriptions. |
| U8 | Low | Water target entered in litres during onboarding, never editable afterwards. | Unit-aware in onboarding and Settings. |

### Screens

| # | Severity | Screen | Issue | Fix |
|---|---|---|---|---|
| F1 | **Critical** | Food | Swipe-to-delete on food entries did nothing — `swipeActions` only works in a `List`, and the screen is a `ScrollView`. Logged foods could not be removed. | Explicit remove button per entry. |
| F2 | High | Add Food | Tapping a search result silently cached it and cleared the list; the user had to find it again under Recent. | Result → serving screen directly. Same for barcode hits and manually created foods. |
| F3 | Medium | Add Food | Every result tap inserted a duplicate `FoodEntity`. | Reuses existing by barcode, then by name + brand. |
| F4 | Medium | Add Food | Empty "Recent"/"Frequent" section headers; no hint when online search is unconfigured. | Sections hidden when empty; searching your saved foods works offline; clear guidance. |
| F5 | Medium | Add Food | Camera permission never handled — a denied camera was a black screen. | Requests access, explains denial, links to Settings. |
| F6 | Low | Serving | Amount always defaulted to 100 g; meal always defaulted to Breakfast. | Defaults to the food's serving size; meal inferred from time of day; carbs/fat shown. |
| F7 | Low | Food | No way to view another day from the Food tab. | Previous/next day arrows. |
| W1 | High | Strength | Add-exercise sheet had a search bar bound to a constant — typing did nothing. | Real search, plus "add as custom exercise" for anything not in the library. |
| W2 | Medium | Strength | After deleting a middle set, "Add Set" reused an existing order index. | Uses max + 1. Same for exercises. |
| W3 | Medium | Workout | No way to delete a workout, remove an exercise, or reopen a completed session. | All three added. |
| W4 | Medium | Today | Templates assigned to a weekday were never surfaced. | Today shows "Scheduled: X" on that weekday and starts it in one tap; Workout tab shows the same. |
| W5 | Medium | Today | Tapping Workout after completing one opened the add sheet again. | Opens the day's session. |
| W6 | Low | Cardio | Optional fields showed a literal "0" instead of a placeholder. | New `DecimalField` shows placeholders, accepts both decimal separators, and does not reformat while you type. |
| W7 | Low | Templates | "Done" saved but did not close the sheet; "Create" did not save. | Both fixed. |
| W8 | Low | Exercise detail | Placeholder text "Demo media ready for licensed asset" was user-facing. | Neutral illustration. |
| C1 | Medium | Calendar | Days from the previous/next month looked identical to the current month; today not highlighted; future days tappable. | Dimmed, highlighted, disabled respectively. Weekday header now respects the locale's first weekday. |
| C2 | Medium | Day detail | No way to add a workout for a past day; no delete for food entries. | Both added. |
| P1 | High | Progress | Weight chart's Y axis started at zero — a 70 kg trend was a flat line at the top. | `includesZero: false`, goal line, last 90 days, monotone interpolation. |
| P2 | Medium | Progress | Photo compare defaulted "Earlier" to the newest set. | Earlier = oldest, Later = newest. |
| P3 | Low | Progress | No thumbnails; "Latest set" was a date only. | Thumbnail strip; photo picker shows what you chose. |
| P4 | Low | Progress | Logging a weight twice on one day created two entries. | Updates the existing manual entry for that day. |
| G1 | High | Settings | Could not edit water target, height, goal weight, age, sex, activity, or name after onboarding. | All editable; calories/protein can be recalculated from them. |
| G2 | Medium | Settings | "Connect Apple Health" showed a static string that never reflected state. | Shows last sync time, errors, and a pointer to the Health app's sharing screen when steps stay at zero. |
| G3 | Low | Settings | Photo reminder button gave no feedback and could not be turned off. | Toggle reflecting the real scheduled state. |
| V1 | Medium | All tabs | Two titles per screen: the editorial header plus the system navigation title. | System bar hidden on tab roots (kept when a screen is pushed so Back still works). |
| V2 | Medium | All | Dark mode turned the cream/sage cards black. | The app declares light appearance; a real dark palette is deferred (see below). |
| V3 | Low | Today | Supplements card had no empty state; water could not be un-logged. | Empty-state text; undo-last-water button. |

---

## Deferred — with reasons

### Needs a device to design properly

| # | Item | Why deferred |
|---|---|---|
| X1 | **Dark mode palette.** | The app is light-only for now. Doing dark properly means a second palette designed and checked on a real screen, not guessed from Linux. |
| X2 | **Accessibility pass** (VoiceOver labels on the ring and calendar cells, Dynamic Type at the largest sizes, reduced motion). | Labels were added where obvious, but a real pass needs VoiceOver running. |
| X3 | **Layout at the largest text sizes.** The dense checklist rows will wrap awkwardly at accessibility sizes. | Same — needs a device. |

### Larger features

| # | Item | Why deferred |
|---|---|---|
| X4 | **Import Apple Health workouts** (Apple Watch sessions) and de-duplicate against manual logs. | Read authorization is already requested. The hard part is de-duplication rules (a Watch "Traditional Strength Training" vs. the app's logged session at the same time) and that deserves its own design. |
| X5 | **Background Health delivery** (`HKObserverQuery` + background delivery) so steps update without opening the app. | Requires the Background Modes capability and careful battery behaviour. Foreground sync on launch/return covers daily use. |
| ~~X7~~ | Saved meals UI. | **Done** in the product-review pass (R3). |
| ~~X8~~ | Edit a logged food's amount in place. | **Done** (R3): macros rescale from the ratio they were logged at. |
| ~~X9~~ | Delete a photo set. | **Done** (R5): Progress → Manage removes the row and the three files. Photo export is still open. |
| X10 | **Food amounts in ounces** for imperial users. | Nutrition data is per 100 g everywhere; a display-only oz conversion is straightforward but needs the serving UI reworked. |
| X19 | **Merge on restore.** Restore is replace-only. | Merge needs duplicate rules per record type; replace is predictable and covers the backup use case. |
| X11 | **Exercise demonstration media.** | Needs licensed assets. |
| X20 | **Supersets / circuits.** | Changes the session model (grouping) and the set-row layout; do it after the new session screen has been used for a few weeks. |
| X21 | **Adaptive calorie targets** from intake and weight trend (MacroFactor-style). | Needs 2–3 weeks of consistent logs to be meaningful and a careful explanation in the UI. |
| ~~X12~~ | Reorder supplements. | **Done** (R6). |

### Engineering

| # | Item | Why deferred |
|---|---|---|
| X13 | **Swift 6 language mode.** The project is on Swift 5 mode. | Moving to 6 surfaces strict-concurrency diagnostics across SwiftData/HealthKit/AVFoundation code. Worth doing once the app is stable on device, not while it is still getting its first builds. |
| ~~X14~~ | Schema V2. | **Done** (R1), once there was a feature that needed it. The banner's "Start fresh" is the escape hatch if the migration fails. |
| X15 | **`@Query` with predicates instead of filtering in memory.** Every screen fetches all rows and filters by date. | Today and the calendar now score from a per-day index built once per render (R7). Predicates are still worth doing for the day-detail and food screens if they slow down after a year of data. |
| ~~X16~~ | Today does not roll over at midnight. | **Done** (R4). |
| X17 | **Nutrition proxy hardening** (rate limiting, auth) before any public use. | The Supabase function is intentionally open for a single user. |
| X18 | **Unit tests for SwiftData-backed logic** (sync upserts, demo cleanup, export mapping) via an in-memory container in the `AureliaTests` target. | These need the iOS SDK; they belong on the Mac, run with ⌘U. |

---

## How to report the next round

Paste the red errors from ⌘5 (Issue Navigator) — text is better than screenshots. For behaviour issues, say which tab, what you did, what you expected, and whether demo mode was on.
