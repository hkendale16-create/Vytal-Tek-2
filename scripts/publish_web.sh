#!/usr/bin/env bash
# Rebuild the Flutter web app into site/app/ for Netlify.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="${FLUTTER_ROOT:-$HOME/flutter}/bin:${PATH}"

cd "$ROOT/apps/mobile"
flutter pub get
flutter build web --release --base-href /app/ --no-wasm-dry-run

rm -rf "$ROOT/site/app"
mkdir -p "$ROOT/site/app"
# CanvasKit is loaded from gstatic (web-resources-cdn). Keep the commit small.
rsync -a --exclude canvaskit "$ROOT/apps/mobile/build/web/" "$ROOT/site/app/"

python3 - "$ROOT" <<'PY'
from pathlib import Path
import sys
root = Path(sys.argv[1])
bootstrap = root / "site/app/flutter_bootstrap.js"
text = bootstrap.read_text()
start = text.rfind("_flutter.loader.load(")
if start < 0:
    raise SystemExit("Could not find _flutter.loader.load(")
bootstrap.write_text(text[:start] + "_flutter.loader.load();\n")

index = root / "site/app/index.html"
html = index.read_text()
html = html.replace("A new Flutter project.", "Vytal Tek — personal health and performance.")
html = html.replace("<title>vytal_tek</title>", "<title>Vytal Tek</title>")
html = html.replace('content="vytal_tek"', 'content="Vytal Tek"')
index.write_text(html)
print("Published site/app")
PY
