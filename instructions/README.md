# Instructions: filling in `.env`

Start with the initial setup (preparing the NAS and getting the files onto it), then one guide per section of `.env.example`. Work through them in order.

0. [Initial setup](00-initial-setup.md): install Container Manager, create the `arr` user and shared folders, SSH, move the files onto the NAS
1. [Host / user](01-host-user.md): user IDs, timezone, folders, home network
2. [Ports](02-ports.md)
3. [VPN (required)](03-vpn-required.md): PrivadoVPN username and password
4. [Cloudflare Tunnel](04-cloudflare-tunnel.md): only if you want outside access
5. [Setup script switches](05-setup-script-switches.md)

After each section, `sh setup.sh --check` tells you what is still wrong.
