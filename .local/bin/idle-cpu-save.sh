#!/usr/bin/env bash
# Idle monitor helper for systemd --user
# Checks xprintidle and sets CPU governor via cpupower on state changes

set -euo pipefail

HOME_DIR=${HOME:-/home/$(whoami)}
CACHE_DIR="$HOME_DIR/.cache/idle-monitor"
STATE_FILE="$CACHE_DIR/state"
XPRINTIDLE_CMD=/usr/bin/xprintidle
CPUPOWER_CMD=/usr/bin/cpupower
SUDO_CMD=/usr/bin/sudo
IDLE_THRESHOLD_MS=${IDLE_THRESHOLD_MS:-120000}
ACTIVE_THRESHOLD_MS=${ACTIVE_THRESHOLD_MS:-20000}
GOV_IDLE=${GOV_IDLE:-powersave}
GOV_ACTIVE=${GOV_ACTIVE:-performance}
DEBUG=${DEBUG:-}

mkdir -p "$CACHE_DIR"

log() {
  echo "[$(basename "$0")] $*"
}

debug() {
  if [ -n "$DEBUG" ]; then
    log "$*"
  fi
}

if [ -n "$DEBUG" ]; then
  set -x
fi

if ! command -v "$XPRINTIDLE_CMD" >/dev/null 2>&1; then
  log "error: $XPRINTIDLE_CMD not found; exiting"
  exit 2
fi

debug "config: idle_threshold=${IDLE_THRESHOLD_MS}ms, active_threshold=${ACTIVE_THRESHOLD_MS}ms, idle_gov=${GOV_IDLE}, active_gov=${GOV_ACTIVE}"

idle_ms=$("$XPRINTIDLE_CMD" 2>/dev/null || true)

if ! [[ "$idle_ms" =~ ^[0-9]+$ ]]; then
  log "error: failed to read idle time (output: '$idle_ms')"
  exit 3
fi

old_state=unknown
if [ -f "$STATE_FILE" ]; then
  old_state=$(cat "$STATE_FILE") || true
fi

new_state=active
threshold=$IDLE_THRESHOLD_MS
if [ "$old_state" = "idle" ]; then
  threshold=$ACTIVE_THRESHOLD_MS
fi

if [ "$idle_ms" -ge "$threshold" ]; then
  new_state=idle
fi

if [ "$new_state" != "$old_state" ]; then
  log "state change: $old_state -> $new_state (idle_ms=${idle_ms}ms)"

  case "$new_state" in
    idle)
      gov=$GOV_IDLE
      ;;
    active|*)
      gov=$GOV_ACTIVE
      ;;
  esac

  log "setting cpu governor to: $gov"
  if $SUDO_CMD $CPUPOWER_CMD frequency-set -g $gov >/dev/null 2>&1; then
    log "successfully set governor to $gov"
  else
    log "error: failed to set governor to $gov"
  fi
  printf "%s" "$new_state" > "$STATE_FILE"
else
  log "no state change: $old_state (idle_ms=${idle_ms}ms)"
fi

exit 0
