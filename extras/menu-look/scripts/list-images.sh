#!/bin/sh
# list-images.sh (aa-menu-look 2) - READ-ONLY. Lists every CarLife / Baidu image of this head unit with its exact
# path, size and PNG colour type, so you know which files you can replace and how big they must be.
#
#   sh /mnt/umass*/aa-menu-look/list-images.sh <bmw|bmwm|bmwi|mini>
#
# Run inside the omap shell (on -f /net/hu-omap/ /bin/sh). No mount rw needed. Nothing on the head unit changes.
# The list is shown and saved on the stick as aa-menu-look/images-found-<brand>.txt.
# To replace one: put your PNG (same width and height) in aa-menu-look/images/<the same path>.

BRAND="$1"
case "$BRAND" in
  bmw|bmwm|bmwi|mini) ;;
  *) echo "usage: sh /mnt/umass*/aa-menu-look/list-images.sh <bmw|bmwm|bmwi|mini>"; exit 1 ;;
esac
U=""
for d in /mnt/umass*; do if [ -d "$d/aa-menu-look" ]; then U=$d; fi; done
if [ -z "$U" ]; then echo "ERROR: no USB stick with an aa-menu-look folder found in /mnt"; exit 1; fi
K="$U/aa-menu-look"
if [ ! -d /opt/hmi ]; then echo "ERROR: /opt/hmi not found - are you in the omap shell?"; exit 1; fi
RO=/opt/hmi/ID5/data/ro
X=/dev/shmem/aa-look
OUT="$K/images-found-$BRAND.txt"
size() { Z=$(wc -c < "$1" 2>/dev/null); echo $Z; }

read WANT < "$K/aa-look.size"
rm -f "$X"
cp /bin/ls "$X" && cat "$K/aa-look" > "$X" || { echo "ERROR: cannot copy aa-look to RAM"; exit 1; }
if [ "$(size "$X")" != "$WANT" ]; then echo "ERROR: wrong copy of aa-look in RAM"; rm -f "$X"; exit 1; fi

{
  echo "CarLife / Baidu images on this head unit for '$BRAND' (width height colour-type  path under $RO)"
  echo "colour type: 2 = RGB, 4 = grey+alpha, 6 = RGBA"
  for top in "$BRAND" common; do
    if [ -d "$RO/$top" ]; then
      find "$RO/$top" -type f \( -iname '*carlife*' -o -iname '*baidu*' -o -iname '*batterie_error*' \) 2>/dev/null | while read F; do
        case "$F" in
          *.png|*.PNG) P=$("$X" png "$F" 2>/dev/null) || P="not-a-png"; echo "$P  ${F#$RO/}" ;;
          *) echo "(not an image)  ${F#$RO/}" ;;
        esac
      done
    fi
  done
} > "$OUT"
cat "$OUT"
echo "Saved on the stick: aa-menu-look/images-found-$BRAND.txt"
