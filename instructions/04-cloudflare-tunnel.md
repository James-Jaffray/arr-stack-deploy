# 4. Cloudflare Tunnel (optional)

Variable: `CLOUDFLARE_TUNNEL_TOKEN`

Skip this section unless you want to reach Sonarr, Radarr or Prowlarr from outside your home network. The tunnel container only starts when you ask for it with `--profile tunnel`.

**Never expose qBittorrent through the tunnel.** The other apps are not hardened for the public internet, so put **Cloudflare Access** (a login page) in front of every hostname you add.

## What you need first

- A free Cloudflare account.
- A domain name managed by Cloudflare (added to your account with Cloudflare as its DNS).

## Getting the token

Cloudflare renames menus now and then; the steps below may look slightly different.

1. Go to <https://one.dash.cloudflare.com> (Zero Trust). If asked, pick a team name and the free plan.
2. Networks > Tunnels > **Create a tunnel** > choose **Cloudflared** > name it (for example `arr-stack`).
3. On the install page you'll see a command containing `--token` followed by a very long string. Copy **only that long string**, not the whole command.
4. In `.env`, uncomment the line and paste it:
   ```text
   CLOUDFLARE_TUNNEL_TOKEN=eyJhIjoi...
   ```
   The token is a secret. If it leaks, roll it in the Cloudflare dashboard.

## Starting it

```sh
docker compose --profile tunnel up -d
```

## Adding hostnames

In the tunnel's **Public Hostname** tab add one entry per app, using the internal names (not `localhost`):

| Hostname | Service |
| --- | --- |
| `sonarr.example.com` | `http://sonarr:8989` |
| `radarr.example.com` | `http://radarr:7878` |
| `prowlarr.example.com` | `http://prowlarr:9696` |

Then in Zero Trust > Access > Applications, create an application for each hostname with a policy that only allows your email address. Do this before treating the hostname as usable.

More detail is in section 6 of the main `README.md`.
