#!/bin/sh
# Run after `docker compose up -d`. PASS/FAIL per check, non-zero exit on any FAIL.
#
#   sh scripts/verify.sh               normal checks
#   sh scripts/verify.sh --killswitch  also stop the VPN and prove qBittorrent goes offline
#
# On Synology you may need `sudo sh scripts/verify.sh` for docker access.
set -eu

# Git Bash rewrites Linux-looking arguments (e.g. /data) into Windows paths.
MSYS_NO_PATHCONV=1
export MSYS_NO_PATHCONV

cd "$(dirname "$0")/.."

KILLSWITCH=0
for arg in "$@"; do
  case $arg in
    --killswitch) KILLSWITCH=1 ;;
    -h | --help) echo "Usage: sh scripts/verify.sh [--killswitch]"; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C_RED=$(printf '\033[31m'); C_GREEN=$(printf '\033[32m'); C_YELLOW=$(printf '\033[33m'); C_OFF=$(printf '\033[0m')
else
  C_RED=; C_GREEN=; C_YELLOW=; C_OFF=
fi
FAILS=0
pass() { printf '%sPASS%s %s\n' "$C_GREEN" "$C_OFF" "$*"; }
bad()  { FAILS=$((FAILS + 1)); printf '%sFAIL%s %s\n' "$C_RED" "$C_OFF" "$*"; }
note() { printf '%sNOTE%s %s\n' "$C_YELLOW" "$C_OFF" "$*"; }

# Read KEY from .env (tolerates CRLF, quotes and inline comments); print default if absent.
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

# Fetch a URL body from the host or (with a container name) from inside a container.
fetch_host() {
  if command -v curl >/dev/null 2>&1; then curl -s --max-time 10 "$1"
  elif command -v wget >/dev/null 2>&1; then wget -qO- -T 10 "$1"
  else return 1; fi
}
fetch_in() {
  docker exec "$1" curl -s --max-time 10 "$2" 2>/dev/null ||
    docker exec "$1" wget -qO- -T 10 "$2" 2>/dev/null
}
http_code() {
  if command -v curl >/dev/null 2>&1; then
    curl -s -o /dev/null -w '%{http_code}' --max-time 8 "$1" || true
  elif command -v wget >/dev/null 2>&1; then
    wget -S --spider -T 8 "$1" 2>&1 | sed -n 's/^ *HTTP\/[0-9.]* \([0-9]*\).*/\1/p' | tail -n 1
  fi
}
looks_like_ip() { case $1 in '' | *[!0-9a-fA-F.:]*) return 1 ;; *) return 0 ;; esac; }

# ---- docker access ----
if ! command -v docker >/dev/null 2>&1; then echo "docker not found" >&2; exit 2; fi
if ! dinfo=$(docker info 2>&1 >/dev/null); then
  case $dinfo in
    *ermission*) echo "Permission denied talking to Docker. Re-run with sudo:  sudo sh scripts/verify.sh" >&2 ;;
    *) echo "Cannot talk to the Docker daemon: $dinfo" >&2 ;;
  esac
  exit 2
fi

echo "== Containers =="
running=$(docker compose ps --status running --services 2>/dev/null || true)
for svc in gluetun qbittorrent prowlarr sonarr radarr; do
  if printf '%s\n' "$running" | grep -qx "$svc"; then pass "$svc is running"; else bad "$svc is not running"; fi
done
if docker ps -a --format '{{.Names}}' | grep -qx cloudflared; then
  if docker ps --format '{{.Names}}' | grep -qx cloudflared; then pass "cloudflared is running"; else bad "cloudflared exists but is not running"; fi
fi

echo "== VPN =="
health=$(docker inspect -f '{{.State.Health.Status}}' gluetun 2>/dev/null || echo missing)
if [ "$health" = healthy ]; then pass "gluetun is healthy"; else bad "gluetun health is '$health' (see: docker logs gluetun)"; fi

host_ip=$(fetch_host https://ifconfig.me 2>/dev/null || true)
qbit_ip=$(fetch_in qbittorrent https://ifconfig.me || true)
echo "     host IP:        ${host_ip:-unknown}"
echo "     qBittorrent IP: ${qbit_ip:-unknown}"
if ! looks_like_ip "$host_ip"; then
  bad "could not read the host's public IP (no curl/wget, or no internet)"
elif ! looks_like_ip "$qbit_ip"; then
  bad "could not read qBittorrent's public IP (VPN down?)"
elif [ "$host_ip" = "$qbit_ip" ]; then
  bad "qBittorrent has the SAME public IP as the host: the VPN is not protecting it"
else
  pass "qBittorrent's public IP differs from the host's"
fi

echo "== Web UIs =="
bind=$(envget BIND_ADDR 0.0.0.0)
[ "$bind" = 0.0.0.0 ] && bind=127.0.0.1
if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
  note "neither curl nor wget on the host; skipping web UI checks"
else
  for entry in "qBittorrent:QBIT_PORT:8080" "Prowlarr:PROWLARR_PORT:9696" "Sonarr:SONARR_PORT:8989" "Radarr:RADARR_PORT:7878"; do
    name=${entry%%:*}; rest=${entry#*:}; key=${rest%%:*}; def=${rest#*:}
    port=$(envget "$key" "$def")
    code=$(http_code "http://$bind:$port")
    case $code in
      2?? | 3?? | 401) pass "$name answers on port $port (HTTP $code)" ;;
      *) bad "$name did not answer on port $port (got '${code:-nothing}')" ;;
    esac
  done
fi

if [ "$KILLSWITCH" = 1 ]; then
  echo "== Kill switch =="
  printf 'This stops gluetun and briefly takes qBittorrent offline. Continue? [y/N] '
  read -r answer || answer=n
  case $answer in
    y | Y | yes)
      docker compose stop gluetun >/dev/null
      sleep 3
      leak=$(fetch_in qbittorrent https://ifconfig.me || true)
      if looks_like_ip "$leak"; then bad "qBittorrent still reached the internet with the VPN stopped ($leak)"
      else pass "qBittorrent has no internet while the VPN is stopped"; fi
      docker compose start gluetun >/dev/null
      n=0
      until [ "$(docker inspect -f '{{.State.Health.Status}}' gluetun 2>/dev/null)" = healthy ] || [ "$n" -ge 40 ]; do
        sleep 3; n=$((n + 1))
      done
      docker restart qbittorrent >/dev/null
      note "gluetun restarted and qBittorrent restarted (it must be restarted after gluetun is recreated)" ;;
    *) note "kill switch test skipped" ;;
  esac
fi

echo
if [ "$FAILS" -eq 0 ]; then printf '%sAll checks passed.%s\n' "$C_GREEN" "$C_OFF"; else printf '%s%s check(s) failed.%s\n' "$C_RED" "$FAILS" "$C_OFF"; exit 1; fi
