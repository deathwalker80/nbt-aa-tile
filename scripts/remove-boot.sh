#!/bin/sh
# remove-boot.sh (nbt-aa-tile 5) - removes the boot start of aa-tile and puts start_webserver.sh back.
# Run INSIDE the omap shell, after:  mount -o remount rw /net/hu-omap/fs/sda0
#   on -f /net/hu-omap/ /bin/sh
#   sh /mnt/umass*/nbt-aa-tile/remove-boot.sh
# Quick stop WITHOUT removing anything: touch /var/opt/aa-tile/DISABLED  (or a file NO-AA-TILE on a USB stick)

W=/opt/conn/bin/start_webserver.sh
B=/opt/aa-tile/start_webserver.sh.original

pidin | grep 'aa-tile/aa-tile' | grep -v grep | while read p r; do kill $p; done
echo "OK: aa-tile stopped (if it was running)"

if [ -f $B ]; then
  cp $B $W && chmod 755 $W && echo "OK: original start_webserver.sh restored"
else
  echo "WARNING: backup $B not found: start_webserver.sh not touched"
fi
if grep 'nbt-aa-tile hook' $W >/dev/null 2>&1; then echo "ERROR: hook still present in $W"; exit 1; fi

rm -f /opt/aa-tile/aa-tile /opt/aa-tile/aa-tile-launcher.sh
rm -rf /var/opt/aa-tile
echo "OK: program and counters removed (the original stays in $B)"
echo "DONE. Reboot (power button 30 s). (A launcher still sleeping in this boot finds no program and stops.)"
