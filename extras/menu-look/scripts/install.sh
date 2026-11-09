#!/bin/sh
# install.sh (aa-menu-look 2) - makes the CarLife entry look like Android Auto. Optional extra of nbt-aa-tile.
#
#   sh /mnt/umass*/aa-menu-look/install.sh <bmw|bmwm|bmwi|mini> ["Label"]
#
# Run INSIDE the omap shell, after:  mount -o remount rw /net/hu-omap/fs/sda0   and   on -f /net/hu-omap/ /bin/sh
#
# 1. LABELS (always): "n. t. a. (ASIA)" / "CarLife" / "Baidu CarLife" of the CarLife entry -> "Android Auto"
#    (or the label you give), in every language, only for the CarLife string IDs. Done ON the head unit by aa-look.
# 2. IMAGES (only if you put some): every PNG under images/<brand>/ and images/common/ of this folder replaces the
#    head-unit file with the SAME path under /opt/hmi/ID5/data/ro/. It must have the same width and height as the
#    original. Folders left empty = only the labels change.
#
# Every file is backed up once (the factory copy) in /opt/aa/menu-look-backup before it is replaced, and listed in
# /opt/aa/menu-look-backup/files.txt. restore.sh puts all of them back (also copied to /opt/aa/menu-look-backup/).
# Everything is checked BEFORE anything is touched. It can be run again (files already in place are skipped).
# Then reboot (power button 30 s).

BRAND="$1"
LABEL="$2"; [ -n "$LABEL" ] || LABEL="Android Auto"
case "$BRAND" in
  bmw|bmwm|bmwi|mini) ;;
  *) echo "usage: sh /mnt/umass*/aa-menu-look/install.sh <bmw|bmwm|bmwi|mini> [\"Label\"]"
     echo "       (bmw for BMW, bmwm if the menu uses the M texts, bmwi for BMW i, mini for MINI)"; exit 1 ;;
esac

U=""
for d in /mnt/umass*; do if [ -d "$d/aa-menu-look" ]; then U=$d; fi; done
if [ -z "$U" ]; then echo "ERROR: no USB stick with an aa-menu-look folder found in /mnt"; exit 1; fi
K="$U/aa-menu-look"
if [ ! -d /opt/hmi ]; then echo "ERROR: /opt/hmi not found - are you in the omap shell (on -f /net/hu-omap/ /bin/sh)?"; exit 1; fi
RO=/opt/hmi/ID5/data/ro
T="$RO/$BRAND/db/text.db"
B=/opt/aa/menu-look-backup
MAN="$B/files.txt"
X=/dev/shmem/aa-look
NEW=/dev/shmem/aa-menu-look-text.db
LIST=/dev/shmem/aa-menu-look-images.txt
FOUND=/dev/shmem/aa-menu-look-found.txt
size() { Z=$(wc -c < "$1" 2>/dev/null); echo $Z; }

echo "aa-menu-look 2: brand $BRAND, label \"$LABEL\""

# ---------------- checks (nothing is changed here) ----------------
if [ ! -f "$T" ]; then echo "ERROR: $T not found: wrong brand for this head unit? Nothing changed."; exit 1; fi
for o in /opt/aa/menu-prima /opt/aa/menu-prima-bmw; do
  if [ -d "$o" ]; then echo "ERROR: an older menu kit is installed ($o). Remove it first with its own remove script, reboot, then run this. Nothing changed."; exit 1; fi
done
if [ -f "$B/brand" ]; then
  read OLDB < "$B/brand"
  if [ "$OLDB" != "$BRAND" ]; then echo "ERROR: already installed for '$OLDB'. Run restore.sh first. Nothing changed."; exit 1; fi
fi
if [ ! -f "$K/aa-look" ] || [ ! -f "$K/aa-look.size" ]; then echo "ERROR: aa-look missing in $K"; exit 1; fi
read WANT < "$K/aa-look.size"
if [ "$(size "$K/aa-look")" != "$WANT" ]; then echo "ERROR: aa-look is $(size "$K/aa-look") bytes, aa-look.size says $WANT. Nothing changed."; exit 1; fi
# the stick is mounted noexec: copy to RAM keeping the execute bit
rm -f "$X" "$NEW" "$LIST" "$FOUND"
cp /bin/ls "$X" && cat "$K/aa-look" > "$X" || { echo "ERROR: cannot copy aa-look to RAM"; exit 1; }
if [ "$(size "$X")" != "$WANT" ]; then echo "ERROR: wrong copy of aa-look in RAM"; rm -f "$X"; exit 1; fi

