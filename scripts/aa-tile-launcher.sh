#!/bin/sh
# aa-tile-launcher.sh (nbt-aa-tile 5) - starts aa-tile at boot, with boot-loop protection.
# Started in the background at every boot by ONE line added to /opt/conn/bin/start_webserver.sh.
# It never blocks that script (started with '&'); until nbt-aad is running it only sleeps.
#
# Safety design:
#  1. Nothing of ours touches the system during boot: this script only sleeps and checks files.
#  2. aa-tile starts ONLY after nbt-aad is running (/dev/shmem/nbt-aad-state exists: nbt-aad rewrites it
#     every second while alive and deletes it on exit), plus 20 s. HMI and MOST are fully up by then.
#     In "follow" mode nothing is lost: without Android Auto the tile would be hidden anyway, and a press
#     ("show" to nbt-aad) only works while nbt-aad runs.
#     With nbt-aad's "Start with the car" OFF, aa-tile only ever starts after the user starts Android Auto.
#  3. aa-tile catches fatal signals: it writes /var/opt/aa-tile/CRASHED and exits at once (no core dump).
#     A crash marker -> this launcher never starts it again (DISABLED). At most one reset, if any.
#  4. Backup counter for resets that do not come from our own crash: written BEFORE the start; cleared once
#     the unit has survived 60 s after the start. 3 starts in a row without that -> DISABLED.
#  5. Manual stops: /var/opt/aa-tile/DISABLED, or an empty file NO-AA-TILE in the root of a USB stick.
#
# Files: /opt/aa-tile/aa-tile, /var/opt/aa-tile/{boots,CRASHED,DISABLED,mode,last}, /dev/shmem/aa-tile.log
# Mode: /var/opt/aa-tile/mode = follow (default: tile only while Android Auto is connected) or always.

D=/var/opt/aa-tile
C=$D/boots
mkdir -p $D 2>/dev/null

if [ -f /dev/shmem/aa-tile-launcher.pid ]; then exit 0; fi
echo $$ > /dev/shmem/aa-tile-launcher.pid

stop_here() { echo "$1" > $D/last; exit 0; }

switches() {
  if [ -f $D/DISABLED ]; then stop_here "disabled (DISABLED present)"; fi
  if [ -f $D/CRASHED ]; then
    echo "aa-tile crashed earlier: $(cat $D/CRASHED)" > $D/DISABLED
    stop_here "crash marker found: disabled"
  fi
  for f in /mnt/umass*/NO-AA-TILE; do
    if [ -e "$f" ]; then stop_here "stopped by USB flag $f"; fi
  done
}

sleep 30
switches

echo "waiting for nbt-aad" > $D/last
while [ ! -f /dev/shmem/nbt-aad-state ]; do sleep 10; done
echo "nbt-aad running, waiting 20 s" > $D/last
sleep 20
switches
if [ ! -x /opt/aa-tile/aa-tile ]; then stop_here "aa-tile missing"; fi

n=0
if [ -f $C ]; then read n < $C; fi
case "$n" in ''|*[!0-9]*) n=0 ;; esac
if [ "$n" -ge 3 ]; then
  echo "$n starts in a row without surviving 60 s: disabled by the bootguard" > $D/DISABLED
  stop_here "bootguard tripped (n=$n)"
fi
n=$((n+1))
echo $n > $C
sleep 5

MODE=follow
if [ -f $D/mode ]; then read MODE < $D/mode; fi
case "$MODE" in always|follow) ;; *) MODE=follow ;; esac
switches
if [ ! -x /opt/aa-tile/aa-tile ]; then stop_here "aa-tile missing"; fi

/opt/aa-tile/aa-tile $MODE </dev/null > /dev/shmem/aa-tile.log 2>&1 &
echo "started mode=$MODE counter=$n" > $D/last

sleep 60
rm -f $C
if [ -f $D/CRASHED ]; then
  echo "aa-tile crashed: $(cat $D/CRASHED)" > $D/DISABLED
  stop_here "crashed within 60 s: disabled"
fi
stop_here "started mode=$MODE, unit up 60 s after the start: counter cleared"
