# 1. Host / user

Variables: `PUID`, `PGID`, `TZ`, `CONFIG_DIR`, `DATA_DIR`, `LAN_SUBNET`

Everything here is for the Synology NAS (DSM 7.2+).

Complete [`00-initial-setup.md`](00-initial-setup.md) first: it creates the `arr` user and the `docker` and `data` shared folders, and shows how to SSH into the NAS, all of which the values below depend on.

## `PUID` and `PGID`

The numeric user and group IDs the apps run as. They decide who owns the files the apps create.

1. [SSH into the NAS](00-initial-setup.md#2-how-to-ssh-into-the-nas) and run `id arr` (use your dedicated user's name). It works even though you're logged in as your admin account.
2. Output looks like `uid=1026(arr) gid=1000(users)`. The first number is `PUID`, the second is `PGID`.

Don't leave the placeholder `1000` unless `id` really says so; wrong IDs cause "permission denied" when importing.

## `TZ`

Your timezone as a name from the standard list, such as `America/Edmonton` or `America/Toronto`. Find yours at <https://en.wikipedia.org/wiki/List_of_tz_database_time_zones> (use the "TZ identifier" column). DSM shows what it is set to in Control Panel > Regional Options. The example default is Alberta, so change it if you're elsewhere.

## `CONFIG_DIR`

The folder where each app keeps its settings. Put the repo in the `docker` shared folder, at `/volume1/docker/arr-stack`, and use:

```text
CONFIG_DIR=/volume1/docker/arr-stack/config
```

If your shared folders are on another volume, `volume1` changes to `volume2` and so on. To confirm the real path: File Station, right-click the `docker` folder > Properties, and read "Location".

## `DATA_DIR`

The single root folder that will hold `torrents/` and `media/`. Keeping both under one root on one volume is what lets finished downloads be hardlinked instead of copied. Use the `data` shared folder's path:

```text
DATA_DIR=/volume1/data
```

If your existing Jellyfin library lives somewhere else, either move it into `data/media/` first or put the library there; hardlinks only work inside one volume.

## `LAN_SUBNET`

Your home network written as a range. It lets your other devices reach qBittorrent's web page through the VPN firewall.

1. DSM: Control Panel > Network > Network Interface. Select your active connection (LAN 1) and open Edit / read its details.
2. Find the NAS's **IP address**, for example `192.168.1.20`, and its **subnet mask**, for example `255.255.255.0`.
3. Keep the first three numbers of the address, end with `.0`, then add a slash and the mask length:

   | Subnet mask | Suffix |
   | --- | --- |
   | `255.255.255.0` | `/24` |
   | `255.255.254.0` | `/23` |
   | `255.255.0.0` | `/16` |

   Almost all home networks are `/24`, so the example gives `192.168.1.0/24`.

## Check it

Copy the repo to `/volume1/docker/arr-stack`, create `.env`, then [SSH in](00-initial-setup.md#2-how-to-ssh-into-the-nas) and run:

```sh
sudo sh setup.sh --check
```

It flags a non-numeric `PUID`/`PGID` and a `LAN_SUBNET` that isn't in `a.b.c.d/nn` form. Running it as `sudo` lets `setup.sh` fix folder ownership later.
