# 2. Ports

Variables: `BIND_ADDR`, `QBIT_PORT`, `PROWLARR_PORT`, `SONARR_PORT`, `RADARR_PORT`

These only change the **host side** (the number you type in the browser). The ports inside the containers never change, so apps keep finding each other.

## `BIND_ADDR`

Which network address the web pages listen on.

| Value | Meaning |
| --- | --- |
| `0.0.0.0` | Reachable from every device on your home network (normal choice). |
| `127.0.0.1` | Reachable only from the machine running Docker. Use it if you'll reach the apps only through the Cloudflare Tunnel, which talks to them container to container. |

Leave it at `0.0.0.0`. On the Synology, `127.0.0.1` means the web pages can only be opened from the NAS itself, so you could not reach qBittorrent, Sonarr, Radarr or Prowlarr from your PC to do the first-run wiring in the main README. Only switch it once everything is set up and you really want the apps reachable through the tunnel alone.

## The four port variables

| Variable | Default | App |
| --- | --- | --- |
| `QBIT_PORT` | `8080` | qBittorrent |
| `PROWLARR_PORT` | `9696` | Prowlarr |
| `SONARR_PORT` | `8989` | Sonarr |
| `RADARR_PORT` | `7878` | Radarr |

Leave the defaults unless something else already uses a port. To find out:

- **Synology:** `setup.sh` checks for you and warns if a port is taken. To check by hand over SSH: `sudo netstat -tln | grep ':8080 '` (change the number); no output means it is free. DSM itself uses 5000/5001, and Jellyfin usually uses 8096, so the defaults normally don't clash. `8080` is the one most often taken by other packages.

If you change a port, pick any unused number from 1024 to 65535, and use it in the browser too (for example `http://<nas-ip>:8081`). Don't reuse `8096` (Jellyfin) or DSM's own `5000`/`5001`.

With the defaults, once the stack is running you'll open these from your PC, replacing `<nas-ip>` with the NAS's IP address:

| App | Address |
| --- | --- |
| qBittorrent | `http://<nas-ip>:8080` |
| Prowlarr | `http://<nas-ip>:9696` |
| Sonarr | `http://<nas-ip>:8989` |
| Radarr | `http://<nas-ip>:7878` |

**If you use the DSM firewall** (Control Panel > Security > Firewall) and the pages won't load from your PC, add an allow rule for these four ports from your home network. A port being free on the NAS doesn't mean the firewall lets you reach it.

## Check it

Once your `.env` is on the NAS, [SSH in](00-initial-setup.md#2-how-to-ssh-into-the-nas) and run:

```sh
cd /volume1/docker/arr-stack
sudo sh setup.sh --check
```

- It fails if a port isn't a number from 1 to 65535.
- It only **warns** if a port is already in use. If the stack is already running, that warning is expected.
- As in the previous guide, lines about the VPN values still being `CHANGE_ME` are expected until you finish guide `03`.
