#!/bin/sh
# test-ram.sh (nbt-aa-tile 5) - TEST FROM RAM. Installs nothing, touches no file on the head unit, no mount rw:
# runs aa-tile from RAM for a fixed time, then it stops by itself, hides the tile and unregisters its MOST device.
# Before: Android Auto running and the phone connected.
# Run INSIDE the omap shell (on -f /net/hu-omap/ /bin/sh):
#   sh /mnt/umass*/nbt-aa-tile/test-ram.sh follow     (tile shown ONLY while Android Auto is connected, 120 s)
#   sh /mnt/umass*/nbt-aa-tile/test-ram.sh always     (tile always shown, 120 s)
# The log is saved next to this script as test<N>.log (the FAT stick cannot create folders from the head unit).

MODE="$1"; [ "$MODE" = "always" ] || MODE=follow
SEC=120
size() { Z=$(wc -c < "$1" 2>/dev/null); echo $Z; }
U=""
for d in /mnt/umass*; do if [ -d "$d/nbt-aa-tile" ]; then U=$d; fi; done
if [ -z "$U" ]; then echo "ERROR: no USB stick with a nbt-aa-tile folder found in /mnt"; exit 1; fi
if [ ! -d /opt/hmi ]; then echo "ERROR: /opt/hmi not found - are you in the omap shell?"; exit 1; fi
K="$U/nbt-aa-tile"
S="$K/aa-tile"
P=/dev/shmem/aa-tile
L=/dev/shmem/aa-tile.log
if [ ! -f "$S" ]; then echo "ERROR: $S not found"; exit 1; fi
if [ -f "$K/aa-tile.size" ]; then
  read WANT < "$K/aa-tile.size"
  if [ "$(size "$S")" != "$WANT" ]; then echo "ERROR: aa-tile is $(size "$S") bytes, aa-tile.size says $WANT. Not starting it."; exit 1; fi
fi
N=1
while [ -f "$K/test$N.log" ]; do N=$((N+1)); done
# The stick is mounted noexec: copy to RAM keeping the execute bit (cp of an executable, then overwrite its content).
rm -f "$P" "$L"
cp /bin/ls "$P" && cat "$S" > "$P" || { echo "ERROR: cannot copy it to RAM"; exit 1; }
if [ "$(size "$P")" != "$(size "$S")" ]; then echo "ERROR: wrong copy in RAM"; rm -f "$P"; exit 1; fi
echo "Android Auto state: $(cat /dev/shmem/nbt-aad-state 2>/dev/null || echo 'no file')"
echo "aa-tile, mode $MODE, $SEC seconds. NOW on the iDrive:"
echo "  1. main MENU: look for the Android Auto tile"
echo "  2. press it: Android Auto must come back"
if [ "$MODE" = "follow" ]; then
echo "  3. (follow) switch off the phone's Bluetooth/WiFi: the tile must DISAPPEAR; reconnect: it comes back"
fi
echo "At the end the tile goes away by itself. Do not press Ctrl+C."
"$P" $MODE $SEC > "$L" 2>&1
RC=$?
grep -E "nbt-aa-tile|registered|subscribed|SHOWN|hidden|pressed|show\]|RESULT|MISSING|FAILED|REFUSED|unregistered|crash" "$L"
echo "exit code: $RC"
case "$RC" in
  0) echo "   0 = the iDrive saw the device and subscribed" ;;
  2) echo "   2 = registered, but the iDrive did not subscribe (no tile)" ;;
  4) echo "   4 = could not attach or register to the MOST server" ;;
  1) echo "   1 = startup problem (library or symbols)" ;;
  9) echo "   9 = aa-tile crashed: keep the log, do NOT go on" ;;
  *) echo "   unexpected code ($RC)" ;;
esac
{ cat "$L"; echo "== exit code: $RC"; date; } > "$K/test$N.log"
rm -f "$P" "$L"
echo "DONE: log saved in $K/test$N.log"
