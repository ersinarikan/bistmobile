#!/usr/bin/env bash
# Local iOS push bootstrap — GoogleService-Info.plist + optional prod FCM env.
# Secrets never printed. Do not commit ios/Runner/GoogleService-Info.plist or .secrets/.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/ios/Runner/GoogleService-Info.plist"
PBX="$ROOT/ios/Runner.xcodeproj/project.pbxproj"
SECRETS="$ROOT/.secrets/fcm.env"
BUNDLE_ID="com.lotlot.lotlotnetMobile"

die() { echo "ERROR: $*" >&2; exit 1; }

find_plist() {
  local c
  for c in \
    "$HOME/Downloads/GoogleService-Info.plist" \
    "$HOME/Desktop/GoogleService-Info.plist" \
    "$ROOT/GoogleService-Info.plist" \
    "$DEST"
  do
    if [[ -f "$c" ]]; then
      echo "$c"
      return 0
    fi
  done
  return 1
}

ensure_pbx_resource() {
  if grep -q 'GoogleService-Info.plist in Resources' "$PBX"; then
    echo "Xcode project already references GoogleService-Info.plist"
    return 0
  fi
  # Stable synthetic IDs (24 hex)
  local REF="A11C0F1EEB00100000000001"
  local BUILD="A11C0F1EEB00100000000002"
  python3 - "$PBX" "$REF" "$BUILD" <<'PY'
import sys
path, ref, build = sys.argv[1:4]
text = open(path).read()
if "GoogleService-Info.plist in Resources" in text:
    print("already present")
    raise SystemExit(0)
# PBXBuildFile
needle = "/* Begin PBXBuildFile section */\n"
insert_bf = (
    needle
    + f"\t\t{build} /* GoogleService-Info.plist in Resources */ = "
      f"{{isa = PBXBuildFile; fileRef = {ref} /* GoogleService-Info.plist */; }};\n"
)
if needle not in text:
    raise SystemExit("PBXBuildFile section missing")
text = text.replace(needle, insert_bf, 1)
# PBXFileReference
needle = "/* Begin PBXFileReference section */\n"
insert_fr = (
    needle
    + f"\t\t{ref} /* GoogleService-Info.plist */ = {{isa = PBXFileReference; "
      f'fileEncoding = 4; lastKnownFileType = text.plist.xml; path = "GoogleService-Info.plist"; '
      f'sourceTree = "<group>"; }};\n'
)
if needle not in text:
    raise SystemExit("PBXFileReference section missing")
text = text.replace(needle, insert_fr, 1)
# Runner group children — after Info.plist
old = "\t\t\t\t97C147021CF9000F007C117D /* Info.plist */,\n"
new = old + f"\t\t\t\t{ref} /* GoogleService-Info.plist */,\n"
if old not in text:
    raise SystemExit("Runner Info.plist group entry missing")
text = text.replace(old, new, 1)
# Resources build phase
old = "\t\t\t\t97C146FC1CF9000F007C117D /* Main.storyboard in Resources */,\n"
new = (
    f"\t\t\t\t{build} /* GoogleService-Info.plist in Resources */,\n" + old
)
if old not in text:
    raise SystemExit("Resources phase Main.storyboard entry missing")
text = text.replace(old, new, 1)
open(path, "w").write(text)
print("Added GoogleService-Info.plist to Xcode project resources")
PY
}

install_plist() {
  local src
  src="$(find_plist)" || die "GoogleService-Info.plist bulunamadı. Downloads/Desktop’a kaydedip tekrar çalıştır."
  # Validate bundle id without dumping full plist to stdout beyond check
  if ! /usr/libexec/PlistBuddy -c 'Print :BUNDLE_ID' "$src" 2>/dev/null | grep -qx "$BUNDLE_ID"; then
    local got
    got="$(/usr/libexec/PlistBuddy -c 'Print :BUNDLE_ID' "$src" 2>/dev/null || echo '?')"
    die "BUNDLE_ID mismatch: got '$got', expected '$BUNDLE_ID'"
  fi
  mkdir -p "$(dirname "$DEST")"
  cp -f "$src" "$DEST"
  echo "Installed $DEST (BUNDLE_ID OK)"
  ensure_pbx_resource
}

