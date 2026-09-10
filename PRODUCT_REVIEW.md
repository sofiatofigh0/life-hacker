# Product review — walkthrough, competitive comparison, and the fix list

This is the record of a full product pass done by reading every screen and data flow as a UX designer,
product lead, engineer and QA would, then comparing the result against the best apps in each category.
Everything in the **easy** and **harder** lists below was implemented in the same pass; the last section
says what was deliberately left out and why.

Verification on Linux: every Swift file parses in Swift 5 mode, the logic package passes 49 tests, and the
Xcode project's references are consistent. The first ⌘R on the Mac is the first real type-check of the view
layer, as with every change so far.

---

## 1. The walkthrough

What a person sees, in order, and what was wrong with it. "Before" is the build that preceded this pass.

### First launch

1. **Onboarding** (3 pages: welcome → measurements → targets). Units are chosen first; every field follows.
   Fine. No changes.
2. **Today** opens on "Today · Tuesday, September 10". Before: the ring said "Daily completion" with a
   product-principle sentence under it and every card showed *consumed / target*. Nothing said hello,
   nothing said how much was left, nothing rewarded consistency.

### A day of use

| Moment | Before | Problem | Now |
|---|---|---|---|
| Open the app | Date as title | Cold; no sense of "you" | Greeting as the title ("Good morning, Sofia"), date as the eyebrow |
| Glance at food | "1,240 / 1,900 kcal" | Every leading tracker frames the number you act on: what is **left** | "660 left · 1,240 of 1,900", turns orange past 110% |
| Glance at protein | "85 / 110 g" | Same | "25 g to go · 85 of 110 g" → "Target met" |
| Steps, water, calories, protein | Text only | Progress needed reading, not seeing | Thin progress bar under each row |
| Supplements | List | No count | "2 / 3" in the header |
| Consistency | Nothing | No reason to come back tomorrow | Streak on the ring: days at ≥ 70%, tolerant of an in-progress today |
| Leave the app open past midnight | Yesterday's data under today's date | Rollover bug (was X16) | Rolls over on the calendar-day-changed notification and on return to foreground |

### Logging food

| Moment | Before | Problem | Now |
|---|---|---|---|
| Log a plate of four things | Search → serving → sheet closes → tap + → search… | Four round trips; the single most common complaint about trackers | **Add & log another** returns to the search with the sheet open |
| Ate the same breakfast as yesterday | Re-log every item | | **Copy yesterday** when the day is empty; **Save as meal…** on any meal card; saved meals log in one tap from Add Food |
| Restaurant meal, no label | Create a fake food | | **Quick add** calories/macros with an optional description |
| Wrong amount logged | Remove and re-add | (was X8) | Tap the entry → edit amount or move to another meal; macros rescale |
| Meal header | kcal only | Protein is the number this app cares about | kcal · protein |
| Day totals | Consumed only | | Remaining/over framing with bars, matching Today |

### Training

| Moment | Before | Problem | Now |
|---|---|---|---|
| Start a session | Type weight and reps into blank fields | Strong/Hevy show last time's numbers as ghost text; that is the whole point of a log | **Previous performance placeholders** per set, "Last: 60 × 10" in the header |
| Do a set | No way to mark it done | The app could not tell a planned set from a performed one | Checkbox per set. Ticking an untouched set adopts last time's numbers |
| Rest between sets | Look at the clock | Every serious lifting app has a rest timer | **Rest timer bar** pinned to the bottom: 1:00/1:30/2:00/3:00, +30 s, skip; local notification when the phone is locked; auto-starts on tick (Settings) |
| Beat a previous best | Nothing | Hevy/Strong celebrate PRs | **PR** tag when a completed set is heavier than any prior set of that exercise |
| Warm-ups, effort | No distinction | Warm-ups polluted volume and "best" | Tap the set number: warm-up toggle and RPE 6–10 |
| A note about this exercise | Session notes only | "Seat 4", "felt heavy" belong on the exercise | Notes field per exercise |
| Finish | Just a flag | Duration never recorded; empty sets kept | Records elapsed time, marks filled sets done, removes untouched empty sets, cancels the timer |
| Session at a glance | Nothing | | Volume · sets done / planned · live elapsed timer |
| Same workout as last time | Rebuild from a template | Hevy's "Repeat" is one tap | **Repeat** card on the Workout tab and in every session's long-press menu |
| How am I progressing on hip thrusts? | Form notes only | Strong's exercise page is a chart | Exercise page: best-set chart, last sessions, all-time best |
| Cardio | Duration, distance | No pace | Pace ("8:35 /mi") computed live; completing requires a duration |
| Templates | Rep range stored, never shown or editable | | Editable rep range; shown in the session header |
| Empty Workout tab | "No sessions yet" | Dead end | Explains the schedule and offers to set it up |

