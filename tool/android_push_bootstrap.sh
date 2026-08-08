#!/usr/bin/env bash
# Local Android push bootstrap — google-services.json into android/app/.
# Secrets never printed. Do not commit android/app/google-services.json.
# Does not touch iOS plist / ios_push_bootstrap.sh.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/android/app/google-services.json"
PACKAGE_ID="com.lotlot.lotlotnet_mobile"
PROJECT_ID="lotlotnet-8c348"

die() { echo "ERROR: $*" >&2; exit 1; }

find_json() {
  local c
  for c in \
    "$HOME/Downloads/google-services.json" \
    "$HOME/Desktop/google-services.json" \
    "$ROOT/google-services.json" \
    "$DEST"
  do
    if [[ -f "$c" ]]; then
      echo "$c"
      return 0
    fi
  done
  return 1
}

validate_json() {
  local src="$1"
  python3 - "$src" "$PACKAGE_ID" "$PROJECT_ID" <<'PY'
import json, sys
path, package, project = sys.argv[1:4]
with open(path) as f:
    data = json.load(f)
pid = data.get("project_info", {}).get("project_id", "")
if pid != project:
    raise SystemExit(f"project_id mismatch: got {pid!r}, expected {project!r}")
clients = data.get("client") or []
pkgs = []
for c in clients:
    p = (c.get("client_info") or {}).get("android_client_info") or {}
    name = p.get("package_name")
    if name:
        pkgs.append(name)
if package not in pkgs:
    raise SystemExit(f"package_name {package!r} not in clients {pkgs!r}")
print(f"OK project_id={pid} package={package}")
PY
}

install_json() {
  local src
  src="$(find_json)" || die "google-services.json bulunamadı. Downloads/Desktop’a kaydedip tekrar çalıştır."
  validate_json "$src"
  mkdir -p "$(dirname "$DEST")"
  cp -f "$src" "$DEST"
  chmod 600 "$DEST" 2>/dev/null || true
  echo "Installed $DEST"
}

check_only() {
  [[ -f "$DEST" ]] || die "Missing $DEST — run: $(basename "$0") install"
  validate_json "$DEST"
  echo "Present: $DEST"
}

usage() {
  cat <<EOF
Usage: $(basename "$0") <install|check|wait>

  install  Copy google-services.json into android/app/ (validate package + project)
  check    Validate existing android/app/google-services.json
  wait     Poll Downloads/Desktop up to 15m, then install
EOF
}

cmd="${1:-}"
case "$cmd" in
  install) install_json ;;
  check) check_only ;;
  wait)
    echo "Waiting for google-services.json in Downloads/Desktop (15 min)..."
    for _ in $(seq 1 90); do
      if find_json >/dev/null; then
        install_json
        exit 0
      fi
      sleep 10
    done
    die "Timed out waiting for google-services.json"
    ;;
  *) usage; exit 1 ;;
esac
