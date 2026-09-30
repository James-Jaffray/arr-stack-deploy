# 4. VPN (optional, provider dependent)

Variables: `SERVER_NAMES`, `VPN_PORT_FORWARDING`, `WIREGUARD_PUBLIC_KEY`, `WIREGUARD_ENDPOINT_IP`, `WIREGUARD_ENDPOINT_PORT`, `WIREGUARD_PRESHARED_KEY`, `OPENVPN_USER`, `OPENVPN_PASSWORD`

All of these are commented out in `.env.example`. **Uncomment a line only when your provider needs it.** Anything you leave commented is passed to Gluetun as empty, which it ignores (tested against the current image). Most people using Mullvad or a similar provider with WireGuard need none of them.

When in doubt, check your provider's page: <https://github.com/qdm12/gluetun-wiki/tree/main/setup/providers>

## OpenVPN login: `OPENVPN_USER`, `OPENVPN_PASSWORD`

Needed only when `VPN_TYPE=openvpn`. Both become **required** then, and `setup.sh` checks them.

- These are usually **not** your normal website login. Many providers issue separate "OpenVPN/IKEv2 credentials" on a manual-setup page; some (for example Mullvad) use your account number as the user. Check the provider's Gluetun page.
- Uncomment both lines and fill them in.

## `SERVER_NAMES`

Pin Gluetun to specific server hostnames instead of any server in the country. Use it if one server is fast and reliable for you, or your provider asks for it. The valid names are on your provider's page or on its server list. Separate several with commas. Most people leave it off.

## `VPN_PORT_FORWARDING`

Set `on` to ask the provider for an inbound port, which can improve torrent connectivity. It only works with providers Gluetun supports for this (per its docs: Private Internet Access, Perfect Privacy, PrivateVPN and ProtonVPN), and some need a specially generated config. Leave it off unless you know you need it. If you enable it, Gluetun writes the forwarded port to a file; putting that port into qBittorrent is a manual step, not automated here.

## The `custom` provider values

Only used when `VPN_PROVIDER=custom` (a provider Gluetun doesn't know). Copy them from the `[Peer]` section of the `.conf` file you downloaded (see `03-vpn-required.md`):

| Variable | Where it comes from |
| --- | --- |
| `WIREGUARD_PUBLIC_KEY` | `PublicKey =` |
| `WIREGUARD_ENDPOINT_IP` | the address part of `Endpoint = 203.0.113.5:51820` (`203.0.113.5`) |
| `WIREGUARD_ENDPOINT_PORT` | the port part of `Endpoint` (`51820`) |
| `WIREGUARD_PRESHARED_KEY` | `PresharedKey =`, only if the file has one |

For a provider Gluetun knows, leave all four commented out.

## Check it

`sh setup.sh --check` only insists on the two OpenVPN values, and only when `VPN_TYPE=openvpn`. Everything else here is validated by Gluetun when the stack starts; `docker logs gluetun` shows any complaint.
