#!/usr/bin/env bash
# Pull the latest code without fighting Xcode.
#
# Xcode rewrites project.pbxproj when it opens the project or when signing is
# touched in the UI. Those edits are never wanted here — the Team and bundle ID
# come from Config/Secrets.xcconfig — so they are shown, then discarded, then
# the pull goes through. Run this instead of `git pull`.
set -euo pipefail
cd "$(dirname "$0")"

if ! git diff --quiet -- Aurelia.xcodeproj/project.pbxproj; then
  echo "Xcode changed project.pbxproj; discarding these lines:"
  git diff -- Aurelia.xcodeproj/project.pbxproj | grep '^[-+]' | grep -v '^[-+][-+]' | sed 's/^/    /' | head -20
  git checkout -- Aurelia.xcodeproj/project.pbxproj
  echo
fi

git pull --ff-only
echo
echo "Now at: $(git log --oneline -1)"
echo "Open Xcode and press ⌘R."