# images: only images/<brand>/ and images/common/, only PNG, only files that exist on the head unit, same size
: > "$LIST"
for top in "$BRAND" common; do
  if [ -d "$K/images/$top" ]; then find "$K/images/$top" -type f -name '*.png' >> "$FOUND" 2>/dev/null; fi
done
N_IMG=0
if [ -f "$FOUND" ]; then
  while read F; do
    REL=${F#$K/images/}
    DST="$RO/$REL"
    if [ ! -f "$DST" ]; then echo "SKIPPED (no such file on this head unit): $REL"; continue; fi
    A=$("$X" png "$F") || { echo "ERROR: $REL on the stick is not a PNG. Nothing changed."; exit 1; }
    O=$("$X" png "$DST") || { echo "ERROR: the head unit's $REL is not a PNG. Nothing changed."; exit 1; }
    set -- $A; AW=$1; AH=$2; AT=$3
    set -- $O; OW=$1; OH=$2; OT=$3
    if [ "$AW" != "$OW" ] || [ "$AH" != "$OH" ]; then
      echo "ERROR: $REL is ${AW}x${AH}, the original is ${OW}x${OH}. Same size needed. Nothing changed."; exit 1
    fi
    if [ "$AT" != "$OT" ]; then echo "note: $REL colour type $AT, original $OT (2 = RGB, 4 = grey+alpha, 6 = RGBA)"; fi
    echo "$REL" >> "$LIST"
    N_IMG=$((N_IMG+1))
  done < "$FOUND"
fi
echo "images to replace: $N_IMG"

# labels: always made from the factory copy if there is one
SRC="$T"
if [ -f "$B/ro/$BRAND/db/text.db" ]; then SRC="$B/ro/$BRAND/db/text.db"; fi
echo "labels: working on $SRC (this takes a little while)"
"$X" labels "$BRAND" "$SRC" "$NEW" "$LABEL"
RC=$?
LABELS=0
case $RC in
  0) LABELS=1 ;;
  3) echo "labels: nothing to change" ;;
  *) echo "ERROR: labels not made (code $RC). Nothing changed."; rm -f "$NEW"; exit 1 ;;
esac
if [ $LABELS = 0 ] && [ $N_IMG = 0 ]; then echo "Nothing to do."; exit 0; fi

# ---------------- changes ----------------
mkdir -p "$B/ro" || { echo "ERROR: cannot write in /opt/aa. Did you run  mount -o remount rw /net/hu-omap/fs/sda0 ?"; exit 1; }
echo "$BRAND" > "$B/brand"
: >> "$MAN"
cp "$K/restore.sh" "$B/restore.sh" 2>/dev/null

# backup <rel>: factory copy, once
backup() {
  if [ -f "$B/ro/$1" ]; then return 0; fi
  mkdir -p "$B/ro/${1%/*}" || { echo "ERROR: cannot create the backup folder for $1"; return 1; }
  if cp "$RO/$1" "$B/ro/$1" && "$X" same "$RO/$1" "$B/ro/$1"; then
    echo "$1" >> "$MAN"; echo "backup: $1"; return 0
  fi
  rm -f "$B/ro/$1"; echo "ERROR: backup of $1 failed"; return 1
}
# put <rel> <new file>: skip if identical; else move the old one aside, copy, compare, drop the old one
put() {
  D="$RO/$1"
  if "$X" same "$D" "$2"; then echo "already in place: $1"; return 0; fi
  V="$D.old-$$"
  mv "$D" "$V" || { echo "ERROR: cannot rename $D"; return 1; }
  if cp "$2" "$D" && "$X" same "$D" "$2"; then rm -f "$V"; echo "OK: $1"; return 0; fi
  echo "ERROR: copy of $1 failed, the previous file is back"
  rm -f "$D"; mv "$V" "$D"; return 1
}

FAIL=0
if [ $LABELS = 1 ]; then
  backup "$BRAND/db/text.db" && put "$BRAND/db/text.db" "$NEW" || FAIL=1
fi
if [ $FAIL = 0 ] && [ $N_IMG != 0 ]; then
  while read REL; do
    backup "$REL" && put "$REL" "$K/images/$REL" || { FAIL=1; break; }
  done < "$LIST"
fi
rm -f "$NEW" "$LIST" "$FOUND"
if [ $FAIL != 0 ]; then
  echo "STOPPED on an error. What was already replaced is listed in $MAN; restore.sh puts it back."
  exit 1
fi
echo "DONE. Now:  cd /   and reboot (power button 30 s)."
echo "To undo:  sh /mnt/umass*/aa-menu-look/restore.sh   (or  sh $B/restore.sh  without the stick)"
