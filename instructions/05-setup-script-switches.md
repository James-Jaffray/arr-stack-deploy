# 5. Setup script switches (optional)

Variable: `SKIP_TUN_CHECK`

## `SKIP_TUN_CHECK`

`setup.sh` tests that Docker can use the `/dev/net/tun` device, which Gluetun needs to create the VPN. On a machine where that test can't work correctly you can turn it off by uncommenting:

```text
SKIP_TUN_CHECK=1
```

Only do this if you know the tun device really is available, for example after you have confirmed Gluetun starts. Skipping it does not fix a missing device; Gluetun will still fail to start.

On Synology, the fix for a missing device is the boot task in `scripts/synology-tun-boot.sh` (see section 3 of the main `README.md`). You can also set it for a single run without editing `.env`:

```sh
SKIP_TUN_CHECK=1 sh setup.sh --check
```
