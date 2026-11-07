#!/bin/sh
# build.sh - builds aa-tile for QNX 6.5 ARM (NBT EVO) with plain clang + ld.lld, no QNX SDK needed.
# The program is linked dynamically against two link-only stubs (build/*_stub.c) that only carry the symbol
# names; at run time the head unit's own libc.so.3 / libsocket.so.3 / ldqnx.so.2 are used.
# No libstdc++ at all (see the static-libstdc++ boot-loop note in Keukenrol123522/g31-nbt-aad-tile).
# Output: out/aa-tile, plus out/aa-tile.size (checked by scripts/test-ram.sh) and its sha256.
set -e
cd "$(dirname "$0")/.."
mkdir -p out out/obj
CF="--target=armv7a-unknown-linux-gnueabi -mfloat-abi=soft -marm -O2 -ffreestanding -fno-builtin -mno-unaligned-access"
clang $CF -c build/crt0.S -o out/obj/crt0.o
clang $CF -fPIC -c build/libc_stub.c -o out/obj/libc_stub.o
clang $CF -fPIC -c build/libsocket_stub.c -o out/obj/libsocket_stub.o
ld.lld -shared -soname libc.so.3 -o out/obj/libc.so.3 out/obj/libc_stub.o
ld.lld -shared -soname libsocket.so.3 -o out/obj/libsocket.so.3 out/obj/libsocket_stub.o
clang $CF -c src/aa_tile.c -o out/obj/aa_tile.o
ld.lld --hash-style=sysv -z norelro -z nognustack --no-rosegment -z max-page-size=0x1000 \
  --image-base=0x100000 --dynamic-linker=/usr/lib/ldqnx.so.2 -e _start \
  -o out/aa-tile out/obj/crt0.o out/obj/aa_tile.o out/obj/libc.so.3 out/obj/libsocket.so.3
wc -c < out/aa-tile | tr -d ' ' > out/aa-tile.size
echo "built out/aa-tile ($(cat out/aa-tile.size) bytes)"
( cd out && sha256sum aa-tile | tee aa-tile.sha256 )
