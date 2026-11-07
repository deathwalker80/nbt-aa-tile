# How the tile works (MOST side)

Everything here was found by **RRudkinp** (Sq00ky/Supra-iDrive6-Android-Auto, issue #55). This file only writes down
what aa-tile does with it, plus what we saw on a MINI F60.

## The device

The NBT EVO HMI already has a native main-menu entry for Baidu CarLife. It appears when a MOST device with the key
**0x2471** (FBlock **0x24**, instance **0x71**) shows up, and the HMI talks to it through its CarLife proxy
(`CPxyAuxiliaryInput`). aa-tile registers that device itself, so the HMI shows its own CarLife tile (and the CarLife
source in Media/Radio). The tile keeps the unit's own text and icon for that slot: changing those means editing
head-unit files, which this project does not do.

## Messages

| Step | Who | What |
|---|---|---|
| register | aa-tile -> DSYSMOSTServer | request `0x0` registerDevices: `<client u32> 1 <0x2471 u16>` |
| subscribe | iDrive -> 0x2471 | `Set` fkt `0x001`, 5 bytes: `01 <ctrl address BE> <fkt BE>` |
| AppState | 0x2471 -> iDrive | `Status` (op `0xC`) fkt **`0xCF1`**, 1 byte: **0 = tile shown, 1 = hidden** |
| other properties | 0x2471 -> iDrive | standard error (op `0xF`, fkt `0x001`): `20 10 <fkt BE>` |
| press | iDrive -> 0x2471 | `Set` fkt **`0xCE8`**, 1 byte: 0 = main-menu tile, other = Media/Radio entry |
| on press | aa-tile -> nbt-aad | UDP `"show"` to `127.0.0.1:52790` (nbt-aad's control port) |
| exit | aa-tile -> DSYSMOSTServer | AppState 1 (hidden), then request `0x4` unregisterDevices |

All messages are sent from the DSI callback thread, as in RRudkinp's patch.

## Modes

* `follow` (default): the tile is shown while `/dev/shmem/nbt-aad-state` starts with `connected`
  (nbt-aad writes `<idle|connecting|connected> <pid> [overlay]` there), hidden otherwise.
* `always`: shown as long as aa-tile runs (for testing).

## What the iDrive subscribes to

On a MINI F60 (`NBTevo_Y21432J`, nbt-aad 1.9.20) the iDrive (MOST address 0x2022) subscribed to these 29 functions of
FB 0x24 inst 0x71:

```
0x120 0x136 0x200 0x431 0x434 0x450 0x4ab 0xc1d 0xc8e 0xc8f 0xc94 0xc99 0xc9b 0xc9c 0xc9d
0xc9e 0xca0 0xca6 0xcc6 0xcc8 0xce1 0xcf0 0xcf1 0xcf4 0xcf5 0xcf6 0xcf7 0xcf9 0xcfa
```

aa-tile answers only 0xCF1 and sends the standard error for the others, so the iDrive keeps re-subscribing
(about 230 subscriptions in 120 s). It is harmless, but answering them properly would cut that traffic. The HMI's
CarLife proxy has a `DeviceInfo` function (`CAuxIn_DeviceInfo` / `DeviceInfo2`): it most likely carries the phone name
and battery that the MINI skin shows under the tile as "battery ?". Which of the IDs above it is, and its payload, is
still open.