### Looking back

| Moment | Before | Problem | Now |
|---|---|---|---|
| Progress tab | Weight + photos | No sense of the week | **This week vs last week**: workouts, average calories, protein, steps, weight, with deltas |
| Calendar | 42 rings | Each ring filtered every table; no summary | Shared per-day score index; **month summary** (workouts, days ≥ 70%, average calories and steps) |
| Day detail | Food rows read-only | | Tap to edit any entry |
| Photos | Add and compare only | Could never delete a set (was X9) | **Manage** list with swipe-to-delete that removes the files too |

### Settings

| Moment | Before | Now |
|---|---|---|
| Reminders | Weekly photo only | Workout-day reminders (from the scheduled templates, at a chosen time) and an evening log check-in |
| Rest timer | — | Default rest length; auto-start on tick |
| Supplements | Delete only | Drag to reorder (was X12) |
| Which build is this? | No way to tell (a real problem during the pull-failure episode) | Version, build and data-schema footer |
| Store failed to open | Banner only | **Start fresh** (confirmed) erases the unreadable store |

---

## 2. Competitive comparison

Apps used as the reference for "what good looks like": MyFitnessPal, Lose It!, MacroFactor and Cronometer
(food); Strong, Hevy and Fitbod (lifting); Apple Fitness, Oura and WHOOP (daily consistency and weekly
reflection); Noom and Future (coaching tone); Structured (scheduling).

| Capability | Best-in-class pattern | Aurelia before | Aurelia now |
|---|---|---|---|
| Calorie framing | MFP / Lose It: *remaining* is the headline number | Consumed / target | Remaining, over-target colour, bars |
| Protein-first | MacroFactor: protein alongside calories everywhere | Today only | Today, Food totals, meal headers, week summary |
| Fast logging | MFP: recent, frequent, saved meals, quick add, copy meal, multi-add | Recent/frequent/favorites | + saved meals, quick add, copy yesterday, add-another |
| Barcode → food | MFP: scan resolves to a serving screen; falls back to manual with prefill | Same (previous pass) | Same |
| Offline food database | Cronometer: curated whole foods | ~130 staples (previous pass) | Same |
| Set logging | Strong / Hevy: ghost values, tick to complete, rest timer, PR badges, warm-up flag, RPE | Blank fields, no completion | All of it |
| Exercise history | Strong: per-exercise chart and records | Form notes only | Chart, recent sessions, all-time best |
| Repeat a workout | Hevy: one tap from history | Templates only | Repeat card + long-press |
| Session summary | Hevy: volume, sets, duration | None | Volume, sets, live timer, auto duration |
| Consistency | Apple Fitness rings / Oura: streaks with forgiveness | Score only | Streak at ≥ 70%, in-progress day does not break it |
| Weekly reflection | MacroFactor / WHOOP: week vs previous week | None | Week card on Progress |
| Nudges | Structured / Fitbod: reminders tied to the plan | Weekly photo only | Workout-day + evening check-in |
| Coaching tone | Noom: warm, specific, not shouty | Neutral | Greeting, "to go", "Target met"; no red on the ring |
| Data ownership | Cronometer: export | Export + restore (previous pass) | Same, plus a documented migration and erase path |
| Apple Watch workouts | Strong, Hevy: import Health workouts | No | **Deferred** (below) |
| Dark mode | All | Light only | **Deferred** (below) |
| Supersets / circuits | Hevy | No | **Deferred** (below) |
| Adaptive targets | MacroFactor: weekly recalculation from intake + weight trend | Manual recalc | **Deferred** (below) |

---

## 3. The fix list

### Easy — all done

| # | Screen | Fix |
|---|---|---|
| E1 | Today | Greeting title with the name; date as eyebrow |
| E2 | Today | Remaining/over framing for calories; "to go"/"Target met" for protein |
| E3 | Today | Orange tint past 110% of calories |
| E4 | Today | Progress bars under calories, protein, steps, water |
| E5 | Today | Streak on the completion ring |
| E6 | Today | Midnight rollover and refresh on foreground |
| E7 | Today | Supplements "n / m" |
| E8 | Today | Thousands separators on every count |
| E9 | Food | Meal header shows protein |
| E10 | Food | Day totals use remaining framing and bars |
| E11 | Workout | Session subtitle shows volume and duration |
| E12 | Workout | Empty state explains templates and links to the schedule |
| E13 | Workout | "Start" on the scheduled card opens the session |
| E14 | Cardio | Pace shown live; completion requires a duration |
| E15 | Templates | Rep range editable and shown in sessions |
| E16 | Calendar | Month summary card |
| E17 | Calendar | Accessibility label per day cell (date + percent) |
| E18 | Progress | Weight card offers "Log weight" when empty |
| E19 | Settings | Supplement drag-to-reorder |
| E20 | Settings | Version / build / schema footer |
| E21 | Settings | Haptic on "Recalculate" |
| E22 | All | Per-day score index shared by Today and Calendar (was 42 full-table scans per render) |