apply_prod_fcm() {
  [[ -f "$SECRETS" ]] || die "Missing $SECRETS — copy from .secrets/fcm.env.example and fill FCM_SERVER_KEY"
  # shellcheck disable=SC1090
  set -a
  # shellcheck source=/dev/null
  source "$SECRETS"
  set +a
  [[ "${FCM_ENABLED:-}" == "1" ]] || die "FCM_ENABLED must be 1 in $SECRETS"
  [[ -n "${FCM_SERVER_KEY:-}" ]] || die "FCM_SERVER_KEY empty in $SECRETS"
  local key_len=${#FCM_SERVER_KEY}
  echo "Applying prod FCM (key length=$key_len; value not printed)..."
  ssh -o BatchMode=yes -i "$HOME/.ssh/id_ed25519_lotlot" root@lotlot.net \
    FCM_ENABLED="$FCM_ENABLED" \
    FCM_SERVER_KEY="$FCM_SERVER_KEY" \
    WATCHLIST_ALERTS_ENABLED="${WATCHLIST_ALERTS_ENABLED:-1}" \
    'bash -s' <<'REMOTE'
set -euo pipefail
DIR=/etc/systemd/system/bist-pattern.service.d
CONF=$DIR/99-fcm.conf
ENVF=$DIR/fcm-server.env
TS=$(date +%Y%m%d_%H%M%S)
[[ -f "$CONF" ]] && cp -a "$CONF" "${CONF}.bak.${TS}" || true
[[ -f "$ENVF" ]] && cp -a "$ENVF" "${ENVF}.bak.${TS}" || true
# EnvironmentFile keeps key intact (no quote stripping)
umask 077
printf 'FCM_SERVER_KEY=%s\n' "$FCM_SERVER_KEY" > "$ENVF"
chmod 0600 "$ENVF"
cat > "$CONF" <<EOF
[Service]
# Mobile FCM — legacy HTTP API (bist_pattern/notifications/fcm.py)
Environment=FCM_ENABLED=1
Environment=WATCHLIST_ALERTS_ENABLED=${WATCHLIST_ALERTS_ENABLED}
EnvironmentFile=-/etc/systemd/system/bist-pattern.service.d/fcm-server.env
EOF
chmod 0644 "$CONF"
systemctl daemon-reload
systemctl restart bist-pattern.service
for i in $(seq 1 20); do
  st=$(systemctl is-active bist-pattern.service || true)
  echo "attempt $i: $st"
  [[ "$st" = active ]] && break
  sleep 3
done
systemctl is-active bist-pattern.service
pid=$(systemctl show -p MainPID --value bist-pattern.service)
echo "MainPID=$pid"
# Verify keys exist without printing secret values
tr '\0' '\n' < /proc/$pid/environ | awk -F= '
  $1=="FCM_ENABLED"{print "FCM_ENABLED="$2}
  $1=="WATCHLIST_ALERTS_ENABLED"{print "WATCHLIST_ALERTS_ENABLED="$2}
  $1=="FCM_SERVER_KEY"{print "FCM_SERVER_KEY_set=yes len=" length($2)}
'
REMOTE
  echo "Prod FCM applied."
}

usage() {
  cat <<EOF
Usage: $(basename "$0") <plist|prod-fcm|all|wait-plist>

  plist      Copy GoogleService-Info.plist into ios/Runner + Xcode resources
  prod-fcm   Apply .secrets/fcm.env to lotlot.net bist-pattern (restart)
  all        plist then prod-fcm
  wait-plist Poll Downloads/Desktop up to 15m for the plist, then install
EOF
}

cmd="${1:-}"
case "$cmd" in
  plist) install_plist ;;
  prod-fcm) apply_prod_fcm ;;
  all) install_plist; apply_prod_fcm ;;
  wait-plist)
    echo "Waiting for GoogleService-Info.plist in Downloads/Desktop (15 min)..."
    for i in $(seq 1 90); do
      if find_plist >/dev/null; then
        install_plist
        exit 0
      fi
      sleep 10
    done
    die "Timed out waiting for GoogleService-Info.plist"
    ;;
  *) usage; exit 1 ;;
esac
