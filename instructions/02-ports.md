# 2. Ports

Variables: `BIND_ADDR`, `QBIT_PORT`, `PROWLARR_PORT`, `SONARR_PORT`, `RADARR_PORT`

These only change the **host side** (the number you type in the browser). The ports inside the containers never change, so apps keep finding each other.

## `BIND_ADDR`

Which network address the web pages listen on.

| Value | Meaning |
| --- | --- |
| `0.0.0.0` | Reachable from every device on your home network (normal choice). |
| `127.0.0.1` | Reachable only from the machine running Docker. Use it if you'll reach the apps only through the Cloudflare Tunnel, which talks to them container to container. |

Leave it at `0.0.0.0` unless you have a reason.

## The four port variables

| Variable | Default | App |
| --- | --- | --- |
| `QBIT_PORT` | `8080` | qBittorrent |
| `PROWLARR_PORT` | `9696` | Prowlarr |
| `SONARR_PORT` | `8989` | Sonarr |
| `RADARR_PORT` | `7878` | Radarr |

Leave the defaults unless something else already uses a port. To find out:

- **Windows (laptop test):** in PowerShell run `netstat -ano | findstr :8080` (change the number). No output means it is free.
- **Synology:** `setup.sh` checks for you, and warns if a port is taken. DSM itself uses 5000/5001, and Jellyfin usually uses 8096, so the defaults normally don't clash. `8080` is the one most often taken by other packages.

If you change a port, pick any unused number from 1024 to 65535, and use it in the browser too (for example `http://<nas-ip>:8081`).

## Check it

`sh setup.sh --check` validates that each port is a number from 1 to 65535 and warns if it is already in use. It will also warn if the stack itself is already running, which is expected.