### Harder — all done

| # | Area | What was built | Schema |
|---|---|---|---|
| H1 | Training | Set completion checkbox; ticking adopts last time's numbers | `SetEntity.completed` |
| H2 | Training | Rest timer (bar, notification, +30 s, skip, default length, auto-start) | — |
| H3 | Training | Previous-performance placeholders and "Last: w × r" header | — |
| H4 | Training | PR badge | — |
| H5 | Training | Warm-up flag and RPE per set | `SetEntity.isWarmup`, `rpe` |
| H6 | Training | Per-exercise notes | `SessionExerciseEntity.notes` |
| H7 | Training | Finish: auto duration, mark filled sets, prune empty sets | — |
| H8 | Training | Session summary (volume, sets, live elapsed) | — |
| H9 | Training | Repeat last workout / repeat any workout | — |
| H10 | Training | Exercise history chart and records | — |
| H11 | Food | Edit a logged entry (amount, meal, delete) | — |
| H12 | Food | Quick add | — |
| H13 | Food | Add & log another | — |
| H14 | Food | Copy yesterday | — |
| H15 | Food | Saved meals: save a meal card, log in one tap, delete | (entity existed) |
| H16 | Progress | Week vs last week summary | — |
| H17 | Progress | Photo set management with file deletion | — |
| H18 | Calendar | Tap-to-edit food entries in day detail | — |
| H19 | Settings | Workout-day reminders derived from templates; evening check-in | — |
| H20 | Persistence | **Schema V2** with a real V1→V2 lightweight migration, explicit inverse relationships, `demoMode` dropped | V1 frozen in `Persistence.swift` |
| H21 | Persistence | "Start fresh" erase path in the store-failure banner | — |
| H22 | Export | Export/restore carry completed, warm-up, RPE and exercise notes | format unchanged (optional fields) |

### Deferred — with reasons

| # | Item | Why not now |
|---|---|---|
| D1 | **Apple Watch / Health workout import** with de-duplication against manual sessions | Needs a de-dup rule (a Watch "Traditional Strength Training" at 18:02 vs. the app's session at 18:00) that should be designed with real data from the user's Watch, not guessed |
| D2 | **Dark mode** | A second palette designed on a real screen; the cream/sage system is light by design |
| D3 | **Supersets / circuits** | Changes the session data model (grouping) and the set-row layout; worth doing after the new session screen has been used for a few weeks |
| D4 | **Adaptive calorie targets** (MacroFactor-style weekly recalculation from intake and weight trend) | Needs 2–3 weeks of consistent logging to be meaningful, and a careful explanation so it does not feel like the app "changed my number" |
| D5 | **Accessibility pass** with VoiceOver running | Labels added where obvious; the set row (five controls) needs testing with VoiceOver on |
| D6 | **Food amounts in ounces / household measures** | Display-only conversion is easy; the serving UI needs redesign to avoid mixing units |
| D7 | **Background Health delivery** | Background Modes capability and battery behaviour; foreground sync covers daily use |
| D8 | **Swift 6 language mode** | After the app is stable on device |

---

## 4. Design principles applied

Written down so future changes stay consistent.

1. **The headline number is the one you act on.** Remaining, not consumed. To go, not eaten.
2. **Never make the user type what the app already knows.** Ghost values, tick-to-adopt, repeat, copy yesterday, saved meals.
3. **Every action gives feedback.** Haptics on log/complete/warn; timer state visible; PR tag.
4. **Forgiving consistency.** Streaks count ≥ 70%, and an in-progress today never breaks one.
5. **Calm, not gamified.** No red rings, no confetti, orange only for "over".
6. **Data is the user's.** Export/restore, a documented migration, and an explicit erase instead of a silent reset.

---

## 5. What to do on the Mac

```bash
cd ~/Developer/life-hacker && ./update.sh
```

Then ⌘R. This build performs the V1→V2 store migration on first launch. If the store cannot be opened,
the orange banner now has **Start fresh…**; confirm it, quit the app completely, and reopen.

To check the build you are running: Settings → bottom of the Privacy section shows version, build and
data schema (2.0.0 for this pass).
