# 1. Host / user

Variables: `PUID`, `PGID`, `TZ`, `CONFIG_DIR`, `DATA_DIR`, `LAN_SUBNET`

Everything here is for the Synology NAS (DSM 7.2+). Do the DSM steps first; the values come out of them.

## Before you start: DSM setup

1. Package Center: install **Container Manager**.
2. Control Panel > User & Group: create a dedicated user (for example `arr`).
3. Control Panel > Shared Folder: create two shared folders, **`docker`** and **`data`**, on the **same volume**. Give the `arr` user read/write on both.
4. Turn SSH on temporarily (see [How to SSH into the NAS](#how-to-ssh-into-the-nas) below). Turn it off again when you're finished.

## How to SSH into the NAS

SSH lets you type commands on the NAS from another computer. You need it here to run `id`, and later to run `setup.sh`.

**Turn it on (in DSM, in your browser)**
1. Control Panel > Terminal & SNMP > **Terminal** tab.
2. Tick **Enable SSH service**. Leave the port at `22` and click **Apply**.

**Find the NAS's IP address**
- DSM: Control Panel > Network > Network Interface, select your connection, and read the IP address (for example `192.168.1.20`). This is also the address you use in the browser for DSM.
- Or open <https://find.synology.com> from a computer on the same network.

**Connect from a computer on the same network**
1. On Windows open **Terminal** or **PowerShell**. (On Mac or Linux open Terminal.) Windows 10 and 11 already include `ssh`.
2. Run the command below, using your **DSM administrator account** name and the NAS IP:

   ```sh
   ssh yourAdminName@192.168.1.20
   ```

   On DSM 7 only accounts in the **administrators** group can use SSH, so the new `arr` user can't log in this way. That's fine: you log in as your admin account and use it to look up `arr`'s IDs.
3. The first time, it says it can't verify the host and asks "Are you sure you want to continue connecting?". Type `yes` and press Enter.
4. Enter your DSM password. **Nothing appears as you type**; that's normal. Press Enter.
5. When you see a prompt such as `yourAdminName@NASName:~$`, you're in. Type commands there.
6. Commands that start with `sudo` ask for your password again. Type it (again nothing shows) and press Enter.
7. Type `exit` to disconnect.

**If it doesn't connect:** check the IP, check you're on the same network as the NAS, and check SSH is ticked and applied. "Connection refused" usually means SSH is still off.

**When finished:** turn **Enable SSH service** off again in the same DSM screen.

## `PUID` and `PGID`

The numeric user and group IDs the apps run as. They decide who owns the files the apps create.

1. [SSH into the NAS](#how-to-ssh-into-the-nas) and run `id arr` (use your dedicated user's name). It works even though you're logged in as your admin account.
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

Copy the repo to `/volume1/docker/arr-stack`, create `.env`, then [SSH in](#how-to-ssh-into-the-nas) and run:

```sh
sudo sh setup.sh --check
```

It flags a non-numeric `PUID`/`PGID` and a `LAN_SUBNET` that isn't in `a.b.c.d/nn` form. Running it as `sudo` lets `setup.sh` fix folder ownership later.
