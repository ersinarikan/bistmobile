#!/usr/bin/env bash
# Install Google Play Billing service account on lotlot.net and enable google_play.
# Does not touch Apple IAP / apple:true. Secrets never printed.
# Usage: place SA JSON in Downloads as lotlot-play-billing.json (or pass path), then:
#   tool/android_play_billing_bootstrap.sh install [path-to.json]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PACKAGE_NAME="com.lotlot.lotlotnet_mobile"
REMOTE_SA="/opt/bist-pattern/.secrets/google-play-sa.json"
SSH_KEY="${LOTLOT_SSH_KEY:-$HOME/.ssh/id_ed25519_lotlot}"
SSH_HOST="${LOTLOT_SSH_HOST:-root@lotlot.net}"

die() { echo "ERROR: $*" >&2; exit 1; }

find_sa() {
  if [[ -n "${1:-}" && -f "$1" ]]; then echo "$1"; return 0; fi
  local c
  for c in \
    "$HOME/Downloads/lotlot-play-billing.json" \
    "$HOME/Downloads/google-play-sa.json" \
    "$HOME/Desktop/lotlot-play-billing.json" \
    "$ROOT/.secrets/google-play-sa.json"
  do
    [[ -f "$c" ]] && { echo "$c"; return 0; }
  done
  return 1
}

validate_sa() {
  local src="$1"
  python3 - "$src" <<'PY'
import json, sys
path = sys.argv[1]
with open(path) as f:
    data = json.load(f)
for k in ("type", "project_id", "private_key", "client_email"):
    if k not in data:
        raise SystemExit(f"missing key {k!r} in SA JSON")
if data.get("type") != "service_account":
    raise SystemExit("type must be service_account")
email = data["client_email"]
if "@" not in email:
    raise SystemExit("client_email invalid")
print(f"OK SA client_email={email} project_id={data.get('project_id')}")
PY
}

install_remote() {
  local src="$1"
  validate_sa "$src"
  [[ -f "$SSH_KEY" ]] || die "Missing SSH key $SSH_KEY"
  echo "Uploading SA to $SSH_HOST (path only; JSON not echoed)..."
  scp -i "$SSH_KEY" -o BatchMode=yes "$src" "$SSH_HOST:/tmp/lotlot-play-sa.json"
  ssh -i "$SSH_KEY" -o BatchMode=yes "$SSH_HOST" \
    REMOTE_SA="$REMOTE_SA" PACKAGE_NAME="$PACKAGE_NAME" 'bash -s' <<'REMOTE'
set -euo pipefail
install -d -m 700 -o bist-pattern -g bist-pattern /opt/bist-pattern/.secrets
install -m 600 -o bist-pattern -g bist-pattern /tmp/lotlot-play-sa.json "$REMOTE_SA"
rm -f /tmp/lotlot-play-sa.json
DIR=/etc/systemd/system/bist-pattern.service.d
CONF=$DIR/99-iap.conf
TS=$(date +%Y%m%d_%H%M%S)
[[ -f "$CONF" ]] && cp -a "$CONF" "${CONF}.bak.${TS}" || true
# Preserve existing Apple IAP lines; ensure Google Play vars present.
python3 - "$CONF" "$REMOTE_SA" "$PACKAGE_NAME" <<'PY'
import pathlib, sys
path, sa, pkg = pathlib.Path(sys.argv[1]), sys.argv[2], sys.argv[3]
text = path.read_text() if path.exists() else "[Service]\n"
lines = text.splitlines()
# Drop old Google Play Environment lines
keep = []
for line in lines:
    if line.startswith("Environment=GOOGLE_PLAY_"):
        continue
    keep.append(line)
# Ensure [Service]
if not any(l.strip() == "[Service]" for l in keep):
    keep.insert(0, "[Service]")
# Insert after [Service]
out = []
inserted = False
for line in keep:
    out.append(line)
    if line.strip() == "[Service]" and not inserted:
        out.append(f"Environment=GOOGLE_PLAY_PACKAGE_NAME={pkg}")
        out.append(f"Environment=GOOGLE_PLAY_SERVICE_ACCOUNT_FILE={sa}")
        inserted = True
if not inserted:
    out.append(f"Environment=GOOGLE_PLAY_PACKAGE_NAME={pkg}")
    out.append(f"Environment=GOOGLE_PLAY_SERVICE_ACCOUNT_FILE={sa}")
# Comment
if not any("Google Play SA" in l for l in out):
    # after [Service]
    for i, l in enumerate(out):
        if l.strip() == "[Service]":
            out.insert(i + 1, "# Mobile IAP — Apple + Google Play (SA file).")
            break
path.write_text("\n".join(out) + "\n")
print(f"Updated {path}")
PY
chmod 0644 "$CONF"
systemctl daemon-reload
systemctl restart bist-pattern.service
for i in $(seq 1 20); do
  st=$(systemctl is-active bist-pattern.service || true)
  echo "attempt $i: $st"
  [[ "$st" = active ]] && break
  sleep 2
done
systemctl is-active bist-pattern.service
pid=$(systemctl show -p MainPID --value bist-pattern.service)
tr '\0' '\n' < /proc/$pid/environ | awk -F= '
  $1=="IAP_ENABLED"{print "IAP_ENABLED="$2}
  $1=="APPLE_IAP_BUNDLE_ID"{print "APPLE_IAP_BUNDLE_ID="$2}
  $1=="GOOGLE_PLAY_PACKAGE_NAME"{print "GOOGLE_PLAY_PACKAGE_NAME="$2}
  $1=="GOOGLE_PLAY_SERVICE_ACCOUNT_FILE"{print "GOOGLE_PLAY_SERVICE_ACCOUNT_FILE_set=yes"}
'
REMOTE
  echo "Remote install done. Checking public config..."
  curl -sS --max-time 15 https://lotlot.net/api/billing/iap/config | python3 -c '
import json,sys
d=json.load(sys.stdin)
iap=d.get("iap") or {}
plat=iap.get("platforms") or {}
print("apple=", plat.get("apple"), "google_play=", plat.get("google_play"), "verify_ready=", iap.get("verify_ready"))
if plat.get("google_play") is not True:
    raise SystemExit("google_play is not true yet — check SA permissions in Play Console")
'
}

check_config() {
  curl -sS --max-time 15 https://lotlot.net/api/billing/iap/config | python3 -m json.tool | head -40
}

usage() {
  cat <<EOF
Usage: $(basename "$0") <install|check|wait> [sa.json]

  install  Upload Play SA JSON to lotlot.net + set GOOGLE_PLAY_* (Apple untouched)
  check    Print GET /api/billing/iap/config (platforms)
  wait     Poll Downloads for lotlot-play-billing.json up to 15m, then install
EOF
}

cmd="${1:-}"
case "$cmd" in
  install)
    src="$(find_sa "${2:-}")" || die "SA JSON yok. Play Console’dan indirip Downloads/lotlot-play-billing.json koy."
    install_remote "$src"
    ;;
  check) check_config ;;
  wait)
    echo "Waiting for lotlot-play-billing.json (15 min)..."
    for _ in $(seq 1 90); do
      if find_sa >/dev/null; then
        install_remote "$(find_sa)"
        exit 0
      fi
      sleep 10
    done
    die "Timed out waiting for SA JSON"
    ;;
  *) usage; exit 1 ;;
esac
