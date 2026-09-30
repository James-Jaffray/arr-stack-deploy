# arr-stack-deploy

A small, private Docker Compose project that sets up a media-automation stack behind a VPN kill switch. Everything is driven by one `.env` file, so on a new machine you copy the repo, fill in `.env`, run one setup script and start it.

Target: **Synology NAS, DSM 7.2+ with Container Manager** (Intel/AMD or ARM). It is developed on a Windows laptop with Docker Desktop first, see [Testing on Windows](#testing-on-windows-docker-desktop). Jellyfin is assumed to exist already and is not part of this repo.

## 1. What this is

| Service | Purpose | Web UI (host port, configurable) |
| --- | --- | --- |
| gluetun | VPN client and kill switch | none |
| qbittorrent | Torrent client, runs *inside* gluetun's network | 8080 (published by gluetun) |
| prowlarr | Indexer manager | 9696 |
| sonarr | TV automation | 8989 |
| radarr | Movie automation | 7878 |
| cloudflared | Optional Cloudflare Tunnel (`tunnel` profile) | none |

Host ports change through `.env`; container ports never do (Sonarr and Radarr reach qBittorrent internally at `gluetun:8080`).

qBittorrent, Sonarr and Radarr all mount the same `DATA_DIR` at `/data`, so finished downloads are **hardlinked** into the library instead of copied.

## 2. Quick start

1. Get the repo onto the machine (git clone, or copy the folder **without** `.env` and `config/`; step-by-step for a Synology in [`instructions/00-initial-setup.md`](instructions/00-initial-setup.md)).
2. `cp .env.example .env`
3. Edit `.env`: every `CHANGE_ME` must be replaced (VPN details, paths, user IDs, home subnet). The [`instructions/`](instructions/README.md) folder explains, section by section, where to find each value.
4. `sh setup.sh --check` (changes nothing, lists every problem at once).
5. `sh setup.sh` (creates folders, fixes ownership).
6. `docker compose up -d`
7. `sh scripts/verify.sh` (containers, VPN health, IP differs, web UIs answer).
8. Optional: `sh scripts/verify.sh --killswitch`.
9. Do the [first-run wiring](#4-first-run-wiring) (step by step in [`instructions/04-connecting-the-apps.md`](instructions/04-connecting-the-apps.md)).
10. Back up `.env` and `CONFIG_DIR` somewhere safe.

`./setup.sh` works if the executable bit survived; if not, `sh setup.sh` always works. `sh setup.sh --up` does steps 5 and 6 together.

### Testing on Windows (Docker Desktop)

- **Best:** clone the repo inside the WSL2 Ubuntu filesystem (`~/arr-stack-deploy`, not `/mnt/c/...`) with Docker Desktop's WSL integration on. That gives Linux permissions, real hardlinks and fast mounts, closest to the Synology.
- **Fallback:** if the repo lives on a Windows drive (as it does when developed under `F:\`), `docker compose` works but bind mounts are slower, `chown` does nothing and hardlinks may not behave like on the NAS. A failed hardlink test there is **not** a bug; `setup.sh` warns about it.
- Run scripts through WSL (`wsl -e sh ./setup.sh --check`) or Git Bash. The scripts set `MSYS_NO_PATHCONV=1` for you.
- Use relative paths in the test `.env`:
  ```text
  CONFIG_DIR=./config
  DATA_DIR=./data
  ```
  `LAN_SUBNET` still needs a valid value, but LAN reachability cannot be proven from the laptop. Use `http://localhost:<port>`.
- If **WireGuard fails on Docker Desktop** but your credentials are right, that is a test-environment limitation. Try `VPN_TYPE=openvpn` (plus `OPENVPN_USER` / `OPENVPN_PASSWORD`) for the laptop test only.
- **Moving to the NAS:** copy the repo *without* `.env` and `config/` (and `data/`), then create the client's own `.env` there. Never copy the laptop's `.env`: it holds your VPN key.

## 3. Synology install

1. DSM 7.2+: install **Container Manager** from Package Center.
2. Control Panel > User: create a dedicated user (e.g. `arr`). Enable SSH temporarily, log in and run `id arr` to get the numeric **PUID** (uid) and **PGID** (gid).
3. Control Panel > Shared Folder: create `docker` and `data` on the **same volume**. Give the `arr` user read/write.
4. Path mapping:

   | `.env` variable | Value |
   | --- | --- |
   | `CONFIG_DIR` | `/volume1/docker/arr-stack/config` |
   | `DATA_DIR` | `/volume1/data` |
   | `PUID` / `PGID` | from `id arr` |

   If Jellyfin's library is elsewhere, put `media/` in `DATA_DIR` and point Jellyfin at it, or move the library there first (hardlinks need one filesystem).
5. **tun device:** Control Panel > Task Scheduler > Create > Triggered Task > User-defined script, event *Boot-up*, user *root*, paste `scripts/synology-tun-boot.sh`. Run it once now. The `tun.ko` path can differ by model (`find / -name tun.ko 2>/dev/null`).
6. Copy the repo to `/volume1/docker/arr-stack/`, create `.env`, then over SSH: `sudo sh setup.sh --check`, `sudo sh setup.sh`.
7. Start it either way:
   - **Container Manager UI:** Project > Create > path `/volume1/docker/arr-stack`, use the existing `docker-compose.yml`. (No `sudo` needed; the UI runs as admin.)
   - **SSH:** `sudo docker compose up -d` (Synology's docker socket normally needs `sudo`).

## 4. First-run wiring

The full step-by-step version is in [`instructions/04-connecting-the-apps.md`](instructions/04-connecting-the-apps.md); this is the summary.

Manual, done once. Container-internal names and paths are the same on every install.

**qBittorrent** (`http://<host>:8080`)
- Temporary password: `docker logs qbittorrent` (look for the generated one). Log in, then Tools > Options > Web UI and set a new one.
- Downloads: default save path `/data/torrents`; Default Torrent Management Mode: **Automatic**.
- Categories: `tv` → `/data/torrents/tv`, `movies` → `/data/torrents/movies`.
- Advanced: network interface `tun0` (OpenVPN) or `wg0` (WireGuard).

**Sonarr / Radarr**
- Settings > General: enable authentication.
- Media Management > Root Folders: Sonarr `/data/media/tv`, Radarr `/data/media/movies`. Tick *Use Hardlinks instead of Copy*.
- Settings > Download Clients > add qBittorrent: **Host `gluetun`**, **Port `8080`** (not `qbittorrent`: it has no network of its own), category `tv` / `movies`.

**Prowlarr**
- Enable authentication; add your indexers.
- Settings > Apps: add Sonarr (`http://sonarr:8989`) and Radarr (`http://radarr:7878`), Prowlarr server `http://prowlarr:9696`, plus each app's API key (Settings > General). Then *Sync App Indexers*.

**Optional:** Settings > Connect in Sonarr and Radarr, add Jellyfin, so libraries refresh after imports.

## 5. Speeding up repeat installs

On a working build, export backups from Sonarr, Radarr and Prowlarr (Settings > System > Backup) and restore them on the new machine. Hostnames and container paths are identical, so they restore cleanly. Re-enter secrets afterwards: indexer logins, the qBittorrent password and API keys.

## 6. Optional Cloudflare Tunnel

1. Cloudflare Zero Trust > Networks > Tunnels > create a tunnel, copy its token.
2. Put `CLOUDFLARE_TUNNEL_TOKEN=...` in `.env`.
3. `docker compose --profile tunnel up -d`
4. In the tunnel, add public hostnames targeting `http://sonarr:8989`, `http://radarr:7878`, `http://prowlarr:9696`, `http://gluetun:8080` (qBittorrent: use `gluetun`, never `qbittorrent`) and, for Jellyfin, `http://<nas-ip>:8096`.
5. There is no Cloudflare Access here: each app is protected only by its own login. Turn those logins on (long unique passwords) **before** adding the hostnames.
6. Follow the full walkthrough in [`instructions/05-cloudflare-tunnel.md`](instructions/05-cloudflare-tunnel.md).

## 7. Updating

```sh
docker compose pull && docker compose up -d
docker restart qbittorrent   # needed if gluetun was recreated
```
Back up `CONFIG_DIR` and `.env` regularly. Images use `:latest`; once the client's setup is stable you can pin tags in `docker-compose.yml`.

## 8. Troubleshooting

| Problem | Likely cause / fix |
| --- | --- |
| gluetun never healthy | `docker logs gluetun`. Wrong Privado username or password (`AUTH_FAILED` in the log; use the username, not the email), or wrong provider name; missing tun device (Synology boot task); on Docker Desktop try `VPN_TYPE=openvpn`. |
| qBittorrent UI unreachable from LAN | `LAN_SUBNET` wrong (must match your home network), or `BIND_ADDR=127.0.0.1`. |
| qBittorrent dead after gluetun recreated | `docker restart qbittorrent` (it is attached to the old network). |
| Connection refused from Sonarr/Radarr | Download client host must be `gluetun`, port `8080`. |
| Imports copy instead of hardlink | `DATA_DIR/torrents` and `media` on different filesystems, or downloads not under `/data/...`; run `setup.sh`. |
| Permission denied on import | `PUID`/`PGID` don't own the folders: `sudo chown -R PUID:PGID` on `CONFIG_DIR` and `DATA_DIR`. |
| Remote path errors | Category save paths must be `/data/torrents/...` exactly. |
| Indexer blocked by Cloudflare | Needs FlareSolverr; not included (possible follow-up). |
| Empty optional VPN variable rejected | The Gluetun docs don't say how empty values are treated; if your version complains, remove that line from the `gluetun` environment in `docker-compose.yml`. |

## 9. Handover checklist

Before the visit
- [ ] DSM version (7.2+) and CPU model
- [ ] VPN account: the client's own Privado username and password (not their email), or details for another provider
- [ ] Where the media lives; free space
- [ ] Home subnet (router LAN settings)
- [ ] Indexer logins

At the NAS
- [ ] tun device works (boot task in place)
- [ ] Dedicated user created; PUID/PGID noted
- [ ] Folders created (`setup.sh`)
- [ ] `.env` filled with the client's values (not the author's)
- [ ] All containers healthy
- [ ] VPN test passes (`verify.sh`)
- [ ] Kill switch tested (`verify.sh --killswitch`)
- [ ] Sonarr, Radarr, Prowlarr, qBittorrent linked
- [ ] One test import visible in Jellyfin
- [ ] SSH turned back off
- [ ] Config backup taken

## Possible follow-ups (not included)

Jellyfin (already installed), FlareSolverr, Watchtower.
