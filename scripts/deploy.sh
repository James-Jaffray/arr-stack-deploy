#!/bin/sh
# Validate, create folders, then start (or update) the whole stack.
#
#   sh scripts/deploy.sh            validate, then `docker compose up -d`
#   sh scripts/deploy.sh --pull     also download newer images first (an update)
#   sh scripts/deploy.sh --skip-setup   skip the setup.sh checks
#
# On Synology: sudo sh scripts/deploy.sh
set -eu
# shellcheck source=_common.sh
. "$(dirname "$0")/_common.sh"

PULL=0
SETUP=1
for arg in "$@"; do
  case $arg in
    --pull) PULL=1 ;;
    --skip-setup) SETUP=0 ;;
    -h | --help) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "Unknown option: $arg (try --help)" ;;
  esac
done

require_docker
enable_tunnel_if_configured

if [ "$SETUP" = 1 ]; then
  say "== Checking .env and creating folders =="
  sh ./setup.sh || die "setup.sh reported problems; fix them and run again."
fi

if [ "$PULL" = 1 ]; then
  say "== Pulling newer images =="
  docker compose pull
fi

say "== Starting the stack =="
[ "$TUNNEL_ON" = 1 ] && say "(Cloudflare tunnel token found in .env: including cloudflared)"
docker compose up -d

if wait_gluetun_healthy; then
  ok "gluetun is healthy"
else
  warn "gluetun is not healthy yet. Check:  docker logs gluetun"
fi

say
docker compose ps
say
say "Next: sh scripts/verify.sh"
