# aa-menu-look (optional extra of nbt-aa-tile)

Makes the CarLife entry that nbt-aa-tile (or an nbt-aad build with the tile) brings up look like Android Auto:

* **Labels**: "n. t. a. (ASIA)" / "CarLife" / "Baidu CarLife" become "Android Auto" (or a label you choose) in every
  language. Done **on the head unit** by `aa-look`, no PC tools needed.
* **Images** (only if you add them): your PNGs replace the CarLife images, file by file. With the image folders
  left empty, only the labels change.

Unlike nbt-aa-tile itself, **this extra modifies head-unit files** (`text.db` and the images you add). Every file is
backed up first, and `restore.sh` puts all of them back byte for byte. In a European car the CarLife entry is not
used for anything else (the HMI itself labels it "n. t. a. (ASIA)").

## Credits

**RRudkinp** worked out the `text.db` format (big-endian tables, UCL NRV2D-compressed UTF-16 languages), the 18
CarLife string IDs and the BMW image paths, and shared them with his Python tools in
[NBT-AAD issue #55](https://github.com/Sq00ky/Supra-iDrive6-Android-Auto/issues/55). `aa-look` is a new C
implementation of that work, so the change can run on the head unit itself.
The MINI paths and the 3 extra MINI string IDs come from a MINI F60.

## What is in the folder

```
aa-menu-look/
  install.sh        labels + your images, with backup        (needs mount rw)
  restore.sh        puts back every replaced file             (needs mount rw)
  list-images.sh    READ-ONLY: lists the CarLife images of your head unit with path and size
  aa-look           the helper program (QNX ARM), aa-look.size
  images/           put your PNGs here, in the same folders as on the head unit
  SHA256SUMS
```

`images/` mirrors `/opt/hmi/ID5/data/ro/` on the head unit: `images/<path>` replaces `/opt/hmi/ID5/data/ro/<path>`.
Only `images/<brand>/` and `images/common/` are used, only `.png` files (lower-case extension), and only when the
same file exists on the head unit. The `FILES.txt` in each folder says what goes there.

## Usage

Unzip `aa-menu-look-2.zip` in the root of the FAT USB stick (it creates the `aa-menu-look` folder; the head unit
cannot create folders on the stick). Add your images if you want them. SSH to the head unit, then:

```sh
mount -o remount rw /net/hu-omap/fs/sda0
on -f /net/hu-omap/ /bin/sh
sh /mnt/umass*/aa-menu-look/install.sh mini          # or: bmw | bmwm | bmwi
# custom label:  sh /mnt/umass*/aa-menu-look/install.sh bmw "Android Auto"
cd /
```

Reboot (power button ~30 s). To undo everything:

```sh
mount -o remount rw /net/hu-omap/fs/sda0
on -f /net/hu-omap/ /bin/sh
sh /mnt/umass*/aa-menu-look/restore.sh                # or, without the stick: sh /opt/aa/menu-look-backup/restore.sh
cd /
```

and reboot. To see which images your head unit has (read-only, no mount needed):

```sh
on -f /net/hu-omap/ /bin/sh
sh /mnt/umass*/aa-menu-look/list-images.sh bmw       # saves aa-menu-look/images-found-bmw.txt on the stick
```

**Brand**: the HMI reads `/opt/hmi/ID5/data/ro/<brand>/db/text.db`. Use `bmw` for a normal BMW, `bmwm` if the menu
uses the M texts, `bmwi` for BMW i, `mini` for a MINI.

### What install.sh checks before touching anything

* the omap shell, the `text.db` of the brand, the size of `aa-look`;
* that the older kits of this project (`/opt/aa/menu-prima`, `/opt/aa/menu-prima-bmw`) are not installed;
* every image: a real PNG, the head-unit file exists, **same width and height** as the original (a different PNG colour
  type only gives a note);
* the labels: `aa-look` refuses a `text.db` whose untouched rebuild is not byte-exact, verifies the new one in memory
  (every language decodes, changed languages read back exactly, the others are byte-identical) and reads the written
  file back. The labels are always made from the factory copy once there is one, so running it again (or with
  another label) is safe.

Then each file is backed up once to `/opt/aa/menu-look-backup/ro/<path>` (listed in `files.txt`), replaced, and
compared with the source. Files already identical are skipped.

## Labels

`aa-look` changes only the CarLife string IDs, and only where their text is one of: `n. t. a. (ASIA)`, `CarLife`,
`Baidu CarLife`, `百度 CarLife`, `百度CarLife` (and the capital forms, which get the label in capitals).

| Brand | String IDs |
|---|---|
| bmw / bmwm / bmwi | 94480 94488 94608 94616 94648 94664 94672 94673 94696 94697 94699 94704 94705 94707 94712 94713 94714 94715 |
| mini | the same 18 + 95944 96432 96433 |

On a MINI F60 (`NBTevo_Y21432J`, text.db with 35 languages) that is 580 lines in 28 languages. The label must be
plain ASCII, 1 to 40 characters.

## Images

Same width and height as the original are required. Keep the original's PNG colour type when you can (2 = RGB,
4 = grey+alpha, 6 = RGBA) and use transparency like the original. Paths are relative to `/opt/hmi/ID5/data/ro/`.

