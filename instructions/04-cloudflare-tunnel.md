# 4. Cloudflare Tunnel (remote access)

Variable: `CLOUDFLARE_TUNNEL_TOKEN`

This lets you reach the apps and Jellyfin from outside the home network without opening any port on the router. The `cloudflared` container makes an outbound connection to Cloudflare, and Cloudflare forwards visitors through it.

What gets exposed:

| Service | Address the tunnel points at | Protection |
| --- | --- | --- |
| Sonarr | `http://sonarr:8989` | The app's own login |
| Radarr | `http://radarr:7878` | The app's own login |
| Prowlarr | `http://prowlarr:9696` | The app's own login |
| qBittorrent | `http://gluetun:8080` | qBittorrent's own login |
| Jellyfin | `http://<nas-ip>:8096` | Jellyfin's own login |

The VPN and the tunnel don't conflict. The VPN protects what qBittorrent sends out; the tunnel is only how you reach its web page. qBittorrent has no network of its own, so the tunnel targets **`gluetun`**, never `qbittorrent`.

## Read this first: risks

This setup has **no Cloudflare Access** (the email-code checkpoint). Every service is protected only by its own login page, which means:

- **Anyone who finds the hostnames can reach the login pages** and try passwords. Bots scan the internet for exactly these apps.
- **Use a long, unique password for every account** on all five services. A password manager helps.
- **Set the logins up before you add the hostnames** (step 4 below, then step 5), so the pages are never open even for a minute.
- **qBittorrent locks out an address after several failed logins, from memory (unverified).** All tunnel visitors share one address, so someone guessing passwords could lock you out as well. If that happens, restart the qBittorrent container: `sudo docker restart qbittorrent`.
- **Keep the apps updated** (`docker compose pull`, see the main README), since a login page doesn't protect against a bug in the app itself.
- **To switch remote access off at any time**, see "Turning it off" at the bottom.

## 1. A domain name

The tunnel needs a domain you control, added to Cloudflare. The friend needs one. Options:

- **Buy one inside Cloudflare:** Cloudflare Dashboard > Domain Registration > Register Domains. Cloudflare sells domains at cost, and it is already set up for them. Prices vary by ending, so check them there.
- **Buy one elsewhere**, then in Cloudflare choose **Add a domain** and change the domain's nameservers at the seller to the two Cloudflare gives you. It can take a while to activate.

A free Cloudflare account is enough. Use the domain in the hostnames below in place of `example.com`.

## 2. Create the tunnel and get the token

Cloudflare renames menus now and then, so these may look slightly different.

1. Go to <https://one.dash.cloudflare.com> (Zero Trust). If asked, choose a team name and the **Free** plan. Cloudflare may ask for a payment method even for the free plan; you aren't charged for it.
2. Networks > Tunnels > **Create a tunnel** > choose **Cloudflared** > name it (for example `arr-stack`).
3. The install page shows a command containing `--token` followed by a very long string. Copy **only that long string**.
4. On the NAS, in `.env`, uncomment the line and paste it:
   ```text
   CLOUDFLARE_TUNNEL_TOKEN=eyJhIjoi...
   ```
   The token is a secret. If it leaks, roll it in the Cloudflare dashboard.

## 3. Start the tunnel

The tunnel only starts when you ask for it. [SSH in](00-initial-setup.md#2-how-to-ssh-into-the-nas) and run:

```sh
cd /volume1/docker/arr-stack
sudo docker compose --profile tunnel up -d
```

Back in the Cloudflare tunnel page, its status should turn **Healthy**. No hostnames exist yet, so nothing is reachable.

## 4. Turn on each app's own login (before adding hostnames)

This is your only protection, so do it first. Open each app from inside the home network.

- **Sonarr, Radarr, Prowlarr:** Settings > General > Security. Set Authentication to a login form (for example **Forms**), and set **Authentication Required** to **Enabled**, not "Disabled for Local Addresses". Tunnel traffic reaches the apps from inside the Docker network, which they treat as local, so the "local addresses" option would skip the login entirely. Menu wording differs a little between versions. Set a username and a strong password.
- **qBittorrent:** Tools > Options > Web UI. Change the password from the temporary one to a strong one. Leave "Bypass authentication for clients on localhost" and "Bypass authentication for clients in whitelisted IP subnets" **off**.
- **Jellyfin:** strong unique passwords for every user, no shared or default accounts.

Check: from a device on the home network, open each app in a private browser window. Each must ask for a login.

## 5. Add the public hostnames

In the tunnel: **Public Hostname** tab > **Add a public hostname**, once per row. Type is `HTTP`.

| Subdomain | Domain | URL |
| --- | --- | --- |
| `sonarr` | `example.com` | `sonarr:8989` |
| `radarr` | `example.com` | `radarr:7878` |
| `prowlarr` | `example.com` | `prowlarr:9696` |
| `qbit` | `example.com` | `gluetun:8080` |
| `jellyfin` | `example.com` | `<nas-ip>:8096` |

Use the NAS's real IP for `<nas-ip>` (for example `192.168.1.20`) and Jellyfin's real port if it isn't the default `8096`. Jellyfin isn't part of this project's containers, so the tunnel reaches it through the NAS's address. If that fails, the DSM firewall may be blocking containers from reaching the NAS itself; see Troubleshooting.

Tip: you don't have to expose everything. Each hostname you leave out is one less login page on the internet. If you only need Jellyfin remotely, add only that row.

## 6. Test it

1. On a phone with Wi-Fi **off** (mobile data), open `https://sonarr.example.com`. You should get Sonarr's login page, not the app. If you land inside the app with no login, stop: go back to step 4 and remove the hostname in step 5 until it is fixed.
2. Repeat for the other services.
3. In the Jellyfin phone or TV app, use `https://jellyfin.example.com` (no port) as the server address.

## Troubleshooting

| Problem | Likely cause / fix |
| --- | --- |
| Tunnel not Healthy | `sudo docker logs cloudflared`. Wrong or truncated token in `.env`; re-copy only the long string. |
| 502 Bad Gateway on an arr hostname | The URL in the public hostname is wrong. Use the container name and port exactly as in the table, and confirm the container runs (`sudo docker ps`). |
| qBittorrent page loads but login fails or says Unauthorized | qBittorrent can reject logins that come through a proxy. In Tools > Options > Web UI, add `qbit.example.com` to **Server domains**, or untick **Enable Host header validation** (and, if needed, CSRF protection). This is general qBittorrent behaviour, so try it if you see the problem. |
| Locked out of qBittorrent after failed logins | `sudo docker restart qbittorrent` (see the risk above). |
| 502 or timeout on Jellyfin only | Containers can't reach the NAS's own address. Check the IP and port, then in DSM check Control Panel > Security > Firewall isn't blocking the Docker network. |
| Jellyfin works on the LAN but the apps fail remotely | Use `https://jellyfin.example.com` with no port as the server address. |

## Turning it off

Stop remote access immediately:

```sh
sudo docker compose --profile tunnel stop cloudflared
```

Or delete the tunnel in the Cloudflare dashboard, which also cuts access straight away.
