# 3. VPN (required): PrivadoVPN

Variables: `VPN_PROVIDER`, `VPN_TYPE`, `OPENVPN_USER`, `OPENVPN_PASSWORD`

This setup is built around **PrivadoVPN**, the provider your existing Gluetun container uses. You need an active **paid** Privado plan: Privado's help pages say manual OpenVPN setups (which is what Gluetun is) are not available on the free plan, so a free account would be rejected with `AUTH_FAILED`. Gluetun's own page for it: <https://github.com/qdm12/gluetun-wiki/blob/main/setup/providers/privado.md>

**Treat the username and password like any other password.** Never commit them, paste them into chat, or put them anywhere except the NAS's `.env`.

## `VPN_PROVIDER` and `VPN_TYPE`

Already set for you in `.env.example`:

```text
VPN_PROVIDER=privado
VPN_TYPE=openvpn
```

Leave them as they are. Gluetun supports Privado over **OpenVPN only**, so there is no WireGuard key to find, and `VPN_TYPE` must stay `openvpn`.

## `OPENVPN_USER` and `OPENVPN_PASSWORD`

These are your Privado VPN login details. They are **not your email address**: Privado's own manual-setup guides state that the email can't be used as the username for a manual setup.

1. Sign in to the Privado web account at <https://app.privadovpn.com>.
2. Find your VPN **username** on your account page, shown next to the password. Privado's help pages call this your "client page"; the menu name may differ from what's written here.
3. Copy the username into `OPENVPN_USER` and the password into `OPENVPN_PASSWORD`.
4. Save `.env`. No quotes are needed, but if the password contains spaces or a `#`, wrap it in double quotes.

If you're stuck, open a support ticket with Privado and ask for "the username and password for a manual OpenVPN setup".


**Connection limit:** Privado's help says a Premium account supports up to 10 connections. The NAS's Gluetun counts as one.

## Check it

```sh
cd /volume1/docker/arr-stack
sudo sh setup.sh --check
```

It lists `OPENVPN_USER` or `OPENVPN_PASSWORD` if either is still `CHANGE_ME` or empty. It can't tell whether the login is correct. The real test is starting the stack and then running `sudo sh scripts/verify.sh`, which confirms gluetun is healthy and that qBittorrent's public IP differs from yours.

If gluetun never becomes healthy, run `sudo docker logs gluetun` and read the last lines. A line containing `AUTH_FAILED` means Privado rejected the username or password, so re-copy them from your account page (and check you used the username, not the email).