### BMW (NBT EVO ID6)

| File | Size | What it is |
|---|---|---|
| `bmw/id6l/widgetasset/CarLifePad/resources/carlife_inactive.png` | 72 x 378 RGBA | main-menu tile, no focus |
| `bmw/id6l/widgetasset/CarLifePad/resources/carlife_selected.png` | 72 x 378 RGBA | main-menu tile, focus (red bar) |
| `bmw/id6l/widgetasset/CarLifePad/resources/carlife_touch.png` | 72 x 378 RGBA | main-menu tile, pressed |
| `common/assetDB/12_baidu/carlife_48x48/carlife_48x48.png` | 48 x 48 RGBA | Media/Radio source entry |

The tile icon is in `widgetasset`, not in `assetDB`. For BMW M / BMW i check with `list-images.sh bmwm|bmwi` and use
`images/bmwm/...` / `images/bmwi/...` if the files are there.

### MINI (NBT EVO ID6)

| File | Size | What it is |
|---|---|---|
| `mini/id6l/assetDB/2D/Baukasten/MainMenu/Widget_Baidu_Apple/global_widget_baidu.png` | 152 x 152 RGBA | main-menu tile picture |
| `mini/id6l/assetDB/2D/Icons/Icons_MainMenu/36x36/MainMenu_Carlife/mainmenu_carlife.png` | 36 x 36 grey+alpha | list-menu icon (white/grey like the others) |
| `mini/id6l/assetDB/2D/Icons/Icons_MainMenu/36x36/MainMenu_Carlife/seeall_carlife.png` | 128 x 128 RGBA | overview icon of the entry |
| `mini/id6l/assetDB/12_baidu/carlife_48x48/carlife_48x48.png` | 48 x 48 RGBA | Media/Radio source entry |
| `mini/id6l/assetDB/2D/Baukasten/MainMenu/Widget_Icons_32x32/Icon_BatteryCharging/icon_kommunikation_batterie_error.png` | 32 x 32 RGBA | optional: battery with "?" under the tile (used wherever a phone battery level is unknown; a transparent image hides it) |

Other CarLife images exist (cover art 360 x 360, list pictures 540 x 477, status bar 48 x 48, device list 56 x 48,
...): `list-images.sh` prints their exact paths and sizes on your head unit, and any of them can be replaced the same
way.

No image is included: the Android Auto logo is a Google trademark and the tile backgrounds are BMW/MINI artwork, so
make or pick your own.

## Build

```sh
sh build/build.sh      # clang + ld.lld, same recipe as aa-tile; also builds out/aa-look-pc for tests on a PC
```

`out/aa-look-pc labels mini text.db text.db.new` runs the same label change on a PC copy of a `text.db`.

## Licence

As nbt-aa-tile: PolyForm Noncommercial 1.0.0. Use at your own risk; keep the backup folder until you are happy.
