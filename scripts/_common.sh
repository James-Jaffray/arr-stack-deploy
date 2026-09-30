#!/bin/sh
# Shared helpers for deploy.sh, drop.sh and restart.sh. Sourced, not run directly.
# Expects the caller to have run `set -eu`.

# Git Bash rewrites Linux-looking arguments (e.g. /data) into Windows paths.
MSYS_NO_PATHCONV=1
export MSYS_NO_PATHCONV

cd "$(dirname "$0")/.." || exit 1

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C_RED=$(printf '\033[31m'); C_GREEN=$(printf '\033[32m'); C_YELLOW=$(printf '\033[33m'); C_OFF=$(printf '\033[0m')
else
  C_RED=; C_GREEN=; C_YELLOW=; C_OFF=
fi
say()  { printf '%s\n' "$*"; }
ok()   { printf '%s[ ok ]%s %s\n' "$C_GREEN" "$C_OFF" "$*"; }
warn() { printf '%s[warn]%s %s\n' "$C_YELLOW" "$C_OFF" "$*"; }
die()  { printf '%s[FAIL]%s %s\n' "$C_RED" "$C_OFF" "$*" >&2; exit 1; }

# Read KEY from .env (tolerates CRLF, quotes, inline comments); print default if absent.
envget() {
  v=$(sed -n "s/^[[:space:]]*$1=//p" .env 2>/dev/null | tail -n 1 | tr -d '\r')
  case $v in
    '"'*) v=${v#\"}; v=${v%%\"*} ;;
    "'"*) v=${v#\'}; v=${v%%\'*} ;;
    '#'*) v= ;;
    *) v=${v%%[[:space:]]#*}; v=${v%"${v##*[![:space:]]}"} ;;
  esac
  printf '%s' "${v:-$2}"
}

# Fail early, with a sudo hint on Synology, if Docker can't be used.
require_docker() {
  command -v docker >/dev/null 2>&1 || die "docker not found."
  if ! dinfo=$(docker info 2>&1 >/dev/null); then
    case $dinfo in
      *ermission*) die "Permission denied talking to Docker. Re-run with sudo:  sudo sh $0" ;;
      *) die "Cannot talk to the Docker daemon: $dinfo" ;;
    esac
  fi
  [ -f .env ] || die ".env not found. Copy .env.example to .env and fill it in first."
}

# Turn the optional Cloudflare tunnel on when a token is present in .env.
# COMPOSE_PROFILES is read by every `docker compose` command below.
enable_tunnel_if_configured() {
  if [ -n "$(envget CLOUDFLARE_TUNNEL_TOKEN '')" ]; then
    COMPOSE_PROFILES=tunnel
    export COMPOSE_PROFILES
    TUNNEL_ON=1
  else
    TUNNEL_ON=0
  fi
  export TUNNEL_ON
}

# Wait until gluetun reports healthy (up to ~2 minutes). Returns non-zero on timeout.
wait_gluetun_healthy() {
  say "Waiting for gluetun to become healthy (up to 2 minutes)..."
  n=0
  while [ "$n" -lt 40 ]; do
    status=$(docker inspect -f '{{.State.Health.Status}}' gluetun 2>/dev/null || echo missing)
    [ "$status" = healthy ] && return 0
    sleep 3
    n=$((n + 1))
  done
  return 1
}
