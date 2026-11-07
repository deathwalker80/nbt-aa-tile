#!/bin/sh
# install-boot.sh (nbt-aa-tile 5) - installs aa-tile so that it starts at every boot.
# Run INSIDE the omap shell, after:  mount -o remount rw /net/hu-omap/fs/sda0
#   on -f /net/hu-omap/ /bin/sh
#   sh /mnt/umass*/nbt-aa-tile/install-boot.sh [follow|always]
#
# What it changes (and nothing else):
#   - copies aa-tile + aa-tile-launcher.sh to /opt/aa-tile/
#   - keeps the ORIGINAL /opt/conn/bin/start_webserver.sh as /opt/aa-tile/start_webserver.sh.original
#   - writes a new start_webserver.sh = "#! /bin/sh" + 2 hook lines + the original file, unchanged
#     (the original first line "#! /bin/sh" becomes a plain comment)
#   - checks the new file with "sh -n" before putting it in place; if anything fails, the original stays
# Removal: remove-boot.sh (puts the original back byte for byte).

U=""
for d in /mnt/umass*; do if [ -d "$d/nbt-aa-tile" ]; then U=$d; fi; done
if [ -z "$U" ]; then echo "ERROR: no USB stick with a nbt-aa-tile folder found in /mnt"; exit 1; fi
S=$U/nbt-aa-tile
W=/opt/conn/bin/start_webserver.sh
B=/opt/aa-tile/start_webserver.sh.original
N=/opt/aa-tile/start_webserver.sh.new

if [ ! -d /opt/hmi ]; then echo "ERROR: not in the omap shell (on -f /net/hu-omap/ /bin/sh)"; exit 1; fi
for f in aa-tile aa-tile-launcher.sh hook.txt; do
  if [ ! -f $S/$f ]; then echo "ERROR: missing $S/$f"; exit 1; fi
done
if [ ! -f $W ]; then echo "ERROR: $W not found: different software, stopping"; exit 1; fi
if grep 'casella-aa hook' $W >/dev/null 2>&1; then
  echo "ERROR: the older casella-aa build is installed. Remove it first with its togli-persistenza.sh, reboot, then run this again."
  exit 1
fi
if grep 'nbt-aa-tile hook' $W >/dev/null 2>&1; then
  echo "Hook already present in $W: only updating program and launcher"
  cp $S/aa-tile /opt/aa-tile/aa-tile && chmod 755 /opt/aa-tile/aa-tile && \
  cp $S/aa-tile-launcher.sh /opt/aa-tile/aa-tile-launcher.sh || { echo "ERROR: update failed"; exit 1; }
  rm -f /var/opt/aa-tile/DISABLED /var/opt/aa-tile/CRASHED /var/opt/aa-tile/boots
  echo "OK: updated. Reboot (power button 30 s)."
  exit 0
fi

mkdir -p /opt/aa-tile || { echo "ERROR: cannot create /opt/aa-tile (did you run mount -o remount rw?)"; exit 1; }
cp $S/aa-tile /opt/aa-tile/aa-tile || { echo "ERROR: copy of aa-tile failed"; exit 1; }
chmod 755 /opt/aa-tile/aa-tile
cp $S/aa-tile-launcher.sh /opt/aa-tile/aa-tile-launcher.sh || { echo "ERROR: copy of aa-tile-launcher.sh failed"; exit 1; }
echo "OK: program and launcher in /opt/aa-tile"

if [ ! -f $B ]; then
  cp $W $B || { echo "ERROR: backup of start_webserver.sh failed, stopping"; exit 1; }
fi
echo "OK: original kept in $B"

{ echo '#! /bin/sh'; cat $S/hook.txt; cat $B; } > $N || { echo "ERROR: cannot write $N"; exit 1; }
if ! sh -n $N; then echo "ERROR: syntax check of the new file failed: nothing changed"; rm -f $N; exit 1; fi
echo "OK: new start_webserver.sh passes sh -n"

cp $N $W || { cp $B $W; chmod 755 $W; echo "ERROR: replacing $W failed, original restored"; exit 1; }
chmod 755 $W
rm -f $N
if grep 'nbt-aa-tile hook' $W >/dev/null 2>&1; then echo "OK: hook in place"; else
  cp $B $W; chmod 755 $W; echo "ERROR: hook not found after the copy, original restored"; exit 1; fi

mkdir -p /var/opt/aa-tile
rm -f /var/opt/aa-tile/DISABLED /var/opt/aa-tile/CRASHED /var/opt/aa-tile/boots
M=follow
if [ "$1" = "always" ]; then M=always; fi
echo $M > /var/opt/aa-tile/mode
echo "OK: mode $M (change it in /var/opt/aa-tile/mode)"
echo ""
echo "DONE. Reboot (power button 30 s). aa-tile starts 25 s after nbt-aad is running"
echo "(mode follow: tile only with Android Auto connected). Status: sh $S/status.sh"
