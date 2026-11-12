#!/usr/bin/env bash
set -Eeuo pipefail

# KijaniKiosk staging blue/green switch controller.
# Usage: sudo bash switch-env.sh blue|green

readonly STATE_DIR="/opt/kijanikiosk"
readonly ACTIVE_FILE="${STATE_DIR}/.active-env"
readonly PREVIOUS_FILE="${STATE_DIR}/.previous-env"
readonly NGINX_ACTIVE="/etc/nginx/kijanikiosk-active-env.conf"
readonly NGINX_INCLUDE="/etc/nginx/conf.d/kijanikiosk-active-env.conf"
readonly LOCK_FILE="/run/lock/kijanikiosk-switch.lock"

log() { printf '[%s] %s\n' "$(date --iso-8601=seconds)" "$*"; }
fail() { log "ERROR: $*" >&2; exit 1; }

[[ ${EUID} -eq 0 ]] || fail 'Run with sudo/root.'
[[ $# -eq 1 ]] || fail 'Usage: switch-env.sh blue|green'

TARGET="$1"
case "$TARGET" in
  blue) PORT=3000; VERSION=v1.3.0; SERVICE=kk-api-blue.service ;;
  green) PORT=3001; VERSION=v1.4.0; SERVICE=kk-api-green.service ;;
  *) fail 'Target must be blue or green.' ;;
esac

mkdir -p "$(dirname "$LOCK_FILE")" "$STATE_DIR"
exec 9>"$LOCK_FILE"
flock -n 9 || fail 'Another switch operation is in progress.'

OLD_ACTIVE="none"
if [[ -f "$ACTIVE_FILE" ]]; then
  OLD_ACTIVE="$(<"$ACTIVE_FILE")"
  [[ "$OLD_ACTIVE" == blue || "$OLD_ACTIVE" == green ]] ||
    fail "Invalid active state: $OLD_ACTIVE"
fi

log "Requested target=$TARGET service=$SERVICE port=$PORT version=$VERSION"

# Start target and wait for its direct health endpoint.
systemctl start "$SERVICE"
READY=0
for _ in $(seq 1 20); do
  if systemctl is-active --quiet "$SERVICE" &&
     curl --connect-timeout 1 --max-time 2 -fsS \
       "http://127.0.0.1:${PORT}/health" |
       grep -Fq "\"version\":\"${VERSION}\""; then
    READY=1
    break
  fi
  sleep 1
done
[[ $READY -eq 1 ]] || fail "$TARGET did not become healthy within 20 seconds."

# Back up current upstream before modifying it.
BACKUP="$(mktemp)"
if [[ -f "$NGINX_ACTIVE" ]]; then
  cp -a "$NGINX_ACTIVE" "$BACKUP"
else
  : > "$BACKUP"
fi

CONFIG_TMP="$(mktemp "${NGINX_ACTIVE}.XXXXXX")"
cleanup() { rm -f "$CONFIG_TMP" "$BACKUP"; }
trap cleanup EXIT

cat > "$CONFIG_TMP" <<NGINX
upstream kijanikiosk_active {
    # Active service: ${SERVICE}
    server 127.0.0.1:${PORT};
    keepalive 16;
}
NGINX

chmod 0644 "$CONFIG_TMP"
mv -f "$CONFIG_TMP" "$NGINX_ACTIVE"

# Ensure Nginx loads the canonical active configuration.
if [[ ! -e "$NGINX_INCLUDE" ]]; then
  ln -s "$NGINX_ACTIVE" "$NGINX_INCLUDE"
fi

restore_upstream() {
  if [[ -s "$BACKUP" ]]; then
    cp -a "$BACKUP" "$NGINX_ACTIVE"
  else
    rm -f "$NGINX_ACTIVE"
  fi
  nginx -t && systemctl reload nginx || true
}

if ! nginx -t; then
  restore_upstream
  fail 'Nginx validation failed; previous upstream restored.'
fi

if ! systemctl reload nginx; then
  restore_upstream
  fail 'Nginx reload failed; previous upstream restored.'
fi

# Verify traffic through the public staging proxy.
if ! curl --connect-timeout 2 --max-time 5 -fsS \
     http://127.0.0.1/health |
     grep -Fq "\"version\":\"${VERSION}\""; then
  restore_upstream
  fail 'Proxy verification failed; previous upstream restored.'
fi

# Commit state only after the switch is verified.
write_state() {
  local path="$1" value="$2" tmp
  tmp="$(mktemp "${path}.XXXXXX")"
  printf '%s\n' "$value" > "$tmp"
  chmod 0644 "$tmp"
  mv -f "$tmp" "$path"
}

write_state "$PREVIOUS_FILE" "$OLD_ACTIVE"
write_state "$ACTIVE_FILE" "$TARGET"

log "SWITCH OK: active=$TARGET previous=$OLD_ACTIVE proxy_version=$VERSION"
