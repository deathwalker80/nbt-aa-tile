#!/bin/sh
# build.sh - builds aa-look for QNX 6.5 ARM (NBT EVO) with clang + ld.lld (same recipe as build/build.sh of aa-tile),
# and a PC copy (out/aa-look-pc) for testing. Output: out/aa-look, out/aa-look.size, out/aa-look.sha256.
set -e
cd "$(dirname "$0")/.."
mkdir -p out out/obj
CF="--target=armv7a-unknown-linux-gnueabi -mfloat-abi=soft -marm -O2 -ffreestanding -fno-builtin -mno-unaligned-access"
clang $CF -c ../../build/crt0.S -o out/obj/crt0.o
clang $CF -fPIC -c build/libc_stub.c -o out/obj/libc_stub.o
ld.lld -shared -soname libc.so.3 -o out/obj/libc.so.3 out/obj/libc_stub.o
clang $CF -DQNX_TARGET -Wall -Wno-unused-function -c src/aa_look.c -o out/obj/aa_look.o
ld.lld --hash-style=sysv -z norelro -z nognustack --no-rosegment -z max-page-size=0x1000 \
  --image-base=0x100000 --dynamic-linker=/usr/lib/ldqnx.so.2 -e _start \
  -o out/aa-look out/obj/crt0.o out/obj/aa_look.o out/obj/libc.so.3
wc -c < out/aa-look | tr -d ' ' > out/aa-look.size
echo "built out/aa-look ($(cat out/aa-look.size) bytes)"
( cd out && sha256sum aa-look | tee aa-look.sha256 )
if command -v cc >/dev/null 2>&1; then cc -O2 -o out/aa-look-pc src/aa_look.c && echo "built out/aa-look-pc (PC test copy)"; fi
