#!/bin/sh
# Stop and REMOVE the containers (and the tunnel, if any).
# Your settings (CONFIG_DIR) and your downloads/media (DATA_DIR) are NOT deleted, so
# `deploy.sh` brings everything back exactly as it was.
#
#   sh scripts/drop.sh         asks for confirmation
#   sh scripts/drop.sh --yes   no question asked
#
# On Synology: sudo sh scripts/drop.sh
set -eu
# shellcheck source=_common.sh
. "$(dirname "$0")/_common.sh"

YES=0
for arg in "$@"; do
  case $arg in
    --yes | -y) YES=1 ;;
    -h | --help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "Unknown option: $arg (try --help)" ;;
  esac
done

require_docker

if [ "$YES" = 0 ]; then
  say "This stops and removes the arr-stack containers (VPN, qBittorrent, Sonarr, Radarr,"
  say "Prowlarr and the tunnel). Your settings and your downloads/media are kept."
  printf 'Continue? [y/N] '
  read -r answer || answer=n
  case $answer in y | Y | yes) ;; *) say "Cancelled."; exit 0 ;; esac
fi

# Always include the tunnel profile so cloudflared is removed too.
COMPOSE_PROFILES=tunnel
export COMPOSE_PROFILES
docker compose down --remove-orphans
ok "Containers removed. Settings and data are untouched. Bring it back with:  sh scripts/deploy.sh"
