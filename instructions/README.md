# Instructions: filling in `.env`

One guide per section of `.env.example`. Work through them in order.

1. [Host / user](01-host-user.md): user IDs, timezone, folders, home network
2. [Ports](02-ports.md)
3. [VPN (required)](03-vpn-required.md): provider, WireGuard key and address
4. [VPN (optional)](04-vpn-optional.md): OpenVPN login, port forwarding, custom providers
5. [Cloudflare Tunnel](05-cloudflare-tunnel.md): only if you want outside access
6. [Setup script switches](06-setup-script-switches.md)

After each section, `sh setup.sh --check` tells you what is still wrong.
