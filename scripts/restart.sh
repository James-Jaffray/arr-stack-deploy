#!/bin/sh
# Restart the stack, or just the services you name.
#
#   sh scripts/restart.sh                  restart everything
#   sh scripts/restart.sh sonarr radarr    restart only those
#
# qBittorrent shares gluetun's network, so whenever gluetun restarts, qBittorrent is
# restarted after it (otherwise it is left attached to the old, dead network).
#
# On Synology: sudo sh scripts/restart.sh
set -eu
# shellcheck source=_common.sh
. "$(dirname "$0")/_common.sh"

for arg in "$@"; do
  case $arg in
    -h | --help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) die "Unknown option: $arg (try --help)" ;;
  esac
done

require_docker
enable_tunnel_if_configured

known=$(docker compose config --services)
if [ "$#" -eq 0 ]; then
  targets=$known
else
  targets=$*
  for t in $targets; do
    printf '%s\n' "$known" | grep -qx "$t" || die "Unknown service '$t'. Available: $(printf '%s' "$known" | tr '\n' ' ')"
  done
fi

has() { printf '%s\n' "$targets" | tr ' ' '\n' | grep -qx "$1"; }

if has gluetun; then
  say "== Restarting gluetun =="
  docker compose restart gluetun
  wait_gluetun_healthy || warn "gluetun is not healthy yet. Check:  docker logs gluetun"
  # Restart qBittorrent after gluetun, then everything else that was asked for.
  say "== Restarting qBittorrent =="
  docker compose restart qbittorrent
  rest=$(printf '%s\n' "$targets" | tr ' ' '\n' | grep -vx -e gluetun -e qbittorrent || true)
else
  rest=$(printf '%s\n' "$targets" | tr ' ' '\n')
fi

if [ -n "$rest" ]; then
  say "== Restarting: $(printf '%s' "$rest" | tr '\n' ' ')=="
  # shellcheck disable=SC2086 # intentional: one argument per service name
  docker compose restart $rest
fi

say
docker compose ps
ok "Done."
