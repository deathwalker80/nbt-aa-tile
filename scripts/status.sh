#!/bin/sh
# status.sh (nbt-aa-tile 5) - READ ONLY. Shows the state of the boot install.
#   on -f /net/hu-omap/ /bin/sh
#   sh /mnt/umass*/nbt-aa-tile/status.sh

W=/opt/conn/bin/start_webserver.sh
D=/var/opt/aa-tile
echo "== hook in start_webserver.sh =="
if grep 'nbt-aa-tile hook' $W >/dev/null 2>&1; then echo "present"; else echo "absent"; fi
echo "== files =="
ls -l /opt/aa-tile 2>/dev/null
echo "== mode / counter / crash / disabled / last action =="
if [ -f $D/mode ]; then echo "mode: $(cat $D/mode)"; else echo "mode: (default follow)"; fi
if [ -f $D/boots ]; then echo "start counter: $(cat $D/boots)"; else echo "start counter: 0"; fi
if [ -f $D/CRASHED ]; then echo "CRASHED: $(cat $D/CRASHED)"; else echo "CRASHED: no"; fi
if [ -f $D/DISABLED ]; then echo "DISABLED: $(cat $D/DISABLED)"; else echo "DISABLED: no"; fi
if [ -f $D/last ]; then echo "last: $(cat $D/last)"; fi
if [ -f /dev/shmem/aa-tile-launcher.pid ]; then echo "launcher ran this boot (pid $(cat /dev/shmem/aa-tile-launcher.pid))"; else echo "launcher did not run this boot"; fi
if [ -f /dev/shmem/nbt-aad-state ]; then echo "nbt-aad state: $(cat /dev/shmem/nbt-aad-state)"; else echo "nbt-aad state: (no file - nbt-aad not running)"; fi
echo "== process =="
pidin | grep 'aa-tile/aa-tile' | grep -v grep
echo "== last program output (RAM) =="
cat /dev/shmem/aa-tile.log 2>/dev/null
