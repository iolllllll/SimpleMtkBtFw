# BlueToolFixup (MediaTek whitelist build)

A small modification of Acidanthera's [BlueToolFixup](https://github.com/acidanthera/BrcmPatchRAM)
(from BrcmPatchRAM, commit `6538902`, version 2.7.3) that lets the **native MediaTek Bluetooth
path of macOS `bluetoothd`** accept cards other than the ones Apple whitelisted.

* `BlueToolFixup.cpp` – the modified source (GPLv2, see `LICENSE`, original copyright headers kept)
* `mediatek.patch` – the change as a unified diff against upstream `BlueToolFixup.cpp`
* `build.sh` – reproducible build recipe (clone upstream, apply the patch, build)

## What it changes

`bluetoothd` on macOS 15+ (Sequoia) and macOS 26+ (Tahoe) contains Apple's native MediaTek driver
(`MtkLoadRomPatch`, `MtkPowerOn`, "USB SRS" transport, chipset type 0xB). It is whitelisted only
for specific USB devices:

### macOS 15 (Sequoia)
Whitelisted for Foxconn `0489:E0D8` in two places:

| function | instruction | bytes |
|---|---|---|
| `Found_USB_Dongle` | `xorl $0xE0D8, %esi` | `81 F6 D8 E0 00 00` |
| `OI_HciIfc_Init_USB_SRS` | `cmpw $0xE0D8, 0x16(%rdi)` | `66 81 7F 16 D8 E0` |

### macOS 26 (Tahoe)
Whitelisted using a 7-entry device table in `bluetoothd`:
`0489:E0D8`, `0489:E0E0`, `0489:E0F1`, `0489:E0F2`, `0489:E0F6`, `0E8D:7922`, `13D3:3568`.

Both macOS versions are handled by `mediatek.patch`:
- Rewrites the PID immediate / table entry in the `cs_validate_page` hook (in memory, SIP/SSV safe).
- Defaults to **PID 0xE14F** (Foxconn MT7925) or **0xE0CD** (Foxconn MT7921). Override with `smbtpid=<n>`.

| boot-arg | effect |
|---|---|
| `smbtpid=<n>` | use another PID (decimal or `0x..`), vendor stays 0x0489 |
| `-smbtmtkoff` | disable the whitelist patch |
| `-smbtchunkoff`, `smbtchunk=<n>` | optional patch of the ROM-patch chunk size |

All stock BlueToolFixup boot-args (`-btlfxoff`, `-btlfxdbg`, ...) keep working.

## Build

```sh
./build.sh      # needs Xcode, MacKernelSDK and Lilu.kext
```

Do **not** load this together with the stock BlueToolFixup (same bundle identifier).
