#!/usr/bin/env bash
set -Eeuo pipefail

# Usage: sudo bash post-deploy-monitor.sh [duration_seconds]
# Default monitoring window: 60 seconds.

readonly STATE_DIR="/opt/kijanikiosk"
readonly ACTIVE_FILE="${STATE_DIR}/.active-env"
readonly PREVIOUS_FILE="${STATE_DIR}/.previous-env"
readonly SWITCH_SCRIPT="${STATE_DIR}/bluegreen/switch-env.sh"

DURATION="${1:-60}"
INTERVAL=2

log() { printf '[%s] %s\n' "$(date --iso-8601=seconds)" "$*"; }
fail() { log "ERROR: $*" >&2; exit 1; }

[[ ${EUID} -eq 0 ]] || fail 'Run with sudo/root.'
[[ "$DURATION" =~ ^[0-9]+$ ]] || fail 'Duration must be an integer.'
(( DURATION > 0 )) || fail 'Duration must be greater than zero.'

[[ -f "$ACTIVE_FILE" ]] || fail 'Active environment state is missing.'
ACTIVE="$(<"$ACTIVE_FILE")"

case "$ACTIVE" in
  blue) PORT=3000; SERVICE=kk-api-blue.service ;;
  green) PORT=3001; SERVICE=kk-api-green.service ;;
  *) fail "Invalid active environment: $ACTIVE" ;;
esac

log "MONITOR START: active=$ACTIVE duration=${DURATION}s"

START="$(date +%s)"
DEADLINE=$((START + DURATION))

while (( $(date +%s) < DEADLINE )); do
  if systemctl is-active --quiet "$SERVICE" &&
     curl --connect-timeout 1 --max-time 2 -fsS \
       "http://127.0.0.1:${PORT}/health" >/dev/null &&
     curl --connect-timeout 1 --max-time 2 -fsS \
       http://127.0.0.1/health >/dev/null; then
    sleep "$INTERVAL"
    continue
  fi

  log "[MONITOR FAIL] active=$ACTIVE service=$SERVICE health check failed"
  log "[MONITOR FAIL] ROLLBACK TRIGGERED"

  [[ -f "$PREVIOUS_FILE" ]] || fail 'Previous environment state is missing.'
  PREVIOUS="$(<"$PREVIOUS_FILE")"
  [[ "$PREVIOUS" == blue || "$PREVIOUS" == green ]] ||
    fail "No valid rollback target recorded: $PREVIOUS"

  log "Rollback target=$PREVIOUS"
  bash "$SWITCH_SCRIPT" "$PREVIOUS"

  case "$PREVIOUS" in
    blue) EXPECTED=v1.3.0 ;;
    green) EXPECTED=v1.4.0 ;;
  esac

  curl --connect-timeout 2 --max-time 5 -fsS \
    http://127.0.0.1/health |
    grep -Fq "\"version\":\"${EXPECTED}\"" ||
    fail 'Rollback proxy health verification failed.'

  log "[MONITOR OK] ROLLBACK CONFIRMED active=$PREVIOUS version=$EXPECTED"
  log "[MONITOR OK] Recovery completed automatically."
  exit 0
done

log "[MONITOR OK] Monitoring completed; active=$ACTIVE remained healthy."
