# Instructions: filling in `.env`

Start with the initial setup (preparing the NAS and getting the files onto it), then one guide per section of `.env.example` (`01` to `03`), then start the stack and connect the apps (`04`). `05` and `06` are optional. Work through them in order.

0. [Initial setup](00-initial-setup.md): install Container Manager, create the `arr` user and shared folders, SSH, move the files onto the NAS
1. [Host / user](01-host-user.md): user IDs, timezone, folders, home network
2. [Ports](02-ports.md)
3. [VPN (required)](03-vpn-required.md): PrivadoVPN username and password
4. [Start the stack and connect the apps](04-connecting-the-apps.md): qBittorrent, Sonarr, Radarr, Prowlarr, indexers
5. [Cloudflare Tunnel](05-cloudflare-tunnel.md): only if you want outside access
6. [Setup script switches](06-setup-script-switches.md)

Once it's running, keep [`runbook.md`](runbook.md) handy: the everyday commands, where things live and a quick diagnosis table.

After each section, `sh setup.sh --check` tells you what is still wrong.
