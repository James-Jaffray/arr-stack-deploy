# Runbook: day-to-day operation

Quick reference for running the stack once it's set up. On the Synology every `docker` or script command needs `sudo`.

## Get to the commands

```sh
ssh yourAdminName@<nas-ip>
cd /volume1/docker/arr-stack
```

(SSH must be on in DSM: Control Panel > Terminal & SNMP. Details in [`00-initial-setup.md`](00-initial-setup.md#2-how-to-ssh-into-the-nas).) Turn it off again when finished.

## Common tasks

| I want to... | Run |
| --- | --- |
| Start everything | `sudo sh scripts/deploy.sh` |
| Update to newer versions | `sudo sh scripts/deploy.sh --pull` |
| Restart everything | `sudo sh scripts/restart.sh` |
| Restart one app | `sudo sh scripts/restart.sh sonarr` (names: `gluetun`, `qbittorrent`, `prowlarr`, `sonarr`, `radarr`, `cloudflared`) |
| Remove the containers (settings and data stay) | `sudo sh scripts/drop.sh` |
| Check everything is healthy | `sudo sh scripts/verify.sh` |
| Prove the kill switch works | `sudo sh scripts/verify.sh --killswitch` |
| Validate `.env` without changing anything | `sudo sh setup.sh --check` |
| See what's running | `sudo docker compose ps` |
| Read an app's log | `sudo docker logs --tail 50 gluetun` (swap the name) |
| Stop remote access only | `sudo docker compose --profile tunnel stop cloudflared` |

Restarting `gluetun` always restarts qBittorrent after it; the script does this for you. If you restart gluetun by hand, run `sudo docker restart qbittorrent` afterwards.

## Web addresses

Replace `<nas-ip>` with the NAS's IP.

| App | Address |
| --- | --- |
| qBittorrent | `http://<nas-ip>:8080` |
| Prowlarr | `http://<nas-ip>:9696` |
| Sonarr | `http://<nas-ip>:8989` |
| Radarr | `http://<nas-ip>:7878` |

Ports come from `.env` (`QBIT_PORT` and so on); if you changed them, use those.

## Where things live

| What | Where |
| --- | --- |
| This project | `/volume1/docker/arr-stack` |
| Settings `.env` (secrets) | `/volume1/docker/arr-stack/.env` |
| App settings | `/volume1/docker/arr-stack/config/` (one folder per app) |
| Downloads and library | `/volume1/data/torrents` and `/volume1/data/media` |

`drop.sh` and updates never touch `config/`, `.env` or `data/`.

## Quick diagnosis

| Symptom | First thing to try |
| --- | --- |
| Nothing downloads | `sudo sh scripts/verify.sh`. If gluetun isn't healthy: `sudo docker logs --tail 50 gluetun`. |
| `AUTH_FAILED` in gluetun's log | The Privado username or password in `.env` is wrong (use the username, not the email), or the plan isn't paid. |
| qBittorrent unreachable after a VPN restart | `sudo docker restart qbittorrent`. |
| Sonarr or Radarr say they can't reach qBittorrent | The download client host must be `gluetun`, port `8080`. |
| An app won't start after an update | `sudo docker logs --tail 50 <name>`, then `sudo sh scripts/deploy.sh` again. |
| Permission denied on imports | Check `PUID` and `PGID` in `.env` match `id arr`, then `sudo sh setup.sh`. |

More in the Troubleshooting table of the main [README](../README.md).

## Backups

Copy these somewhere safe on a schedule, and before any update:

- `/volume1/docker/arr-stack/config/`
- `/volume1/docker/arr-stack/.env` (contains your VPN login; keep the backup private)

Sonarr, Radarr and Prowlarr can also export their own backups (Settings > System > Backup). Your media in `/volume1/data` is your normal Synology backup's job.
