# 4. VPN (optional)

Variables: `SERVER_COUNTRIES`, `SERVER_NAMES`, `VPN_PORT_FORWARDING`, and a WireGuard block that Privado doesn't use.

Everything here is commented out in `.env.example`. **You can skip this page.** With nothing set, Gluetun picks a Privado server for you, exactly as your current container does (its `SERVER_COUNTRIES`, `SERVER_CITIES` and similar settings are all empty). Anything you leave commented is passed to Gluetun as empty, which it ignores (tested against the current image).

Gluetun's Privado page: <https://github.com/qdm12/gluetun-wiki/blob/main/setup/providers/privado.md>

## `SERVER_COUNTRIES`

Use it if you want your traffic to exit from a particular country. Uncomment the line and give a country name the way Privado spells it, for example `SERVER_COUNTRIES=Canada`. Several can be comma separated. If you set a country Privado has no servers in, Gluetun fails to start and logs that no server matches; remove the line or fix the name.

## `SERVER_NAMES`

Pins Gluetun to specific servers. The Privado page calls this kind of filter "the narrowest filter" and warns that if a pinned server is ever removed, the container will fail until you change it. Avoid it unless you have a specific reason. (Gluetun's Privado page describes the same idea under the variable name `SERVER_HOSTNAMES`; `SERVER_NAMES` is what this repo's compose file passes through.)

## `VPN_PORT_FORWARDING`

Not available for Privado in Gluetun (it supports forwarding for only a few other providers), so leave it off.

## WireGuard block

Only for a provider that uses WireGuard; Privado does not in Gluetun. Ignore it. It is covered in "Using a different provider later" in [`03-vpn-required.md`](03-vpn-required.md).

## Check it

`sh setup.sh --check` doesn't validate these. Gluetun checks them when the stack starts; `sudo docker logs gluetun` shows any complaint.
