# 3. VPN (required)

Variables: `VPN_PROVIDER`, `VPN_TYPE`, `WIREGUARD_PRIVATE_KEY`, `WIREGUARD_ADDRESSES`, `SERVER_COUNTRIES`

This is the most important section. You need a paid account with a VPN provider that Gluetun supports. Provider websites change often, so the Gluetun wiki page for your provider is the final word on the exact steps: <https://github.com/qdm12/gluetun-wiki/tree/main/setup/providers>

**Treat the WireGuard key like a password.** Never commit it, paste it into chat, or copy your laptop's `.env` to the client's NAS. If it leaks, generate a new one at your provider.

## `VPN_PROVIDER`

The provider name spelled the way Gluetun expects, all lower case. Examples from the Gluetun docs: `mullvad`, `protonvpn`, `private internet access`, `nordvpn`, `airvpn`, `windscribe`, `surfshark`, `ivpn`, `custom`.

- Find yours in the provider list linked above; the page for each provider shows the exact name.
- Not every provider supports both WireGuard and OpenVPN in Gluetun. The provider page tells you which.
- Names with spaces need no quotes in `.env`.

## `VPN_TYPE`

- `wireguard` (recommended): faster and simpler. Needs the two WireGuard values below.
- `openvpn`: use it if your provider only offers OpenVPN in Gluetun, or if WireGuard won't work on Docker Desktop during the laptop test. Then uncomment `OPENVPN_USER` and `OPENVPN_PASSWORD` in the optional section (see `04-vpn-optional.md`); the setup script then requires them and no longer needs the two WireGuard values.

## `WIREGUARD_PRIVATE_KEY` and `WIREGUARD_ADDRESSES`

Both come from a WireGuard configuration your provider generates for you.

1. Log in to your provider's website and find its WireGuard configuration generator (often under "WireGuard", "Manual setup" or "Devices"). If it asks for a platform choose "Linux" or "Router".
2. Generate a configuration and **download the `.conf` file**. Some providers only show the text on screen, which works too.
3. Open the file in Notepad. It looks like this (values here are fake):

   ```ini
   [Interface]
   PrivateKey = wOEI9rqqbDwnN8/Bpp22sVz48T71vJ4fYmFWujulwUU=
   Address = 10.64.222.21/32

   [Peer]
   PublicKey = ...
   Endpoint = 203.0.113.5:51820
   ```

4. Copy the value after `PrivateKey =` into `WIREGUARD_PRIVATE_KEY` (it usually ends in `=`; keep it).
5. Copy the value after `Address =` into `WIREGUARD_ADDRESSES`, for example `10.64.222.21/32`. If there are two addresses (an IPv4 and an IPv6 one), Gluetun accepts them comma separated; if unsure use the IPv4 one.
6. Ignore the `[Peer]` values (`PublicKey`, `Endpoint`) for now. You only need them if `VPN_PROVIDER=custom` (see `04-vpn-optional.md`).
7. Delete the downloaded `.conf` file when done, or keep it somewhere safe. It is a secret too.

Some providers limit how many devices or keys one account can have. Generating a key for the laptop test and another for the NAS may use up two slots.

## `SERVER_COUNTRIES`

The country your traffic exits from. Use a name your provider actually has servers in, for example `Canada`. Case doesn't matter. The provider's page in the Gluetun wiki lists what is accepted; a name the provider doesn't have will stop Gluetun finding a server.

## Check it

```sh
sh setup.sh --check
```

It lists every value still set to `CHANGE_ME`. It cannot tell whether the key is right; the real test is `docker compose up -d` and then `sh scripts/verify.sh`, which confirms gluetun is healthy and that qBittorrent's public IP differs from yours. If gluetun never becomes healthy, run `docker logs gluetun` and read the last few lines.
