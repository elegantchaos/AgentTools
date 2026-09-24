#!/usr/bin/env bash
# Checks that `agt validate` works in a sandbox that allows writes only where an agent's sandbox should:
# the repository, temporary directories, SwiftPM's cache, and the per-user clang module cache.
#
# Usage: Extras/Scripts/sandbox-check.sh [repository]
#
# Without a repository, validates a copy of Extras/Fixtures/SwiftPackage. Set AGT to choose the agt binary.
# Validation runs under sandbox-exec with writes denied everywhere else, as in an agent's sandbox, so any
# write elsewhere that validation needs makes the run fail. Writes that a tool attempts and quietly gives up
# on are not detected.
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
agt="${AGT:-agt}"
agt="$(command -v "$agt")"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

if [ $# -gt 0 ]; then
  repo="$(cd "$1" && pwd -P)"
else
  repo="$work/SwiftPackage"
  cp -R "$root/Extras/Fixtures/SwiftPackage" "$repo"
  git -C "$repo" init --quiet
fi

tmp="$(cd "${TMPDIR:-/tmp}" && pwd -P)"
swiftpm_cache="$HOME/Library/Caches/org.swift.swiftpm"
module_cache="$(getconf DARWIN_USER_CACHE_DIR)clang/ModuleCache"

profile="(version 1)
(allow default)
(deny file-write*)
(allow file-write*
  (subpath \"$repo\")
  (subpath \"$swiftpm_cache\")
  (subpath \"$module_cache\")
  (subpath \"$tmp\")
  (subpath \"/private/tmp\")
  (regex #\"^/dev/\"))"

echo "== Validating $repo in a sandbox"
status=0
(cd "$repo" && sandbox-exec -p "$profile" "$agt" validate) || status=$?

exit "$status"
