#!/bin/bash
set -euo pipefail

SCRIPT_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIRECTORY="$(cd "$SCRIPT_DIRECTORY/.." && pwd)"
cd "$PROJECT_DIRECTORY"

required_files=(
    ".github/workflows/ci.yml"
    ".github/workflows/documentation.yml"
    "Scripts/build-documentation.sh"
    "CHANGELOG.md"
    "CONTRIBUTING.md"
    "LICENSE"
    "README.md"
    "SECURITY.md"
    "THIRD_PARTY_NOTICES.md"
    "docs/continuous-integration.md"
    "docs/assets/results-gallery/README.md"
    "docs/version-0.1.0.md"
)

for required_file in "${required_files[@]}"; do
    if [[ ! -f "$required_file" ]]; then
        echo "Missing release file: $required_file" >&2
        exit 1
    fi
done

release_files() {
    git ls-files --cached --others --exclude-standard "$@"
}

scan_release_text() {
    local pattern="$1"
    local found=1
    while IFS= read -r -d '' candidate_file; do
        if [[ ! -f "$candidate_file" ]]; then
            continue
        fi
        if [[ "$candidate_file" == "Scripts/check-release-hygiene.sh" ]]; then
            continue
        fi
        if /usr/bin/grep -I -H -n -E "$pattern" "$candidate_file"; then
            found=0
        fi
    done < <(release_files -z)
    return "$found"
}

if release_files | /usr/bin/grep -Eiq '\.(avi|mkv|mov|mp4|webm)$'; then
    echo "Video media is not allowed in release source:" >&2
    release_files | /usr/bin/grep -Ei '\.(avi|mkv|mov|mp4|webm)$' >&2
    exit 1
fi

if scan_release_text '/Users/[^/[:space:]]+|/Volumes/[^/[:space:]]+'; then
    echo "Release source contains an absolute local user or volume path." >&2
    exit 1
fi

credential_pattern='AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35}|gh[pousr]_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9_-]{20,}|-----BEGIN ([A-Z ]+ )?PRIVATE KEY-----'
if scan_release_text "$credential_pattern"; then
    echo "Release source contains a value matching a credential pattern." >&2
    exit 1
fi

development_team_pattern='(^|[[:space:]])(PFK_)?DEVELOPMENT_TEAM[[:space:]]*=[[:space:]]*[A-Z0-9]{10}([;[:space:]]|$)'
if scan_release_text "$development_team_pattern"; then
    echo "Release source contains a hard-coded Apple development team." >&2
    echo "Use Examples/PosterFrameIOSExample/Config/Signing.local.xcconfig instead." >&2
    exit 1
fi

git diff --check
echo "Release hygiene checks passed."
