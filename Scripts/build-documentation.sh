#!/bin/bash
set -euo pipefail

if (( $# > 1 )); then
    echo "Usage: $0 [hosting-base-path]" >&2
    exit 1
fi

SCRIPT_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIRECTORY="$(cd "$SCRIPT_DIRECTORY/.." && pwd)"
cd "$PROJECT_DIRECTORY"

HOSTING_BASE_PATH="${1-/poster-frame-kit}"
DERIVED_DATA_DIRECTORY="$PROJECT_DIRECTORY/.build/documentation-derived-data"
OUTPUT_DIRECTORY="$PROJECT_DIRECTORY/.build/documentation-site"

xcodebuild docbuild -quiet \
    -scheme PosterFrameKit \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "$DERIVED_DATA_DIRECTORY" \
    CODE_SIGNING_ALLOWED=NO \
    OTHER_DOCC_FLAGS=--warnings-as-errors

xcrun docc process-archive transform-for-static-hosting \
    "$DERIVED_DATA_DIRECTORY/Build/Products/Debug/PosterFrameKit.doccarchive" \
    --output-path "$OUTPUT_DIRECTORY" \
    --hosting-base-path "$HOSTING_BASE_PATH"

echo "Documentation site: $OUTPUT_DIRECTORY"
