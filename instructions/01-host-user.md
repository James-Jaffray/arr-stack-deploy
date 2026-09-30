# 1. Host / user

Variables: `PUID`, `PGID`, `TZ`, `CONFIG_DIR`, `DATA_DIR`, `LAN_SUBNET`

Fill these in first. The values differ between the **Windows laptop test** and the **Synology**; both are given.

## `PUID` and `PGID`

The numeric user and group IDs the apps run as. They decide who owns the files the apps create.

- **Windows laptop test:** leave both at `1000`. Files on a Windows drive have no Linux owners, so the numbers don't matter there.
- **Synology:**
  1. Control Panel > User & Group: create a dedicated user (for example `arr`).
  2. Control Panel > Terminal & SNMP: turn SSH on temporarily.
  3. SSH in and run `id arr`.
  4. Output looks like `uid=1026(arr) gid=100(users)`. The first number is `PUID`, the second is `PGID`.
  5. Turn SSH back off afterwards.

## `TZ`

Your timezone as a name from the standard list, such as `America/Edmonton` or `America/Toronto`. It is not a Windows-style name. Find yours at <https://en.wikipedia.org/wiki/List_of_tz_database_time_zones> (use the "TZ identifier" column). The example default is Alberta, so change it if you're elsewhere.

## `CONFIG_DIR`

The folder where each app keeps its settings.

- **Laptop test:** leave as `./config`. It is created inside the repo folder.
- **Synology:** `/volume1/docker/arr-stack/config`.

## `DATA_DIR`

The single root folder that will hold `torrents/` and `media/`. Keeping both under one root on one volume is what lets finished downloads be hardlinked instead of copied.

- **Laptop test:** comment out the `/volume1/data` line and uncomment `DATA_DIR=./data`.
- **Synology:** `/volume1/data` (the shared folder named `data`, on the same volume as your `docker` folder).

## `LAN_SUBNET`

Your home network written as a range. It lets your other devices reach qBittorrent's web page through the VPN firewall.

1. In PowerShell run `ipconfig`.
2. Under your active adapter (Wi-Fi or Ethernet), find `IPv4 Address`, for example `192.168.1.57`.
3. Find the `Subnet Mask`, for example `255.255.255.0`.
4. Keep the first three numbers of the address, end with `.0`, then add a slash and the mask length:

   | Subnet mask | Suffix |
   | --- | --- |
   | `255.255.255.0` | `/24` |
   | `255.255.254.0` | `/23` |
   | `255.255.0.0` | `/16` |

   Almost all home networks are `/24`, so the example gives `192.168.1.0/24`.
5. On the Synology use the network the NAS is on. It is normally the same as your laptop's.

## Check it

```sh
sh setup.sh --check
```

It flags a non-numeric `PUID`/`PGID` and a `LAN_SUBNET` that isn't in `a.b.c.d/nn` form.
