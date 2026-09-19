#!/usr/bin/env bash
# Pull the latest code without fighting Xcode.
#
# Xcode rewrites project.pbxproj when it opens the project or when signing is
# touched in the UI. Those edits are never wanted here — the Team and bundle ID
# come from Config/Secrets.xcconfig — so they are shown, then discarded, then
# the pull goes through. Run this instead of `git pull`.
set -euo pipefail
cd "$(dirname "$0")"

# Files Xcode rewrites on its own. Edits to them are made here, in git, never
# by hand on the Mac, so local changes are always Xcode's and safe to drop.
for f in Aurelia.xcodeproj/project.pbxproj Aurelia/Info.plist; do
  if ! git diff --quiet -- "$f"; then
    echo "Xcode changed $f; discarding these lines:"
    git diff -- "$f" | grep '^[-+]' | grep -v '^[-+][-+]' | sed 's/^/    /' | head -20
    git checkout -- "$f"
    echo
  fi
done

git pull --ff-only
echo
echo "Now at: $(git log --oneline -1)"
echo "Open Xcode and press ⌘R."
