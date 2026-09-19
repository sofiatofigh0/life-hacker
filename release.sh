#!/usr/bin/env bash
# Ship a build to TestFlight.
#
#   ./release.sh          bump the build number, archive, upload
#   ./release.sh 1.1      also set the version people see
#
# Needs: a paid Apple Developer membership, Xcode signed in to that Apple ID
# (Xcode → Settings → Accounts), and Config/Secrets.xcconfig with your
# DEVELOPMENT_TEAM and bundle identifier. The first run needs the app record
# to exist in App Store Connect — see TESTFLIGHT.md.
set -euo pipefail
cd "$(dirname "$0")"

die() { echo "error: $*" >&2; exit 1; }

[ -f Config/Secrets.xcconfig ] || die "Config/Secrets.xcconfig is missing (copy Secrets.xcconfig.example)."
TEAM=$(sed -n 's/^DEVELOPMENT_TEAM *= *//p' Config/Secrets.xcconfig | tr -d '[:space:]')
[ -n "$TEAM" ] || die "DEVELOPMENT_TEAM is empty in Config/Secrets.xcconfig."
BUNDLE=$(sed -n 's/^PRODUCT_BUNDLE_IDENTIFIER *= *//p' Config/Secrets.xcconfig | tr -d '[:space:]')
case "$BUNDLE" in ""|com.example.*) die "Set a real PRODUCT_BUNDLE_IDENTIFIER in Config/Secrets.xcconfig.";; esac

if ! git diff --quiet -- . ':!Aurelia.xcodeproj/project.pbxproj' || [ -n "$(git ls-files --others --exclude-standard)" ]; then
  die "Commit or stash your changes first; a TestFlight build should match a commit."
fi
git checkout -- Aurelia.xcodeproj/project.pbxproj 2>/dev/null || true

# --- Version and build number -----------------------------------------------
VERSION_FILE=Config/Version.xcconfig
BUILD=$(sed -n 's/^CURRENT_PROJECT_VERSION *= *//p' "$VERSION_FILE" | tr -d '[:space:]')
NEXT=$((BUILD + 1))
sed -i '' "s/^CURRENT_PROJECT_VERSION *=.*/CURRENT_PROJECT_VERSION = $NEXT/" "$VERSION_FILE"
if [ $# -ge 1 ]; then
  sed -i '' "s/^MARKETING_VERSION *=.*/MARKETING_VERSION = $1/" "$VERSION_FILE"
fi
VERSION=$(sed -n 's/^MARKETING_VERSION *= *//p' "$VERSION_FILE" | tr -d '[:space:]')
git add "$VERSION_FILE"
git commit -q -m "Release $VERSION ($NEXT)"
echo "Version $VERSION, build $NEXT (committed)."

# --- Archive ------------------------------------------------------------------
mkdir -p build
ARCHIVE="build/Aurelia-$VERSION-$NEXT.xcarchive"
rm -rf "$ARCHIVE"
echo "Archiving…"
xcodebuild -project Aurelia.xcodeproj -scheme Aurelia -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates archive -quiet

# --- Upload -------------------------------------------------------------------
sed "s/TEAM_ID/$TEAM/" Config/ExportOptions.plist > build/ExportOptions.plist
echo "Uploading to App Store Connect…"
xcodebuild -exportArchive -archivePath "$ARCHIVE" \
  -exportOptionsPlist build/ExportOptions.plist -exportPath build/export \
  -allowProvisioningUpdates

git push -q origin HEAD 2>/dev/null || echo "(push failed; run: git push)"
echo
echo "Uploaded $VERSION ($NEXT). App Store Connect processes it for a few minutes,"
echo "then it appears under TestFlight and testers are notified."
