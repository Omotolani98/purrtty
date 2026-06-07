#!/usr/bin/env bash
# Build libghostty.a + ghostty.h and drop them into vendor/.
#
# purrtty links a prebuilt libghostty so its own build stays fast. This script
# clones ghostty at a pinned ref, builds the static library, and copies the
# archive AND its matching header into vendor/ (so the two never drift).
#
# Requirements:
#   - Zig 0.15.2 (ghostty's pinned compiler — MUST match build.zig.zon)
#   - Xcode or full Command Line Tools (Metal shader compilation: `xcrun metal`)
#   - git, network access (ghostty fetches ~30 vendored deps on first build)
#
# Usage:  scripts/build-libghostty.sh [git-ref]
set -euo pipefail

REF="${1:-v1.3.1}"                     # pin to a commit/tag for reproducibility
REPO="https://github.com/ghostty-org/ghostty.git"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${ROOT}/.ghostty-src"
VENDOR="${ROOT}/vendor"

echo "==> zig: $(zig version)  (ghostty needs 0.15.2)"

if [ ! -d "${WORK}/.git" ]; then
  echo "==> cloning ghostty @ ${REF}"
  git clone "${REPO}" "${WORK}"
fi
git -C "${WORK}" fetch --tags origin
git -C "${WORK}" checkout "${REF}"

echo "==> building libghostty (ReleaseFast, app-runtime=none) — this is large"
# NOTE: verify the exact lib step/flags against ghostty's build.zig for ${REF}.
# As of 1.3.x this produces zig-out/lib/libghostty.a + zig-out/include/ghostty.h.
( cd "${WORK}" && zig build -Doptimize=ReleaseFast -Dapp-runtime=none )

mkdir -p "${VENDOR}"
cp -v "${WORK}/zig-out/lib/libghostty.a" "${VENDOR}/libghostty.a"
cp -v "${WORK}/zig-out/include/ghostty.h" "${VENDOR}/ghostty.h"

echo "==> done. vendor/libghostty.a + vendor/ghostty.h updated."
echo "    now: zig build run"
