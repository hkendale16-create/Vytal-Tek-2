#!/usr/bin/env bash
# Install Flutter stable from Google storage so CI does not download
# third-party GitHub Actions (which 429 under rate limits).
set -euo pipefail

CHANNEL="${FLUTTER_CHANNEL:-stable}"
FLUTTER_ROOT="${FLUTTER_ROOT:-${RUNNER_TOOL_CACHE:-$HOME}/flutter}"
RELEASES_URL="https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json"

download() {
  local url="$1"
  local out="$2"
  local attempt
  for attempt in 1 2 3 4 5; do
    if curl --fail --location --retry 5 --retry-delay 4 --retry-all-errors \
      --connect-timeout 20 --show-error -o "$out" "$url"; then
      return 0
    fi
    echo "Download failed (attempt ${attempt}/5): ${url}" >&2
    sleep $((attempt * 4))
  done
  return 1
}

mkdir -p "$(dirname "$FLUTTER_ROOT")"
mkdir -p /tmp/flutter-setup
download "$RELEASES_URL" /tmp/flutter-setup/releases.json

eval "$(
  python3 - "$CHANNEL" /tmp/flutter-setup/releases.json <<'PY'
import json, sys
channel, path = sys.argv[1], sys.argv[2]
data = json.load(open(path))
wanted = data["current_release"][channel]
for release in data["releases"]:
    if release.get("hash") == wanted and release.get("channel") == channel:
        archive = release["archive"]
        print(f'ARCHIVE_URL={data["base_url"]}/{archive}')
        print(f'VERSION={release["version"]}')
        print(f'SHA256={release.get("sha256", "")}')
        print(f'HASH={release["hash"]}')
        break
else:
    raise SystemExit(f"No {channel} release found")
PY
)"

echo "Resolved Flutter ${CHANNEL} ${VERSION} (${HASH})"

if [[ -x "${FLUTTER_ROOT}/bin/flutter" ]]; then
  echo "Flutter already present at ${FLUTTER_ROOT}"
else
  ARCHIVE_PATH="/tmp/flutter-setup/flutter.tar.xz"
  download "$ARCHIVE_URL" "$ARCHIVE_PATH"
  if [[ -n "$SHA256" ]]; then
    echo "${SHA256}  ${ARCHIVE_PATH}" | sha256sum --check --status
  fi
  EXTRACT_ROOT="$(dirname "$FLUTTER_ROOT")"
  rm -rf "$FLUTTER_ROOT"
  tar -xJf "$ARCHIVE_PATH" -C "$EXTRACT_ROOT"
  if [[ ! -x "${FLUTTER_ROOT}/bin/flutter" ]]; then
    # Archives unpack to a "flutter/" directory; relocate if needed.
    unpacked="$(find "$EXTRACT_ROOT" -maxdepth 2 -type f -path '*/bin/flutter' | head -n 1)"
    if [[ -z "$unpacked" ]]; then
      echo "Flutter binary missing after extract" >&2
      exit 1
    fi
    mv "$(dirname "$(dirname "$unpacked")")" "$FLUTTER_ROOT"
  fi
fi

git config --global --add safe.directory "$FLUTTER_ROOT" || true

if [[ -n "${GITHUB_PATH:-}" ]]; then
  echo "${FLUTTER_ROOT}/bin" >> "$GITHUB_PATH"
fi
if [[ -n "${GITHUB_ENV:-}" ]]; then
  echo "FLUTTER_ROOT=${FLUTTER_ROOT}" >> "$GITHUB_ENV"
  echo "PUB_CACHE=${PUB_CACHE:-$HOME/.pub-cache}" >> "$GITHUB_ENV"
fi

export PATH="${FLUTTER_ROOT}/bin:${PATH}"
flutter --version
