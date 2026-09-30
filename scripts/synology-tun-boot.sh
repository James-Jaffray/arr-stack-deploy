#!/bin/sh
# Paste into DSM: Control Panel > Task Scheduler > Create > Triggered Task > User-defined script
#   Event: Boot-up    User: root
#
# Gluetun needs /dev/net/tun, which DSM does not always create. This loads the tun kernel
# module and creates the device if it is missing.
#
# The tun.ko path can differ by Synology model / DSM version. If insmod fails, locate it with:
#   find / -name tun.ko 2>/dev/null
# and edit the path below. This has not been tested on every model.

/sbin/insmod /lib/modules/tun.ko 2>/dev/null
if [ ! -c /dev/net/tun ]; then
  [ -d /dev/net ] || mkdir -m 755 /dev/net
  mknod /dev/net/tun c 10 200
  chmod 0666 /dev/net/tun
fi
