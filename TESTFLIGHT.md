# Sharing Aurelia through TestFlight

TestFlight is Apple's beta channel. You upload a build once; anyone you invite installs it from the
TestFlight app on their own iPhone, with no Mac and no cable. It also removes the 7-day expiry of free-account
installs for you. It needs a paid Apple Developer membership (US$99 per year).

## One-time setup

1. **Enrol** at [developer.apple.com/programs/enroll](https://developer.apple.com/programs/enroll) with the
   same Apple ID Xcode is signed in to. Approval usually takes a day or two; Apple emails you.
2. **Confirm your Team ID.** Xcode → Settings → Accounts → your Apple ID. The 10-character ID next to
   your name is `DEVELOPMENT_TEAM` in `Config/Secrets.xcconfig`. It does not change when you enrol.
3. **Create the app record.** Go to [appstoreconnect.apple.com](https://appstoreconnect.apple.com) →
   Apps → **+** → New App:
   - Platform: iOS
   - Name: Aurelia (or anything; the name must be unique on the store, so "Aurelia Wellness" if taken)
   - Primary language: English
   - Bundle ID: pick the one from `Config/Secrets.xcconfig`. If it is not in the list, build once to a
     device with ⌘R first: automatic signing registers it.
   - SKU: `aurelia` (any internal label)
4. **Answer the two TestFlight questions** under the app → TestFlight → Test Information: a feedback
   email (yours) and, under App Privacy, "Data not collected". These only need doing once.

## Every release

```bash
cd ~/Developer/life-hacker && ./release.sh
```

The script:

1. Checks your work is committed and signing is configured.
2. Bumps the build number in `Config/Version.xcconfig` and commits it (`./release.sh 1.1` also sets the
   version people see).
3. Archives a Release build and uploads it to App Store Connect. The first archive with a new
   membership can take a few extra minutes while Xcode creates the distribution certificate; if it
   asks about keychain access, allow it.
4. Pushes the commit.

If the script fails at the upload step, the archive is still in `build/`. Open Xcode → Window →
Organizer, select it, and press **Distribute App → TestFlight & App Store Connect**. That is the manual
equivalent.

Processing takes 5 to 15 minutes. App Store Connect emails you when the build is ready. Testers are
notified automatically and update from the TestFlight app.

## Inviting your friend

1. App Store Connect → your app → **TestFlight** → **External Testing** (left column) → **+** to create a
   group, for example "Friends".
2. Add the build to the group. The first build in an external group goes through a short Apple review
   (usually under a day). Later builds are usually available immediately.
3. Add your friend's email under Testers. They receive an invitation, install the **TestFlight** app from
   the App Store, accept, and install Aurelia.

Internal Testing (up to 100 people you add to your App Store Connect team) skips the review entirely.
For one or two friends the external group is simpler because they do not need a team role.

## Things to know

- **Their data is theirs.** The app is offline-first. Nothing your friend logs reaches you or Apple, and
  nothing of yours reaches them.
- **The food-search proxy.** `NUTRITION_PROXY_URL` from your `Secrets.xcconfig` is baked into the build.
  Anyone with the app can call that Supabase function. It is fine for a friend; if you ever invite more
  people, leave the URL empty for release builds or add a key to the function. Barcode lookup through
  Open Food Facts works without it.
- **Builds expire after 90 days** on TestFlight. Upload a new one before then and testers keep going.
- **HealthKit and camera** use the descriptions already in `Info.plist`. No extra review paperwork for
  TestFlight.
- **Schema changes.** Your friend's data goes through the same migration plan as yours
  (`Aurelia/Persistence.swift`). Never delete a model's fields without a migration stage, because you
  cannot ask a tester to "start fresh".
- **Encryption question.** `ITSAppUsesNonExemptEncryption` is `false` in `Info.plist` because the app only
  uses HTTPS, so App Store Connect will not ask on every upload.
- **Your own phone.** You can keep using ⌘R, or install from TestFlight like everyone else. Installing the
  TestFlight build over the Xcode build keeps your data as long as the bundle identifier is the same.

## Going to the App Store later

Everything above carries over. The additions are a privacy policy URL, screenshots, a description, an age
rating, and Apple's review of the HealthKit and camera justifications. Budget a few evenings.
