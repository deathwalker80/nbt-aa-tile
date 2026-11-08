#!/bin/sh
# restore.sh (aa-menu-look 1) - puts back EVERY file that install.sh replaced (labels and images), byte for byte,
# from the factory copies in /opt/aa/menu-look-backup, then removes that folder.
#
#   sh /mnt/umass*/aa-menu-look/restore.sh      or, without the stick:   sh /opt/aa/menu-look-backup/restore.sh
#
# Run INSIDE the omap shell, after:  mount -o remount rw /net/hu-omap/fs/sda0   and   on -f /net/hu-omap/ /bin/sh
# Then reboot (power button 30 s).

if [ ! -d /opt/hmi ]; then echo "ERROR: /opt/hmi not found - are you in the omap shell (on -f /net/hu-omap/ /bin/sh)?"; exit 1; fi
RO=/opt/hmi/ID5/data/ro
B=/opt/aa/menu-look-backup
MAN="$B/files.txt"
size() { Z=$(wc -c < "$1" 2>/dev/null); echo $Z; }

if [ ! -f "$MAN" ]; then echo "Nothing to restore: $MAN not found (aa-menu-look is not installed)."; exit 0; fi

FAIL=0
N=0
while read REL; do
  [ -n "$REL" ] || continue
  S="$B/ro/$REL"
  D="$RO/$REL"
  if [ ! -f "$S" ]; then echo "ERROR: backup of $REL missing"; FAIL=1; continue; fi
  if [ -f "$D" ] && [ "$(size "$D")" = "$(size "$S")" ] && cmp -s "$D" "$S" 2>/dev/null; then
    echo "already original: $REL"; N=$((N+1)); continue
  fi
  V="$D.new-$$"
  if [ -f "$D" ]; then mv "$D" "$V" || { echo "ERROR: cannot rename $D. Did you run  mount -o remount rw /net/hu-omap/fs/sda0 ?"; FAIL=1; continue; }; fi
  if cp "$S" "$D" && [ "$(size "$D")" = "$(size "$S")" ]; then
    rm -f "$V"; echo "restored: $REL"; N=$((N+1))
  else
    echo "ERROR: copy of $REL failed, leaving the current file"
    rm -f "$D"; [ -f "$V" ] && mv "$V" "$D"; FAIL=1
  fi
done < "$MAN"

if [ $FAIL != 0 ]; then
  echo "NOT COMPLETE: the backup in $B is kept. Fix the error above and run restore.sh again."
  exit 1
fi
echo "DONE: $N file(s) back to the original. Now:  cd /   and reboot (power button 30 s)."
cd /
exec rm -rf "$B"
