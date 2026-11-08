# nbt-aa-tile

Android Auto tile in the **main menu of BMW / MINI NBT EVO (ID5/ID6)** head units, as a small program that runs
**next to** [NBT-AAD](https://github.com/Sq00ky/Supra-iDrive6-Android-Auto) instead of inside it.

It uses the head unit's own CarLife entry: the tile appears on the home screen (and as a source in Media/Radio),
and pressing it brings Android Auto to the front. Nothing on the head unit or in nbt-aad is modified to show it.

**Status:** the program (build 4, Italian names) was tested on a MINI F60 (`NBTevo_Y21432J`, nbt-aad 1.9.20) from RAM
in both modes; RRudkinp ran the boot kit on his bench unit (tile shown while Android Auto is connected, gone when
the phone's WiFi is off). **Build 5** in this repo is the same code with English
names, paths and messages (the compiled functions are instruction-for-instruction identical to build 4, only string
addresses differ); it has not been run in a car yet. Use at your own risk.

## Credits

* **RRudkinp** - found the whole mechanism (MOST device `0x2471`, `AppState 0xCF1`, press `0xCE8`), spent several
  long evenings on it and shared it in [issue #55](https://github.com/Sq00ky/Supra-iDrive6-Android-Auto/issues/55)
  together with his own nbt-aad tile build. This program exists because of that work.
* **Sq00ky / nanaisu** - NBT-AAD. The DSI/MOST client in `src/aa_tile.c` is derived from NBT-AAD's
  (`dsi_client.cpp`, `most/msg.hpp`, `most/ids.hpp`), so this repo stays under the same licence.
* **Keukenrol123522** - ported RRudkinp's patch into nbt-aad itself as an opt-in build option (`NBT_TILE=1`):
  [g31-nbt-aad-tile](https://github.com/Keukenrol123522/g31-nbt-aad-tile). Use that one if you build nbt-aad
  yourself and want no extra process.
* **dn00** - the `_start` layout in `build/crt0.S` follows his f60-probe.
* **deathwalker80** - this standalone version, tests on the MINI F60.

## nbt-aa-tile or NBT_TILE?

| | nbt-aa-tile (this repo) | `NBT_TILE=1` build (Keukenrol123522) |
|---|---|---|
| What | separate QNX program (C, ~14 KB) | inside nbt-aad |
| Rebuild nbt-aad | no | yes |
| Works with | any nbt-aad with the control port and state file (1.8.66 and later) | the build you compile |
| Files changed on the HU | 2 lines at the top of `/opt/conn/bin/start_webserver.sh` (boot start only) | none |

Both use the same mechanism and both are credited to RRudkinp.

## Requirements

* NBT EVO with SSH root access (for example with [Bavarian SSH](https://ssh.bavarian-aa.uk/)).
* nbt-aad installed and working. aa-tile needs its control port (UDP `127.0.0.1:52790`) and its state file
  (`/dev/shmem/nbt-aad-state`): both are there from 1.8.66 on, and still in the current main branch.
* A FAT USB stick. The head unit cannot create folders on it, so prepare the folder on a PC.

## Files

```
src/aa_tile.c                the program
build/build.sh               build with plain clang + ld.lld (no QNX SDK), see below
build/crt0.S, *_stub.c       start-up code and link-only stubs (no code of them ends up in the program)
scripts/test-ram.sh          run from RAM for 120 s, nothing installed  <- always start here
scripts/install-boot.sh      start at every boot (adds 2 lines to start_webserver.sh, keeps the original)
scripts/remove-boot.sh       undo install-boot.sh (original file back byte for byte)
scripts/status.sh            read-only state of the boot install
scripts/aa-tile-launcher.sh  the boot launcher (installed by install-boot.sh)
scripts/hook.txt             the 2 lines added to start_webserver.sh
docs/protocol.md             the MOST messages and what the iDrive asks for
```

## Usage

Download `nbt-aa-tile-5.zip` from [Releases](https://github.com/deathwalker80/nbt-aa-tile/releases) and unzip it in
the root of the USB stick: it contains the `nbt-aa-tile` folder ready to use (`aa-tile`, `aa-tile.size`, the files
from `scripts/`, and `SHA256SUMS`). Or build it yourself and put the same files in that folder.
Plug the stick in, SSH to the head unit, then:

```sh
# 1. test from RAM (no mount, nothing installed): Android Auto running and the phone connected
on -f /net/hu-omap/ /bin/sh
sh /mnt/umass*/nbt-aa-tile/test-ram.sh follow    # or: always
#    the log is saved on the stick as nbt-aa-tile/test<N>.log

# 2. only if the test was fine: start it at every boot
mount -o remount rw /net/hu-omap/fs/sda0
on -f /net/hu-omap/ /bin/sh
sh /mnt/umass*/nbt-aa-tile/install-boot.sh follow
#    reboot (power button 30 s), then:
sh /mnt/umass*/nbt-aa-tile/status.sh
```

Modes: `follow` (default) shows the tile only while Android Auto is connected; `always` keeps it visible.
After the install the mode is in `/var/opt/aa-tile/mode`.

### Safety

* Nothing starts during boot: the launcher sleeps until nbt-aad is running, then waits 20 s more.
* If aa-tile ever crashes it writes `/var/opt/aa-tile/CRASHED` and is never started again.
* A counter disables it after 3 starts in a row that the unit does not survive for 60 s.
* Manual stop: `touch /var/opt/aa-tile/DISABLED`, or an empty file `NO-AA-TILE` in the root of a USB stick
  plugged in before switching on.
* Removal: `remove-boot.sh` (with `mount -o remount rw` first), then reboot.

## Build

```sh
sh build/build.sh      # needs clang and ld.lld (tested with LLVM 18.1)
```

It writes `out/aa-tile`, `out/aa-tile.size` and `out/aa-tile.sha256`. The program is linked dynamically: at run time
it uses the head unit's own `libc.so.3`, `libsocket.so.3` and `ldqnx.so.2`, and `libsys_dsi_colibry` through `dlopen`.
No libstdc++ (a statically linked libstdc++ crashes inside the HMI plugin environment, see Keukenrol123522's README).

## Optional extra: labels and images

The tile shows the CarLife entry as it is ("n. t. a. (ASIA)" / "CarLife" and the CarLife icon). The optional extra
[`extras/menu-look`](extras/menu-look) (`aa-menu-look-1.zip` in Releases) changes the labels to "Android Auto" on the
head unit itself and, if you add your own PNGs, the images, with a backup of every file and a full restore script.
Unlike the tile, it **modifies head-unit files**. BMW and MINI paths, sizes and string IDs are in its README.

## Not included on purpose

No BMW files (`text.db`, images, binaries from the head unit) and no Android Auto logo.

## Help wanted

Contributions, test reports and ideas are welcome: open an issue or a pull request here, or join the discussion in
[NBT-AAD issue #55](https://github.com/Sq00ky/Supra-iDrive6-Android-Auto/issues/55). Open points:

* **Test reports** from other cars and software builds (BMW ID5/ID6, Supra, other MINI models, other `NBTevo_*`
  versions): car, HU build, nbt-aad version, mode, and the `test<N>.log` from `test-ram.sh`.
* **Boot start without touching head-unit files.** The NBT-AAD authors prefer added files only; today the boot start
  needs 2 lines in `start_webserver.sh`. A better hook, or nbt-aad starting aa-tile itself, would remove that.
* **Phone name and battery on the tile**, as CarPlay shows them. The CarLife device has `DeviceInfo` functions that
  look like the right place; not tried yet.
* **Icon and label** of the tile without modifying head-unit files.

## Licence

PolyForm Noncommercial 1.0.0, see `LICENSE.md` (copied unchanged from NBT-AAD). Required notice:
*Copyright (c) 2026 nanaisu - NBT-AAD (https://github.com/Sq00ky/Supra-iDrive6-Android-Auto)*. Noncommercial use only.
Not affiliated with or endorsed by the NBT-AAD author, BMW, MINI or Google.
