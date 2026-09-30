# 4. Start the stack and connect the apps

This is the manual, one-time part. You start the containers, then link qBittorrent, Sonarr, Radarr and Prowlarr so a request flows all the way through:

```text
Prowlarr (finds releases)  ->  Sonarr / Radarr (decide what to get)  ->  qBittorrent (downloads, via the VPN)
                                          |
                                          +--> moves finished files into /data/media for Jellyfin
```

Do it from a computer on the home network. Menu names vary slightly between app versions. Everything here uses the **container-internal** addresses, which are identical on every install.

**Keep the API keys and passwords to yourself.** Each app's API key gives full control of it.

## 0. Start the stack

[SSH in](00-initial-setup.md#2-how-to-ssh-into-the-nas) and, with `.env` complete (guides `01` to `03`):

```sh
cd /volume1/docker/arr-stack
sudo sh setup.sh --check
sudo sh setup.sh
sudo docker compose up -d
sudo sh scripts/verify.sh
```

`verify.sh` should report every container running, gluetun healthy, and qBittorrent's public IP different from your home IP. Don't go further until it does; if gluetun isn't healthy, see `03-vpn-required.md`.

Then open each app from your PC, replacing `<nas-ip>` with the NAS's IP address:

| App | Address |
| --- | --- |
| qBittorrent | `http://<nas-ip>:8080` |
| Prowlarr | `http://<nas-ip>:9696` |
| Sonarr | `http://<nas-ip>:8989` |
| Radarr | `http://<nas-ip>:7878` |

## 1. qBittorrent

1. **Temporary password.** The username is `admin`. The password is random and printed in the container log:
   ```sh
   sudo docker logs qbittorrent 2>&1 | grep -i password
   ```
   Log in with it.
2. **New password.** Tools > Options > Web UI > Authentication: set a new password and click **Save**. Leave "Bypass authentication for clients on localhost" and the whitelist option **off**.
3. **Save location.** Tools > Options > Downloads:
   - Default Torrent Management Mode: **Automatic**.
   - Default Save Path: `/data/torrents`.
4. **Categories.** In the left panel, right-click **Categories > All**, choose **Add category**, and create two:

   | Category | Save path |
   | --- | --- |
   | `tv` | `/data/torrents/tv` |
   | `movies` | `/data/torrents/movies` |

5. **Network interface (extra kill switch).** Tools > Options > Advanced > **Network Interface**: choose `tun0` (Privado uses OpenVPN, which creates `tun0`). qBittorrent will then send nothing if the VPN interface is missing. If downloads never start, this is the first thing to check.

## 2. Sonarr and Radarr

Do the same steps in both. The differences are the port, the root folder and the category.

| | Sonarr | Radarr |
| --- | --- | --- |
| Address | `http://<nas-ip>:8989` | `http://<nas-ip>:7878` |
| Root folder | `/data/media/tv` | `/data/media/movies` |
| qBittorrent category | `tv` | `movies` |

1. **First-run login.** If the app asks you to set up authentication, choose a login form (for example **Forms**), set **Authentication Required** to **Enabled** (not "Disabled for Local Addresses"), and create a username and a strong password. Otherwise set this in Settings > General > Security.
2. **Root folder.** Settings > Media Management > **Add Root Folder**, and pick the path from the table.
3. **Hardlinks.** On the same page, click **Show Advanced** and make sure **Use Hardlinks instead of Copy** is ticked (it normally is). Save.
4. **Download client.** Settings > Download Clients > **+** > **qBittorrent**:

   | Field | Value |
   | --- | --- |
   | Name | `qBittorrent` |
   | Host | **`gluetun`** |
   | Port | `8080` |
   | Use SSL | off |
   | Username | `admin` |
   | Password | the new qBittorrent password |
   | Category | `tv` (Sonarr) or `movies` (Radarr) |

   Click **Test**, then **Save**. The host is `gluetun`, **not** `qbittorrent`: qBittorrent has no network of its own, it lives inside Gluetun's.
5. **API key.** Settings > General > Security > **API Key**. You'll need each app's key in the next section; copy it when you get there.

No remote path mapping is needed, because qBittorrent, Sonarr and Radarr all see the same `/data` folder.

## 3. Prowlarr

Open `http://<nas-ip>:9696`.

1. **First-run login.** Same as above: login form, authentication required, strong password.
2. **Add indexers.** Indexers > **Add Indexer**, search for one, click it, fill in the fields, **Test**, **Save**.
   - Choose indexers you have an account with or that are open to use, and only download content you have the right to.
   - Private indexers ask for details from your account on their site (an API key, passkey or login). Copy them from there.
   - Some indexers sit behind Cloudflare's bot check and fail the test. Those need FlareSolverr, which this project doesn't include.
3. **Connect Sonarr.** Settings > **Apps** > **+** > **Sonarr**:

   | Field | Value |
   | --- | --- |
   | Prowlarr Server | `http://prowlarr:9696` |
   | Sonarr Server | `http://sonarr:8989` |
   | API Key | Sonarr's key (Sonarr > Settings > General) |
   | Sync Level | **Full Sync** |

   Click **Test**, then **Save**.
4. **Connect Radarr.** Same again with **Radarr**: Sonarr Server becomes Radarr Server `http://radarr:7878`, and use Radarr's API key.
5. **Sync.** On the Apps page click **Sync App Indexers**. Your indexers now appear automatically in Sonarr and Radarr under Settings > Indexers. Adding or removing an indexer in Prowlarr later updates both.

## 4. Test the whole chain

1. In Sonarr: **Series > Add New**, search for a show, choose the root folder, and add it. Then open the show and click the magnifier (**Automatic Search**) on an episode.
2. In qBittorrent, a torrent should appear under the `tv` category, and progress.
3. When it finishes, Sonarr imports it into `/data/media/tv/...`.
4. **Check the hardlink** (no double disk use). Over SSH, list the same file in both places with `-i` and compare the first number (the inode) and the link count:
   ```sh
   ls -li /volume1/data/torrents/tv/<folder> /volume1/data/media/tv/<show>/<season>
   ```
   Same inode number and a link count of `2` means it is a hardlink. Different numbers mean it was copied, usually because `torrents` and `media` are on different volumes or the paths don't match the ones above.
5. Repeat with a movie in Radarr (category `movies`).

If nothing downloads: Sonarr > System > Status shows problems. Check the download client test passes, and that qBittorrent's interface is `tun0` while the VPN is up.

## 5. Jellyfin

Jellyfin already exists on the NAS and isn't part of this project.

1. In Jellyfin (Dashboard > Libraries), add a **TV Shows** library at `/volume1/data/media/tv` and a **Movies** library at `/volume1/data/media/movies`. If Jellyfin runs as a container or another user, it needs read access to these folders; it sees them at whatever path you mounted them to.
2. Optional, so new imports appear straight away: in Sonarr and Radarr, Settings > **Connect** > **+** > **Emby / Jellyfin** (wording varies). Host = the NAS IP, port `8096`, and an API key made in Jellyfin (Dashboard > API Keys). Tick the options to update the library on import.

## Speeding up the next install

Once this works, export backups from Sonarr, Radarr and Prowlarr (Settings > System > Backup). Restoring them on a new machine brings back the wiring. You'll still re-enter secrets such as indexer logins and the qBittorrent password. See section 5 of the main README.
